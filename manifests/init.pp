# == Class: gluster
#
# Currently empty, will contain some things eventually.
class gluster(
  $repo_manage = $gluster::params::repo_manage,
  $repo_source = $gluster::params::repo_source,
) inherits gluster::params {

  validate_bool($repo_manage)

  # If $repo_manage is false, we still want to allow `gluster::repo` to be used
  # outside this class.
  if $repo_manage {
    class { 'gluster::repo':
      manage => $repo_manage,
      source => $repo_source,
    }
  }
}
