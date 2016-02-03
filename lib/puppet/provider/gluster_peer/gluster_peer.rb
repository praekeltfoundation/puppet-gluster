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

  def create
    gluster_cmd('peer', 'probe', resource[:peer])
    # If there's no exception, we're done.
    @property_hash[:ensure] = :present
  rescue GlusterCmdError => e
    if e.opErrno == '107'
      # FIXME: Is this opErrno check narrow enough? Some other commands have
      # very different errors sharing an errno value.
      warning([
          "Peer '#{resource[:peer]}' unreachable, not actually creating.",
          "(#{e.opErrstr})"].join(' '))
    else
      raise e
    end
  end

  def destroy
    gluster_cmd('peer', 'detach', resource[:peer])
    @property_hash[:ensure] = :absent
  end

end
