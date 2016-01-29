require File.expand_path(File.join(File.dirname(__FILE__), '..', 'gluster'))

Puppet::Type.type(:gluster_peer).provide(
  :gluster_peer, :parent => Puppet::Provider::Gluster) do

  has_command(:gluster, 'gluster') do
    environment :HOME => "/tmp"
  end

  def self.instances
    all_peers.map do |peer|
      new(
        :name => peer,
        :peer => peer,
        :ensure => :present,
      )
    end
  end

  def self.prefetch(resources)
    peers = instances
    resources.keys.each do |name|
      if provider = peers.find{ |peer| peer.name == name }
        resources[name].provider = provider
      end
    end
  end

  def exists?
    @property_hash[:ensure] == :present
  end

  def handle_peer_probe(output)
    doc = REXML::Document.new(output)
    if xpath_first(doc, '/cliOutput/opRet/text()') == '0'
      # Success, we're done.
      @property_hash[:ensure] = :present
    else
      # TODO: Check that this works on older glusterfs as well.
      if xpath_first(doc, '/cliOutput/opErrno/text()') == '107'
        # This indicates an unreachable peer.
        warning(
          "Peer '#{resource[:peer]}' is unreachable, not actually creating.")
      else
        raise Puppet::ExecutionFailure, xpath_first(
          doc, '/cliOutput/opErrstr/text()')
      end
    end
  end

  def create
    handle_peer_probe(gluster_cmd('peer', 'probe', resource[:peer]))
  end

  def destroy
    gluster_cmd('peer', 'detach', resource[:peer])
    @property_hash[:ensure] = :absent
  end

end
