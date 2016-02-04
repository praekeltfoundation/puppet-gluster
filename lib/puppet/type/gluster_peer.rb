Puppet::Type.newtype(:gluster_peer) do
  desc <<-'ENDOFDESC'
  Defines a glusterfs peer to probe.

    Example:

      gluster_peer { ['gfs1.local', 'gfs2.local']:
        ensure => present,
      }

  ENDOFDESC

  ensurable do
    defaultvalues
    defaultto(:present)

    # We want to ignore the ignored peers here.
    def property_matches?(current, desired)
      if current != desired and resource.ignore?
        info("Ignoring '#{resource[:peer]}' (pretending it's #{desired})")
        return true
      end
      # We're not pretending, so invoke the original method.
      super
    end
  end

  newparam(:peer, :namevar => true)

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

  def ignore?
    value(:local_peer_aliases).include? value(:peer)
  end

  autorequire(:service) do
    'glusterfs-server'
  end
end
