module XPathHelpers
  def value_if_text(node)
    case node.node_type
    when :text
      node.value
    else
      node
    end
  end

  def xpath_match(node, query)
    REXML::XPath.match(node, query).map { |r| value_if_text(r) }
  end

  def xpath_first(node, query)
    value_if_text(REXML::XPath.first(node, query))
  end
end

class Puppet::Provider::Gluster < Puppet::Provider

  # NOTE: This assumes that child providers define a `gluster` command:
  #
  # has_command(:gluster, 'gluster') do
  #   environment :HOME => '/tmp'
  # end

  # We want these to be both class and instance methods.
  extend XPathHelpers
  include XPathHelpers

  # Peer information

  def self.parse_peer_status(output)
    doc = REXML::Document.new(output)
    xpath_match(doc, '/cliOutput/peerStatus/peer/hostname/text()')
  end

  def self.gluster_cmd(*args)
    gluster('--xml', '--mode=script', *args)
  end

  def gluster_cmd(*args)
    gluster('--xml', '--mode=script', *args)
  end

  def self.all_peers
    parse_peer_status(gluster_cmd('peer', 'status'))
  end

  def self.peers_present(required_peers)
    peers = all_peers
    missing_peers = required_peers - peers
    if (required_peers - all_peers).empty?
      true
    else
      debug("Missing required peers: #{missing_peers.join(', ')}")
      false
    end
  end

  # Volume information

  def self.parse_volume_info(output)
    doc = REXML::Document.new(output)
    xpath_match(doc, '/cliOutput/volInfo/volumes/volume').map do |vol|
      extract_volume_info(vol)
    end
  end

  def self.volume_status(status_str)
    case status_str
    when 'Created'
      :stopped
    when 'Stopped'
      :stopped
    when 'Started'
      :started
    else
      alert("Unknown volume status: #{status_str}")
      :unknown
    end
  end

  def self.brick_peers(bricks)
    bricks.map { |brick| brick.split(':')[0] }.uniq
  end

  def self.extract_volume_info(vol_xml)
    vol = {
      :name => xpath_first(vol_xml, 'name/text()'),
      :status => volume_status(xpath_first(vol_xml, 'statusStr/text()')),
      :bricks => xpath_match(vol_xml, 'bricks/brick/name/text()'),
    }
    vol[:peers] = brick_peers(vol[:bricks])
    if vol[:status] == :started
      vol[:ensure] = :present
    else
      vol[:ensure] = vol[:status]
    end
    vol
  end

  def self.all_volumes
    output = gluster_cmd('volume', 'info', 'all')
    parse_volume_info(output)
  end

  def get_volume_info(name)
    # If we use the single-volume form of `gluster volume info` we'll have to
    # handle an error if the volume doesn't exist. This way we get an array of
    # size zero or one and `.first` turns that into a `volume_info` hash or
    # `nil`.
    vols = self.class.all_volumes.select { |v| v[:name] == name }
    vols.first
  end
end
