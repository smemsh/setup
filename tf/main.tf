#

locals {
  home = data.external.env.result.HOME

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
}

data "external" "env" {
  program = ["jq", "-n", "env"]
}

data "external" "hosts" {
  program = ["${local.home}/bin/tfhosts"]
}
#output "debug_print" {
#  value = data.external.hosts
#}

terraform {
  required_version = "1.8.7"
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "0.2.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.4"
    }
  }
  backend "local" {
    # path = ".terraform/terraform.tfstate"
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
      "%s/22", local.hostdb[local.plexbyhost[each.value]]
    )
    "ipv6.nat"      = "false"
    "ipv4.nat"      = "false"
    "ipv6.dhcp"     = "false"
    "ipv4.dhcp"     = "false"
    "ipv6.firewall" = "false"
    "ipv4.firewall" = "false"
  }
}

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

resource "incus_storage_pool" "vpool" {
  for_each = local.plexhosts
  remote   = each.value

  name   = "vpool"
  driver = "lvm"
  config = {
    "lvm.thinpool_name" = "vthin"
    "lvm.vg_name"       = "vpool"
    "volume.size"       = local.volsz_default
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
  # TODO tekius has a shared mount?
  # how to do this with security.idmap.isolated?
  #   - setting raw.idmap to share should work, but leaves that uid able to be
  #     controlled on the host from within the container.  also see disk
  #     device config propagation, recursive, and shift options
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
