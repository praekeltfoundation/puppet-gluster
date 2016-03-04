# == Class: gluster::client
#
# Manages the gluster client package. Only use this if you need a client
# without a server. The `gluster` class manages the server package, which pulls
# in the client package as a dependency.
#
# === Parameters
#
# [*repo_manage*]
#   Whether to manage the repository.
#
# [*repo_source*]
#   Repo source. Valid sources are:
#   * `gluster/glusterfs-3.7`
#
# [*ensure*]
#   Package ensure value.
#
# [*package_name*]
#   Name of the package to manage.
#
class gluster::client(
  $repo_manage  = $gluster::params::repo_manage,
  $repo_source  = $gluster::params::repo_source,
  $ensure       = $gluster::params::package_ensure,
  $package_name = $gluster::params::client_package_name,
) inherits gluster::params {
  validate_bool($repo_manage)

  if $repo_manage {
    class { 'gluster::repo':
      manage => $repo_manage,
      source => $repo_source,
      before => Package[$package_name],
    }
  }

  package { $package_name:
    ensure => $ensure,
  }
}
