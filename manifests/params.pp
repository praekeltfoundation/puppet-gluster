# Class: gluster::params
#
# Default parameters for various things.
#
class gluster::params {
  $repo_manage = true
  $repo_source = $::osfamily ? {
    'Debian' => 'gluster/glusterfs-3.7',
    default  => undef,
  }

  $package_manage = true
  $package_ensure = 'installed'
  $package_name = $::osfamily ? {
    'Debian' => 'glusterfs-server',
    default  => undef,
  }

  $service_manage = true
  $service_ensure = 'running'
  $service_name = $::osfamily ? {
    'Debian' => 'glusterfs-server',
    default  => undef,
  }
}
