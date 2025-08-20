#

locals {
  home = data.external.env.result.HOME

  domain  = "smemsh.net"
  masklen = 22

  plexhosts  = toset(["omnius", "vernius"])
  plexgates  = [for h in local.plexhosts : replace(h, "/us$/", "plex")]
  gatebyplex = zipmap(local.plexhosts, local.plexgates)

  volsz_default = "10GiB"
  volsz_plex    = "32GiB"

  # posix systems need 64k uids, and let container hosts nest 1k such systems
  uidspace_unpriv   = 64 * 1024
  uidspace_nestpriv = local.uidspace_unpriv * 1024

  lxdfeatures = [
    "networks", "networks.zones",
    "images", "profiles",
    "storage.volumes", "storage.buckets"
  ]

  hostdb = data.external.hosts.result

  cloudinits   = var.baketime ? data.external.cloudinits[0].result : null
  cloudinit_id = var.bakenode
}
