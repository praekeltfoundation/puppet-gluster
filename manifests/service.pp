# == Class: gluster::service
#
# Manages the gluster service.
#
# === Parameters
#
# [*manage*]
#   Whether to manage the service.
#
# [*ensure*]
#   Service ensure value.
#
# [*service_name*]
#   Name of the service to manage.
#
class gluster::service(
  $manage       = $gluster::params::service_manage,
  $ensure       = $gluster::params::service_ensure,
  $service_name = $gluster::params::service_name,
) inherits gluster::params {
  if $manage {
    service { $service_name:
      ensure => $ensure,
    }
    if $::osfamily == 'Debian' {
      include apt
      Class['apt::update'] -> Service[$service_name]
    }
  }
}
