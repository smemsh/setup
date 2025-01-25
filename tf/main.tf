#

locals {
  home = data.external.env.result.HOME

  domain  = "smemsh.net"
  masklen = 22

  plexhosts  = toset(["omnius", "vernius"])
  plexgates  = [for h in local.plexhosts : replace(h, "/us$/", "plex")]
  plexbyhost = zipmap(local.plexhosts, local.plexgates)

  volsz_default = "10GiB"
  volsz_plex    = "128GiB"

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

  omnicount = 1 # omniplexN will be the last host
  omnihosts  = toset([for n in range(1, local.omnicount + 1) : "omniplex${n}"])
}

###

data "external" "env" {
  program = ["jq", "-n", "env"]
}

data "external" "hosts" {
  program = ["${local.home}/bin/tfhosts"]
}
#output "debug_print" {
#  value = data.external.hosts
#}

data "external" "cloudinits" {
  count = var.baketime ? 1 : 0

  program = ["${local.home}/bin/tfcloudinit"]
  query = {
    host = local.cloudinit_id
  }
}

###

terraform {
  required_version = "1.9.0"
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "0.2.0"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.4"
    }
  }
  backend "local" {
    # path = ".terraform/terraform.tfstate"
    # todo: gcs, but must also setup encryption, and what about when lan
    #  but no internet? and what if gcs bucket became inaccessible?
    #  possibly, periodic statefile copies from gcs to local might
    #  accomplish this, backend could be switched to local then, as long
    #  as statefile is same format/information.  obviously if using gce
    #  nodes, if gcs is gone gce will probably be gone also so it would
    #  only matter for non-gce nodes
  }
}

provider "incus" {
  remote {
    name    = "local"
    scheme  = "unix"
    default = true
  }

  # :8443
  remote {
    name    = "omnius"
    scheme  = "https"
    address = "omnius.proxima"
  }
  remote {
    name    = "vernius"
    scheme  = "https"
    address = "vernius.proxima"
  }
}

###

resource "incus_image" "u22v" {
  for_each = local.plexhosts
  remote   = each.value
  aliases  = ["u22v"]
  source_image = {
    remote       = "images"
    name         = "ubuntu/22.04/cloud"
    type         = "virtual-machine"
    architecture = "x86_64"
  }

}

resource "incus_image" "u22v_adm" {
  for_each = toset(["omnius"])
  remote   = each.value

  aliases = ["u22v_adm"]
  source_instance = {
    # only matters at create-time, but we leave it persistent, so
    # subsequent runs rely on the bake-time instance, which typically
    # only exists when "-var baketime=true", hence the try clause
    name = try(incus_instance.imgbake[each.key].name, "")
  }

  lifecycle {
    ignore_changes = all
    # cannot do this because then it changes whether false or true as
    # long as it's different TODO figure out some way
    #replace_triggered_by = [terraform_data.imgrefresh["adm"]]
  }
}

###

resource "incus_network" "br0" {
  name        = "br0"
  for_each    = local.plexhosts
  remote      = each.value
  type        = "bridge"
  description = "host-bridged-br0"

  config = {
    "dns.mode"     = "none" # dnsmasq still starts, see upstream bug 1537
    "ipv6.address" = "none"
    "ipv4.address" = format(
      "%s/${local.masklen}", local.hostdb[local.plexbyhost[each.value]]
    )
    "ipv6.nat"      = "false"
    "ipv4.nat"      = "false"
    "ipv6.dhcp"     = "false"
    "ipv4.dhcp"     = "false"
    "ipv6.firewall" = "false"
    "ipv4.firewall" = "false"
  }
}

###

import {
  for_each = local.plexhosts

  to = incus_project.default[each.value]
  id = "${each.value}:default"
}

# featured resources are shared by any projects that disable feature
resource "incus_project" "default" {
  name        = "default"
  for_each    = local.plexhosts
  remote      = each.value
  description = "root-project"

  config = zipmap(
    [for ft in local.lxdfeatures : "features.${ft}"],
    [for _ in local.lxdfeatures : "true"]
  )

  lifecycle {
    # default project always exists, but terraform tries to replace
    ignore_changes = [remote]
  }
}

resource "incus_project" "plex" {
  name        = "plex"
  for_each    = local.plexhosts
  remote      = each.value
  description = "plex-project"

  config = zipmap(
    # share everything with the default project
    [for ft in local.lxdfeatures : "features.${ft}"],
    [for _ in local.lxdfeatures : "false"]
  )
}

###

resource "incus_storage_pool" "vpool" {
  for_each = local.plexhosts
  remote   = each.value

  name   = "vpool"
  driver = "lvm"
  config = {
    "lvm.thinpool_name" = "vthin"
    "lvm.vg_name"       = "vpool"
    # not sure why, but profile config on root device size= does not
    # seem to override this, so we we have them match for now
    "volume.size"       = local.volsz_plex
    #"volume.size"       = local.volsz_default
  }
}

###

import {
  for_each = local.plexhosts

  id = "${each.value}:default"
  to = incus_profile.default[each.value]
}

resource "incus_profile" "default" {
  name        = "default"
  for_each    = local.plexhosts
  remote      = each.value
  description = "host-bridged-br0"

  config = {
    "security.secureboot"     = "false"
    "security.idmap.isolated" = "true"
    "security.idmap.size"     = local.uidspace_unpriv
  }
  device {
    name = "eth0"
    type = "nic"
    properties = {
      name    = "eth0"
      network = "br0"
    }
    #properties = {
    #  name    = "eth0"
    #  parent  = "br0"
    #  nictype = "bridged"
    #}
  }
  device {
    name = "root"
    type = "disk"
    properties = {
      path = "/"
      pool = "vpool"
      size = local.volsz_plex
    }
  }
}

# systems that should be privileged and nest, ie k8s/podman/incus hosts
resource "incus_profile" "nestpriv" {
  name        = "nestpriv"
  for_each    = local.plexhosts
  remote      = each.value
  description = "privileged-nested"

  config = {
    "security.nesting"    = "true"
    "security.privileged" = "true"

    # nested incus host instance will need its own subuid/subgid files
    # *and* uidmap package installed.  OR if either is missing (former
    # won't ever be on a system with shadow-utils), incus defaults to
    # 1M:1B, but since outermost incus will have this same 1B, it should
    # be more restricted for inner container hosts (their total subuid
    # range should correspond to idmap size). some applies to k8s/docker
    # also.  note, changing /etc/sub[ug]id requires incus restart
    #
    "security.idmap.size" = local.uidspace_nestpriv
  }
}

###

resource "incus_instance" "scytus" {
  name        = "scytus"
  remote      = "vernius"
  description = "pki-host"
}

resource "incus_instance" "tekius" {
  name        = "tekius"
  remote      = "vernius"
  profiles    = ["default", "nestpriv"]
  description = "distrobuild-host"

  device {
    name = "imgdata"
    type = "disk"
    properties = {
      "path"   = "/data"
      "shift"  = "true"
      "source" = "/var/lib/incus/fs/tekius"
    }
  }
}

###

# set by an ansible play that initiates the bake and makes an image
variable "baketime" {
  description = "build-bakehost-yn"
  type        = bool
  default     = false
}

variable "bakehost" {
  description = "bakehost-remote"
  type        = string
  default     = ""
}

variable "bakenode" {
  description = "bakehost-nodename"
  type        = string
  default     = ""
}

resource "incus_instance" "imgbake" {
  name        = var.bakenode
  for_each    = toset(var.baketime ? [var.bakehost] : [])
  remote      = each.value
  description = "imgbake-instance"

  type     = "virtual-machine"
  image    = incus_image.u22v[each.value].fingerprint
  running  = true
  profiles = ["default"]

  config = {
    "cloud-init.network-config" = sensitive(local.cloudinits.network-config)
    "cloud-init.user-data"      = sensitive(local.cloudinits.user-data)
  }
}

###

resource "ansible_vault" "sshprivkey" {
  for_each   = local.omnihosts
  vault_file = "../keys/host/${each.value}.${local.domain}-id_rsa"

  vault_password_file = "../bin/ansvault"
}

resource "incus_instance" "omniadmv" {
  for_each    = local.omnihosts
  name        = each.value
  remote      = "omnius"
  description = "omniplex-instance-${each.value}"

  type     = "virtual-machine"
  image    = incus_image.u22v_adm["omnius"].fingerprint
  running  = true
  profiles = ["default"]

  config = {

    "cloud-init.network-config" = <<-HERE
      #
      ---
      version: 2
      ethernets:
        eth0:
          addresses:
            - ${format("%s/%s", local.hostdb[each.value], local.masklen)}
          routes:
            - to: 0.0.0.0/0
              via: ${local.hostdb[local.plexbyhost["omnius"]]}
          nameservers:
            addresses:
              - 8.8.8.8
              - 8.8.4.4
    HERE

    # bake-time user-data is more complicated, but for nodes
    # instantiated from baked images, we only set hostname ssh key
    #
    "cloud-init.user-data" = <<-HERE
      #cloud-config
      ---
      fqdn: ${each.value}.${local.domain}
      hostname: ${each.value}
      manage_etc_hosts: false
      manage_resolv_conf: false
      create_hostname_file: true
      prefer_fqdn_over_hostname: true
      ssh_keys:
        rsa_private: ${jsonencode(ansible_vault.sshprivkey[each.value].yaml)}
        rsa_public: ${jsonencode(file(format("../keys/host/%s.%s-id_rsa.pub",
                                             each.value, local.domain)))}
    HERE
  }
}
