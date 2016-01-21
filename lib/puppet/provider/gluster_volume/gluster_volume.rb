require File.expand_path(File.join(File.dirname(__FILE__), '..', 'gluster'))

Puppet::Type.type(:gluster_volume).provide(
  :gluster_volume, :parent => Puppet::Provider::Gluster) do

  has_command(:gluster, 'gluster') do
    environment :HOME => "/tmp"
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

  def create_volume
    info("Creating volume #{resource[:name]} (#{@property_hash[:ensure]})")
    args = []
    if resource[:replica]
      args << "replica" << resource[:replica]
    end
    resource[:bricks].each { |brick| args << brick }
    if resource.force?
      args << "force"
    end
    gluster("volume", "create", resource[:name], args)
    update_volume_info
  end

  def start_volume
    info("Starting volume #{resource[:name]} (#{@property_hash[:ensure]})")
    gluster("volume", "start", resource[:name])
    update_volume_info
  end

  def stop_volume
    info("Stopping volume #{resource[:name]} (#{@property_hash[:ensure]})")
    gluster("volume", "stop", resource[:name], "--mode=script")
    update_volume_info
  end

  def delete_volume
    info("Deleting volume #{resource[:name]} (#{@property_hash[:ensure]})")
    gluster("volume", "delete", resource[:name], "--mode=script")
    update_volume_info
  end

  def update_volume_info
    vol_info = get_volume_info(resource[:name])
    @property_hash.merge! vol_info unless vol_info.nil?
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