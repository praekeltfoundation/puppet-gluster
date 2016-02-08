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
class gluster(
  $repo_manage    = $gluster::params::repo_manage,
  $repo_source    = $gluster::params::repo_source,
  $package_manage = $gluster::params::package_manage,
  $package_ensure = $gluster::params::package_ensure,
  $package_name   = $gluster::params::package_name,
) inherits gluster::params {

  validate_bool($repo_manage)
  validate_bool($package_manage)

  # If $repo_manage is false, we still want to allow `gluster::repo` to be used
  # outside this class.
  if $repo_manage {
    class { 'gluster::repo':
      manage => $repo_manage,
      source => $repo_source,
    }
  }

  # If $package_manage is false, we still want to allow `gluster::install` to
  # be used outside this class.
  if $package_manage {
    class { 'gluster::install':
      ensure       => $package_ensure,
      manage       => $package_manage,
      package_name => $package_name,
    }
  }

}
