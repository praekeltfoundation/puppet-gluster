## 0.2.2-dev UNRELEASED

### Features
* `gluster::client` added.

## 0.2.1 2016-02-11

### Features
* Support for Puppet 4.x.

### Fixes
* Missing require added so the providers now work deliberately instead of
  accidentally.
* Test helper now excludes `gluster peer status` from configured errors to
  avoid breaking prefetch in integration tests.

## 0.2.0 2016-02-10

### Features
* `gluster::repo`, `gluster::install`, and `gluster::service` classes to manage
  the installation and operation of gluster and a a top-level `gluster` class
  to wrap them.

## 0.1.1 - 2016-02-05

### Fixes
* `gluster_peer` and `gluster_volume` now autorequire `Package[gluster-server]`.
* `gluster_volume` now autorequires the parent directories of any bricks on the
  current node.

## 0.1.0 - 2016-02-04
**Initial release**
* `gluster_peer` resource to configure cluster peers
* `gluster_volume` resource to create volumes
