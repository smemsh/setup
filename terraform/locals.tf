#

locals {
  home   = data.external.env.result.HOME
  hostdb = data.external.hosts.result

  volsz_default = "10GiB"
  volsz_plex    = "32GiB"

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
      for ft in local.lxdfeatures: "features.${ft}" => boolstr
    }
  }

  cloudinits   = var.baketime ? data.external.cloudinits[0].result : null
  cloudinit_id = var.bakenode
}
