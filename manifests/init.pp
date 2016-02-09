# == Class: gluster
#
# [*repo_manage*]
#   Whether to manage the repository.
#
# [*repo_source*]
#   Repo source. Valid sources are:
#   * `gluster/glusterfs-3.7`
#
# [*package_manage*]
#   Whether to manage the package.
#
# [*package_ensure*]
#   Package ensure value.
#
# [*package_name*]
#   Name of the package to manage.
#
# [*service_manage*]
#   Whether to manage the service.
#
# [*service_ensure*]
#   Service ensure value.
#
# [*service_name*]
#   Name of the service to manage.
#
class gluster(
  $repo_manage    = $gluster::params::repo_manage,
  $repo_source    = $gluster::params::repo_source,
  $package_manage = $gluster::params::package_manage,
  $package_ensure = $gluster::params::package_ensure,
  $package_name   = $gluster::params::package_name,
  $service_manage = $gluster::params::service_manage,
  $service_ensure = $gluster::params::service_ensure,
  $service_name   = $gluster::params::service_name,
) inherits gluster::params {

  validate_bool($repo_manage)
  validate_bool($package_manage)
  validate_bool($service_manage)

  class { 'gluster::repo':
    manage => $repo_manage,
    source => $repo_source,
  }

  class { 'gluster::install':
    ensure       => $package_ensure,
    manage       => $package_manage,
    package_name => $package_name,
  }

  class { 'gluster::service':
    ensure       => $service_ensure,
    manage       => $service_manage,
    service_name => $service_name,
  }

  if $package_manage and $service_manage {
    Package[$package_name] ~> Class['gluster::service']
  }

  anchor { 'gluster::begin': }
  -> Class['gluster::repo']
  -> Class['gluster::install']
  -> Class['gluster::service']
  -> anchor { 'gluster::end': }

}
