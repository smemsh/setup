#

locals {
  hostdb = data.external.hosts.result

  # incus lvm uses image staging phase, configured by pool volume.size
  # while profile device size is for deployed volume.  we match for now.
  # https://discuss.linuxcontainers.org/t/15911
  #
  volsz = "${var.volsz}GiB"

  # when many systems startup at once there can be a delay connecting on
  # ssh for some of the nodes ever after ipv4 is up, but terraform wait_for
  # has no ports so we use an ansible wait_for with local-exec
  #
  sshtimeout = 45

  # posix systems need 64k uids, and let container hosts nest 1k such systems
  uidspace_unpriv   = 64 * 1024
  uidspace_nestpriv = local.uidspace_unpriv * 1024

  lxdfeatures = [
    "images", "profiles",
    "networks", "networks.zones",
    "storage.volumes", "storage.buckets"
  ]
  lxdfeatures_preset = {
    for boolstr in ["true", "false"] : boolstr => {
      for ft in local.lxdfeatures : "features.${ft}" => boolstr
    }
  }

  cloudinits   = var.baketime ? data.external.cloudinits[0].result : null
  cloudinit_id = var.bakenode
}
