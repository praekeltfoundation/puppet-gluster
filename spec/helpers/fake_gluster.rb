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
    ops[:errSt] ||= 'error'
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
    @name = name
    @bricks = bricks.map do |brick|
      brick[:uuid] ||= uuidify(brick[:name])
      brick[:hostUuid] ||= uuidify(brick[:name].split(':')[0])
      brick
    end
    @props = volume_hash.clone
    # FIXME: Build some of these values (status, types, etc.) more sensibly.
    # Fill in missing parameters.
    @props[:id] ||= uuidify(name)
    @props[:status] ||= 1
    @props[:statusStr] ||= 'Started'
    @props[:stripe] ||= 1
    @props[:replica] ||= 1
    @props[:disperse] ||= 1
    @props[:redundancy] ||= 1
    @props[:type] ||= 2
    @props[:typeStr] ||= 'Replicate'
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
        ['bricks', @bricks.map do |brick|
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
    @unreachable_peers = {}
  end

  # Manipulate and inspect state.

  def add_peer(hostname, peer_hash={})
    @peers << FakePeer.new(hostname, peer_hash)
  end

  def add_peers(*peers)
    peers = peers[0] if peers.size == 1 and peers[0].is_a? Array
    peers.each { |peer| add_peer(peer) }
  end

  def remove_peer(hostname)
    @peers.delete_if { |peer| peer.hostname == hostname }
  end

  def peer_unreachable(hostname, reason=nil)
    reason = 'Probe returned with unknown errno 107' if reason.nil?
    @unreachable_peers[hostname] = reason
  end

  def peer_reachable(hostname)
    @unreachable_peers.delete(hostname)
  end

  def peer_hosts
    @peers.map { |peer| peer.hostname }
  end

  def add_volume(name, bricks=nil, volume_hash={})
    @volumes << FakeVolume.new(name, bricks, volume_hash)
  end

  def add_volumes(*volumes)
    volumes = volumes[0] if volumes.size == 1 and volumes[0].is_a? Array
    volumes.each { |volume| add_volume(volume) }
  end

  # Pretend to be the cli.

  def gluster(*args)
    ['--xml', '--mode=script'].each do |arg|
      raise ArgumentError, "missing '#{arg}'" unless args.include? arg
      args.delete(arg)
    end
    case args
    when ['peer', 'status']
      peer_status
    when ->(a){ a.size == 3 and a.take(2) == ['peer', 'probe'] }
      peer_probe(args[2])
    when ->(a){ a.size == 3 and a.take(2) == ['peer', 'detach'] }
      peer_detach(args[2])
    when ['volume', 'info', 'all']
      volume_info
    else
      raise ArgumentError, "I don't know how to handle #{args.inspect}"
    end
  end

  def peer_status
    elem = make_cli_elem('peerStatus')
    @peers.each { |peer| peer.status_xml(elem) }
    format_doc(elem)
  end

  def peer_probe(peer)
    # TODO: More comprehensive implementation, including failures.
    if @unreachable_peers.include? peer
      elem = make_cli_err(
        :opErrno => 107, :opErrstr => @unreachable_peers[peer])
    else
      add_peer(peer)
      elem = make_cli_elem('output')
    end
    format_doc(elem)
  end

  def peer_detach(peer)
    # TODO: More comprehensive implementation, including failures.
    remove_peer(peer)
    elem = make_cli_elem('output')
    add_elems(elem, 'success')
    format_doc(elem)
  end

  def volume_info
    elem = make_cli_elem('volInfo').add_element('volumes')
    add_elems(elem, [['count', @volumes.size.to_s]])
    @volumes.each { |volume| volume.info_xml(elem) }
    format_doc(elem)
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
