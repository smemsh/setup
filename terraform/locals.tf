#

locals {
  hostdb = data.external.hosts.result

  # incus lvm uses image staging phase, configured by pool volume.size
  # while profile device size is for deployed volume.  we match for now.
  # https://discuss.linuxcontainers.org/t/15911
  #
  volsz = "${var.volsz}GiB"

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

  # we configure crio-d to use a zot oci registry cache for these domains
  # todo: this is currently duplicated in vars/kube.yml
  #
  oci_domains = ["ghcr", "docker", "gcr", "registry.k8s", "quay"]

  # read-through oci image cache for all the common registries, so testing
  # bootstraps goes a lot faster.  it can also be store local build artifacts
  #
  zotrc_json = {
    log     = { level = "debug" }
    http    = { address = "0.0.0.0", port = 5000, compat = ["docker2s2"] }
    storage = { rootDirectory = "/var/lib/registry", gc = false }
    extensions = {
      metrics = { enable = true }
      search  = { enable = true }
      events  = { enable = false }
      scrub   = { enable = false }
      lint    = { enable = false }
      trust   = { enable = false }
      ui      = { enable = false }
      sync    = {
        enable     = true
        registries = [
          for d in local.oci_domains : {
            urls           = ["https://${d}.io"]
            content        = [{ prefix = "**", destination = "/${d}" }]
            onDemand       = true
            tlsVerify      = false
            preserveDigest = true
          }
        ]
      }
    }
  }
}
