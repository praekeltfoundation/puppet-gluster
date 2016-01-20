Puppet::Type.newtype(:gluster_volume) do
  desc <<-'ENDOFDESC'
  Defines a glusterfs peer to probe.

    Example:

      gluster_volume { 'volume1':
        replica => 2,
        bricks  => [
          'gfs1.local:/data/brick1',
          'gfs2.local:/data/brick1',
        ],
      }

  ENDOFDESC

  ensurable do
    newvalue(:present) do
      provider.create
    end
    newvalue(:stopped) do
      provider.ensure_stopped
    end
    newvalue(:absent) do
      provider.destroy
    end
    defaultto(:present)

    # We don't want to just use `exists?` here.
    def retrieve
      provider.get(:ensure)
    end
  end

  # TODO: More params, etc.

  newparam(:name, :namevar => true)

  newparam(:force, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    defaultto :false
  end

  newparam(:replica)

  newparam(:bricks, :array_matching => :all) do
    desc "List of bricks backing the volume."

    munge do |val|
      Array(val)
    end
  end

  autorequire(:package) do
    "glusterfs-server"
  end

  autorequire(:gluster_peer) do
    peers = value(:bricks).map { |brick| brick.split(":")[0] }.uniq
    info("peers: #{peers}")
    peers
  end
end
