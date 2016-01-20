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

  newparam(:ignore_peers, :array_matching => :all) do
    desc ("Peer addresses to ignore. " +
          "This should include anything that resolves to the current host.")
    defaultto []

    munge do |val|
      facts = ['fqdn', 'hostname', 'ipaddress', 'ipaddress_lo']
      Array(val) + facts.map { |n| Facter[n] }.compact.map { |f| f.value }
    end
  end

  def ignore?
    value(:ignore_peers).include? value(:peer)
  end

  autorequire(:package) do
    "glusterfs-server"
  end
end
