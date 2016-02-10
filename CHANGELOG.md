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
