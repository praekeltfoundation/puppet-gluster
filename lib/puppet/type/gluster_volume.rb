require 'puppet/parameter/boolean'

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

    # We can't just use the default `exists?` check here, because we don't have
    # a binary value.
    def retrieve
      provider.get(:ensure)
    end

    # We want to ignore volumes with missing peers here.
    def property_matches?(current, desired)
      if current != desired
        missing_peers = provider.missing_peers
        unless missing_peers.empty?
          info([
              "Ignoring '#{resource[:name]}' (pretending it's #{desired})",
              'because the following peers are missing:',
              missing_peers.join(', '),
            ].join(' '))
          return true
        end
      end
      # We're not pretending, so invoke the original method.
      super
    end
  end

  # TODO: More params, etc.

  newparam(:name, :namevar => true)

  newparam(:force, :boolean => true, :parent => Puppet::Parameter::Boolean) do
    defaultto :false
  end

  newparam(:replica) do
    desc "Number of replicas for a replicated volume."

    validate do |val|
      info("replica: #{val.inspect}")
      if val.to_s !~ /^\d+$/ or Integer(val) < 2
        raise ArgumentError, "if present, replica must be an integer >= 2"
      end
    end

    munge { |val| Integer(val) }
  end

  newparam(:bricks, :array_matching => :all) do
    desc "List of bricks backing the volume."
    defaultto []

    munge { |val| Array(val) }
  end

  newparam(:local_peer_aliases, :array_matching => :all) do
    desc([
        'Other names for the current host.',
        'Anything included here will be ignored when checking peers.',
      ].join(' '))
    defaultto []

    munge do |val|
      facts = [:fqdn, :hostname, :ipaddress]
      Array(val) + facts.map { |f| Facter.value(f) }.compact
    end
  end

  autorequire(:service) { 'glusterfs-server' }
  autorequire(:package) { 'glusterfs-server' }
  autorequire(:gluster_peer) do
    value(:bricks).map { |brick| brick.split(":")[0] }.uniq
  end
  autorequire(:file) do
    files = []
    value(:bricks).each do |brick|
      peer, dir = brick.split(":")
      files << dir if value(:local_peer_aliases).include? peer
    end
    files.uniq
  end
end
