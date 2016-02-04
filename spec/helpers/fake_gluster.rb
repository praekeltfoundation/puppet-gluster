def assert(cond, msg='Assertion failed')
  raise Exception, msg unless cond
end

module GlusterXML
  require 'rexml/document'

  def make_cli_elem(name, opRet=0, opErrno=0, opErrstr=nil)
    root = make_cli_root(opRet, opErrno, opErrstr)
    cmd = root.add_element(name)
    cmd
  end

  def make_cli_err(ops={})
    ops[:opRet] ||= -1
    ops[:opErrno] ||= 0
    ops[:opErrstr] ||= 'error'
    make_cli_root(ops[:opRet], ops[:opErrno], ops[:opErrstr])
  end

  def make_cli_root(opRet, opErrno, opErrstr)
    doc = REXML::Document.new
    doc << REXML::XMLDecl.new('1.0', 'UTF-8', 'yes')
    root = doc.add_element('cliOutput')
    add_elems(root, [
        ['opRet', opRet.to_s],
        ['opErrno', opErrno.to_s],
        ['opErrstr', opErrstr.to_s],
      ])
    root
  end

  def uuidify(str)
    # This fakes a UUID by reformatting the MD5 hash of the input.
    Digest::MD5.hexdigest(str).unpack('a8a4a4a4a12').join('-')
  end

  def add_elems(parent, elems)
    # If `elems` is a string, we're just adding a single text child.
    elems = [elems] if elems.is_a? String
    elems.each do |name, children=nil, attrs={}|
      if children.nil?
        # No children means we're adding text.
        parent.add_text(name)
      else
        elem = parent.add_element(name, attrs)
        add_elems(elem, children)
      end
    end
    parent
  end

  def format_doc(doc_or_elem)
    formatter = REXML::Formatters::Pretty.new
    formatter.compact = true
    output = ""
    formatter.write(doc_or_elem.document, output)
    output
  end
end


class FakePeer
  include GlusterXML

  attr_accessor :hostname

  def initialize(hostname, peer_hash={})
    if hostname.is_a? Hash
      peer_hash = hostname
      hostname = peer_hash[:hostname]
    end
    @hostname = hostname
    @props = peer_hash.clone
    # FIXME: Build some of these values (state, etc.) more sensibly.
    @props[:hostname] = hostname
    @props[:uuid] ||= uuidify(hostname)
    @props[:hostnames] = [hostname] + (@props.delete(:other_names) || [])
    @props[:connected] ||= 1
    @props[:state] ||= 3
    @props[:stateStr] ||= 'Peer in Cluster'
  end

  def status_xml(parent)
    add_elems(parent.add_element('peer'), [
        ['uuid', @props[:uuid]],
        ['hostname', @props[:hostname]],
        ['hostnames', @props[:hostnames]],
        ['connected', @props[:connected].to_s],
        ['state', @props[:state].to_s],
        ['stateStr', @props[:stateStr]],
      ])
  end
end


class FakeVolume
  include GlusterXML

  def initialize(name, bricks=nil, volume_hash={})
    if name.is_a? Hash
      volume_hash = name
      name = volume_hash[:name]
      bricks = volume_hash[:bricks]
    end
    @props = volume_hash.clone
    @props[:name] = name
    @props[:id] ||= uuidify(name)
    @props[:bricks] = bricks.map do |brick|
      brick = {:name => brick} if brick.is_a? String
      brick[:uuid] ||= uuidify(brick[:name])
      brick[:peer] = brick[:name].split(':')[0]  # Used internally only.
      brick[:hostUuid] ||= uuidify(brick[:name])
      brick
    end
    # FIXME: Build some of these values (status, types, etc.) more sensibly.
    # Fill in missing parameters.
    @props[:status] ||= 1
    @props[:statusStr] ||= 'Started'
    @props[:stripe] ||= 1
    @props[:replica] ||= 1
    @props[:disperse] ||= 1
    @props[:redundancy] ||= 1
    @props[:type] ||= 2
    @props[:typeStr] ||= 'Replicate'
  end

  [:name, :id, :bricks].each { |key| define_method(key) { @props[key] } }

  def peers
    bricks.map { |brick| brick[:peer] }
  end

  def started?
    @props[:status] == 1
  end

  def [](key)
    @props[key]
  end

  def []=(key, value)
    @props[key] = value
  end

  def short_xml(parent)
    add_elems(parent.add_element('volume'), [
        ['name', @props[:name]],
        ['id', @props[:id]],
      ])
  end

  def info_xml(parent)
    add_elems(parent.add_element('volume'), [
        ['name', @props[:name]],
        ['status', @props[:status].to_s],
        ['statusStr', @props[:statusStr]],
        ['brickCount', @props[:bricks].size.to_s],
        # FIXME: I don't know what the distCount actually is.
        ['distCount', @props[:bricks].size.to_s],
        ['stripeCount', @props[:stripe].size.to_s],
        ['replicaCount', @props[:replica].to_s],
        ['disperseCount', @props[:disperse].to_s],
        ['redundancyCount', @props[:redundancy].to_s],
        ['type', @props[:type].to_s],
        ['typeStr', @props[:typeStr]],
        ['transport', @props[:transport].to_s],
        # TODO: Support xlators?
        ['xlators', []],
        ['bricks', bricks.map do |brick|
            ['brick', [
                brick[:name],           # Text element.
                ['name', brick[:name]],
                ['hostUuid', brick[:hostUuid]],
              ], {'uuid' => brick[:uuid]}]
          end],
        # TODO: Support options?
        ['optCount', '1'],
        ['options', []],
      ])
  end
end


class FakeGluster
  include GlusterXML

  def initialize
    @peers = []
    @volumes = []
    @error = nil
    @unreachable_peers = {}
    @local_addresses = [Facter.value(:fqdn)]
  end

  # Manipulate and inspect state.

  def set_error(opRet, opErrno=-1, opErrstr='')
    @error = { :opRet => opRet, :opErrstr => opErrno, :opErrstr => opErrstr }
  end

  def add_local_alias(address)
    @local_addresses << address
  end

  def add_peer(hostname, peer_hash={})
    @peers << FakePeer.new(hostname, peer_hash)
  end

  def add_peers(*peers)
    peers = peers[0] if peers.size == 1 and peers[0].is_a? Array
    peers.each { |peer| add_peer(peer) }
  end

  def remove_peer(hostname)
    old_count = @peers.size
    @peers.delete_if { |peer| peer.hostname == hostname }
    old_count != @peers.size
  end

  def peer_unreachable(hostname, reason=nil)
    reason = 'Probe returned with unknown errno 107' if reason.nil?
    @unreachable_peers[hostname] = reason
  end

  def peer_reachable(hostname)
    @unreachable_peers.delete(hostname)
  end

  def peer_hosts
    @peers.map(&:hostname)
  end

  def add_volume(name, bricks=nil, volume_hash={})
    @volumes << FakeVolume.new(name, bricks, volume_hash)
  end

  def add_volumes(*volumes)
    volumes = volumes[0] if volumes.size == 1 and volumes[0].is_a? Array
    volumes.each { |volume| add_volume(volume) }
  end

  def get_volume(name)
    vols = @volumes.select { |vol| vol.name == name }
    assert vols.size == 1, "Expected to find one volume, found #{vols.size}"
    vols[0]
  end

  def volume_names
    @volumes.map(&:name)
  end

  # Pretend to be the cli.

  def gluster(*args)
    ['--xml', '--mode=script'].each do |arg|
      raise ArgumentError, "missing '#{arg}'" unless args.include? arg
      args.delete(arg)
    end
    return format_doc(make_cli_err(@error)) unless @error.nil?

    # All commands have the form <noun> <verb> <*args>, so we can use this to
    # avoid building a big dispatch table.
    cmd_method = "cmd_#{args[0]}_#{args[1]}".to_sym
    send(cmd_method, *args.drop(2).map(&:to_s))
  end

  # peer commands

  def cmd_peer_status
    elem = make_cli_elem('peerStatus')
    @peers.each { |peer| peer.status_xml(elem) }
    format_doc(elem)
  end

  def cmd_peer_probe(peer)
    if @unreachable_peers.include? peer
      format_doc(make_cli_err(
          :opErrno => 107, :opErrstr => @unreachable_peers[peer]))
    else
      add_peer(peer)
      format_doc(make_cli_elem('output'))
    end
  end

  def cmd_peer_detach(peer)
    remove_peer(peer)
    format_doc(add_elems(make_cli_elem('output'), 'success'))
  end

  # volume commands

  def cmd_volume_info(name)
    assert name == 'all', 'single volume info not supported'
    elem = make_cli_elem('volInfo').add_element('volumes')
    add_elems(elem, [['count', @volumes.size.to_s]])
    @volumes.each { |volume| volume.info_xml(elem) }
    format_doc(elem)
  end

  def cmd_volume_create(name, *args)
    # The args must follow the sequence <name> [replica, etc.] <bricks> [force]
    # which conveniently makes them easy to parse here.
    params = {}
    bricks = []
    if args[-1] == 'force'
      params[:force] = true
      args.delete_at(-1)
    end
    while !args.empty?
      case args[0]
      when 'replica'
        params[:replica] = args[1]
        args = args.drop(2)
      else
        bricks = args
        args = []
      end
    end
    params[:status] = 0
    params[:statusStr] = 'Created'
    volume = FakeVolume.new(name, bricks, params)
    all_peers = peer_hosts + @local_addresses
    volume.peers.each do |peer|
      return format_doc(make_cli_err(
          :opErrno => 30800,
          :opErrstr => "Host #{peer} is not in 'Peer in Cluster' state",
      )) unless all_peers.include? peer
    end
    @volumes << volume
    format_doc(volume.short_xml(make_cli_elem('volCreate')))
  end

  def cmd_volume_delete(name)
    volume = get_volume(name)
    assert !volume.started?, "volume started (status: #{volume[:status]})"
    @volumes.delete(volume)
    format_doc(volume.short_xml(make_cli_elem('volDelete')))
  end

  def cmd_volume_start(name)
    volume = get_volume(name)
    assert !volume.started?, "volume started (status: #{volume[:status]})"
    volume[:status] = 1
    volume[:statusStr] = 'Started'
    format_doc(volume.short_xml(make_cli_elem('volStart')))
  end

  def cmd_volume_stop(name)
    volume = get_volume(name)
    assert volume.started?, "volume not started (status: #{volume[:status]})"
    volume[:status] = 2
    volume[:statusStr] = 'Stopped'
    format_doc(volume.short_xml(make_cli_elem('volStop')))
  end

  # Utility stuff to make life a little easier.

  def to_proc
    method(:gluster).to_proc
  end
end

def stub_gluster(*objs)
  fake_gluster = FakeGluster.new
  objs.each { |obj| allow(obj).to receive(:gluster, &fake_gluster)}
  fake_gluster
end
