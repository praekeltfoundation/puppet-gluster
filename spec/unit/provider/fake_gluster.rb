module GlusterXML
  require 'rexml/document'

  def make_cli_elem(name, opRet=0, opErrno=0, opErrstr=nil)
    doc = REXML::Document.new
    doc << REXML::XMLDecl.new('1.0', 'UTF-8', 'yes')
    root = doc.add_element 'cliOutput'
    add_elem_text(root, 'opRet', opRet.to_s)
    add_elem_text(root, 'opErrno', opErrno.to_s)
    add_elem_text(root, 'opErrstr', opErrstr)
    cmd = root.add_element(name)
    cmd
  end

  def uuidify(str)
    # This fakes a UUID by reformatting the MD5 hash of the input.
    Digest::MD5.hexdigest(str).unpack('a8a4a4a4a12').join('-')
  end

  def add_elem_text(parent, name, text=nil)
    elem = parent.add_element name
    elem.add_text text unless text.nil?
    elem
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
    @bricks = bricks.map do |brick| populate_brick(brick)
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

  def initialize(peers=[], volumes=[])
    @peers = []
    @volumes = []
    peers.each { |peer| add_peer(peer) }
    volumes.each { |volume| add_volume(volume) }
  end

  def add_peer(hostname, peer_hash={})
    @peers << FakePeer.new(hostname, peer_hash)
  end

  def add_volume(name, bricks=nil, volume_hash={})
    @volumes << FakeVolume.new(name, bricks, volume_hash)
  end

  def peer_status
    elem = make_cli_elem('peerStatus')
    @peers.each { |peer| peer.status_xml(elem) }
    format_doc(elem)
  end

  def volume_info
    elem = make_cli_elem('volInfo').add_element('volumes')
    add_elem_text(elem, 'count', @volumes.size.to_s)
    @volumes.each { |volume| volume.info_xml(elem) }
    format_doc(elem)
  end
end
