require File.expand_path(File.join(File.dirname(__FILE__), '..', 'gluster'))

Puppet::Type.type(:gluster_volume).provide(
  :gluster_volume, :parent => Puppet::Provider::Gluster) do

  has_command(:gluster, 'gluster') do
    environment :HOME => '/tmp'
  end

  def self.instances
    all_volumes.map do |volume|
      new(
        :name => volume[:name],
        :ensure => volume[:ensure],
      )
    end
  end

  def self.prefetch(resources)
    volumes = instances
    resources.keys.each do |name|
      if provider = volumes.find { |volume| volume.name == name }
        resources[name].provider = provider
      end
    end
  end

  def missing_peers
    # We know about a peer if the cluster knows about it or if it's a local
    # alias.
    peers = self.class.all_peers + resource[:local_peer_aliases]
    # Extract and dedupe peer addresses from the volume bricks.
    required_peers = resource[:bricks].map { |brick| brick.split(':')[0] }.uniq
    # Return a list of all brick peers we don't know about.
    required_peers - peers
  end

  def create_volume
    info("Creating volume #{resource[:name]} (#{@property_hash[:ensure]})")
    args = []
    if resource[:replica]
      args << 'replica' << resource[:replica]
    end
    resource[:bricks].each { |brick| args << brick }
    if resource.force?
      args << 'force'
    end
    gluster_cmd('volume', 'create', resource[:name], *args)
    update_volume_info
  end

  def start_volume
    info("Starting volume #{resource[:name]} (#{@property_hash[:ensure]})")
    gluster_cmd('volume', 'start', resource[:name])
    update_volume_info
  end

  def stop_volume
    info("Stopping volume #{resource[:name]} (#{@property_hash[:ensure]})")
    gluster_cmd('volume', 'stop', resource[:name])
    update_volume_info
  end

  def delete_volume
    info("Deleting volume #{resource[:name]} (#{@property_hash[:ensure]})")
    gluster_cmd('volume', 'delete', resource[:name])
    update_volume_info
  end

  def update_volume_info
    vol_info = get_volume_info(resource[:name])
    if vol_info.nil?
      @property_hash[:ensure] = :absent
    else
      @property_hash.merge! vol_info unless vol_info.nil?
    end
  end

  def create
    # Create the volume if it doesn't exist.
    if @property_hash.fetch(:ensure, :absent) == :absent
      create_volume
    end

    # Start the volume if it's stopped.
    if @property_hash[:ensure] == :stopped
      start_volume
    end
  end

  def ensure_stopped
    # Create the volume if it doesn't exist.
    if @property_hash.fetch(:ensure, :absent) == :absent
      create_volume
    end

    # Stop the volume if it's running.
    if @property_hash[:ensure] == :present
      stop_volume
    end
  end

  def destroy
    # Stop the volume if it's running.
    if @property_hash[:ensure] == :present
      stop_volume
    end

    # Delete the volume if it's stopped.
    if @property_hash[:ensure] == :stopped
      delete_volume
    end
  end

end
