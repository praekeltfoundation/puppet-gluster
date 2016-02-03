class GlusterCmdError < Puppet::ExecutionFailure
  attr_reader :opRet, :opErrno, :opErrstr
  def initialize(opRet, opErrno, opErrstr)
    @opRet = opRet
    @opErrno = opErrno
    @opErrstr = opErrstr
    super("Execution failed (#{opRet}) #{opErrno}: #{opErrstr}")
  end
end

module GlusterCmdHelpers
  def value_if_text(node)
    return node.value if node.node_type == :text
    node
  end

  def xpath_match(node, query)
    REXML::XPath.match(node, query).map { |r| value_if_text(r) }
  end

  def xpath_first(node, query)
    value_if_text(REXML::XPath.first(node, query))
  end

  def cli_text(doc, path)
    xpath_first(doc, "/cliOutput/#{path}/text()")
  end

  def gluster_cmd(*args)
    output = gluster('--xml', '--mode=script', *args)
    doc = REXML::Document.new(output)
    if (opRet = cli_text(doc, 'opRet')) != '0'
      raise GlusterCmdError.new(
        opRet, cli_text(doc, 'opErrno'), cli_text(doc, 'opErrstr'))
    end
    doc
  end
end


class Puppet::Provider::Gluster < Puppet::Provider

  # NOTE: This assumes that child providers define a `gluster` command:
  #
  # has_command(:gluster, 'gluster') do
  #   environment :HOME => '/tmp'
  # end

  # We want these to be both class and instance methods.
  extend GlusterCmdHelpers
  include GlusterCmdHelpers

  # Peer information

  def self.parse_peer_status(doc)
    xpath_match(doc, '/cliOutput/peerStatus/peer/hostname/text()')
  end

  def self.all_peers
    parse_peer_status(gluster_cmd('peer', 'status'))
  end

  # Volume information

  def self.parse_volume_info(doc)
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
    parse_volume_info(gluster_cmd('volume', 'info', 'all'))
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
