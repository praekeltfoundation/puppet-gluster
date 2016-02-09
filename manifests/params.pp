# Class: gluster::params
#
# Default parameters for various things.
#
class gluster::params {
  $repo_manage = true
  $repo_source = $::operatingsystem ? {
    'Ubuntu' => 'gluster/glusterfs-3.7',
    default  => undef,
  }

  $package_manage = true
  $package_ensure = 'installed'
  $package_name = 'glusterfs-server'

  $service_manage = true
  $service_ensure = 'running'
  $service_name = 'glusterfs-server'
}
