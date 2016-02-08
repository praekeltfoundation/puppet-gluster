# == Class: gluster::repo
#
# Manages the repo to install gluster from. Currently only Ubuntu is supported.
#
# === Parameters
#
# [*manage*]
#   Whether to manage the repository.
#
# [*source*]
#   Repo source. Valid sources are:
#   * `gluster/glusterfs-3.7`
#
class gluster::repo(
  $manage = $gluster::params::repo_manage,
  $source = $gluster::params::repo_source,
) inherits gluster::params {
  if $manage {
    case $::operatingsystem {
      'Ubuntu': {
        include apt

        case $source {
          'gluster/glusterfs-3.7': {
            apt::ppa { 'ppa:gluster/glusterfs-3.7': }
          }
          default: {
            fail("APT repository '${source}' is not supported.")
          }
        }
        contain 'apt::update'

      }

      default: {
        fail("No repository information for OS '${::operatingsystem}'.")
      }
    }
  }
}
