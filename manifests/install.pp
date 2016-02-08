# == Class: gluster::install
#
# Manages the gluster package.
#
# === Parameters
#
# [*manage*]
#   Whether to manage the package.
#
# [*ensure*]
#   Package ensure value.
#
# [*package_name*]
#   Name of the package to manage.
#
class gluster::install(
  $manage       = $gluster::params::package_manage,
  $ensure       = $gluster::params::package_ensure,
  $package_name = $gluster::params::package_name,
) inherits gluster::params {
  if $manage {
    package { $package_name:
      ensure => $ensure,
    }
  }
}
