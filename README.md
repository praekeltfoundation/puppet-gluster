# puppet-gluster

Puppet module for managing glusterfs.

Unlike other glusterfs modules, this one uses custom types and providers to
avoid needing multiple runs to set up interdependent resources and to
gracefully handle missing peers.

This is particularly useful when provisioning VMs with vagrant.

## WARNING

This is pretty much just a prototype at the moment. Its functionality is quite
limited and it hasn't been tested on a wide variety of environments. It meets
our fairly needs, but we wouldn't recommend using it in production without
hammering on it a bit first.


## Usage

The `gluster` class manages the installation and running of the
`glusterfs-server` service. Repo and package management is only implemented for
Ubuntu, however.

```puppet
class { 'gluster':
  package_ensure => 'latest',
  service_ensure => 'running',
}
```

For a full list of options see the [manifest source](manifests/init.pp).

In most cases the defaults should be suitable and a simple `include gluster`
will suffice.


### `gluster_peer`

The `gluster_peer` resource sets up peer relationships between the nodes by
running `gluster peer probe` as necessary. If a peer can't be reached, the
resource will log a warning and pretend success to avoid unnecessary failures
during cluster bootstrapping.

```puppet
gluster_peer { ['gfs1.local', 'gfs2.local']:
    ensure => present,
}
```

Peers may be removed by setting `ensure` to `absent`.

```puppet
gluster_peer { oldgfs1.local':
    ensure => absent,
}
```

To avoid continually probing localhost, `gluster_peer` ignores peers that match
the `fqdn` and `hostname` facts. Other peer names can be ignored with the
`local_peer_aliases` param, which can be useful if a host has multiple names.

```puppet
gluster_peer { ['gfs1.local', 'gfs2.local']:
    ensure             => present,
    local_peer_aliases => [$gfs_host_alias],
}
```

The `gluster_peer` resource sets up peer relationships between the nodes by
running `gluster peer probe` as necessary.


### `gluster_volume`

The `gluster_volume` resource manages a glusterfs volume. If any hosts
mentioned in the `bricks` list aren't active peers, the resource will log a
message and pretend to be in sync to avoid unnecessary failures during cluster
bootstrapping.

`Gluster_peer` resources for all hosts mentioned in the `bricks` list will be
autorequired, as will `File` resources for the parent directories of brick
paths on the local peer.

```
gluster_volume { 'volume1':
    bricks => [
        'gfs1.local:/data/brick1',
        'gfs2.local:/data/brick1',
    ],
}
```

As with `gluster_peer`, aliases for the local peer can be provided.

```
gluster_volume { 'volume1':
    local_peer_aliases => [$gfs_host_alias],
    bricks             => [
        'gfs1.local:/data/brick1',
        'gfs2.local:/data/brick1',
    ],
}
```

Currently, the only volume type parameter accepted is `replica`. (We expect to
support the others in the future.)

```
gluster_volume { 'volume1':
    replica => 2,
    bricks  => [
        'gfs1.local:/data/brick1',
        'gfs2.local:/data/brick1',
    ],
}
```

The `ensure` parameter accepts the values `present`, `absent`, and `stopped`.
`present` indicates that the volume should be running, `absent` indicates that
the volume should not exist, and `stopped` indicates that the volume should
exist but not be running.
