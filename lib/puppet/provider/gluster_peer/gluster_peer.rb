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
    begin
      # FIXME: I think this behaviour is different with `--xml`.
      gluster('peer', 'probe', resource[:peer], '--xml')
    rescue Puppet::ExecutionFailure => e
      # Prior to 3.7, gluster returned a less helpful error when it couldn't
      # reach the peer it was probing.
      ['Probe returned with Transport endpoint is not connected',
       'Probe returned with unknown errno 107'].each do |msg|
        if e.message.chomp.end_with? "peer probe: failed: #{msg}"
          warning("Peer '#{resource[:peer]}' is unreachable," +
                  " not actually creating.")
          return
        end
      end
      raise
    end
    # We only set this if we've successfully changed state.
    @property_hash[:ensure] = :present
  end

  def destroy
    gluster('peer', 'detach', resource[:peer], '--xml')
    @property_hash[:ensure] = :absent
  end

end
