#

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

module "osimgs" {
  source   = "./osimgs"
  for_each = local.plexhosts

  remote = each.value
}

module "typeimgs" {
  source   = "./typeimgs"
  for_each = local.plexhosts

  remote   = each.value
  bakename = var.bakenode
}

module "imgdata" {
  source   = "./imgdata"
  for_each = local.plexhosts

  remote   = each.value
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
      "%s/${local.masklen}", local.hostdb[local.gatebyplex[each.value]]
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

data "incus_project" "default" {
  for_each = local.plexhosts
  remote   = each.value
  name     = "default"
}

#

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

data "incus_project" "plex" {
  for_each = local.plexhosts
  remote   = each.value
  name     = "plex"
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

data "incus_profile" "default" {
  for_each = local.plexhosts
  remote   = each.value
  name     = "default"
}

#

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

data "incus_profile" "nestpriv" {
  for_each = local.plexhosts
  remote   = each.value
  name     = "nestpriv"
}

#

resource "incus_profile" "protected" {
  name        = "protected"
  for_each    = local.plexhosts
  remote      = each.value
  description = "deletion-blocked"

  config = {
    "security.protection.delete" = "true"
  }
}

data "incus_profile" "protected" {
  for_each = local.plexhosts
  remote   = each.value
  name     = "protected"
}

###

resource "incus_instance" "scytus" {
  name        = "scytus"
  remote      = "vernius"
  profiles    = ["default", "protected"]
  description = "pki-host"
}

resource "incus_instance" "tekius" {
  name        = "tekius"
  remote      = "vernius"
  profiles    = ["default", "nestpriv", "protected"]
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

resource "incus_instance" "imgbake" {
  name        = var.bakenode
  for_each    = toset(var.baketime ? [var.bakehost] : [])
  remote      = each.value
  description = "imgbake-instance"

  type     = try(module.osimgs[var.bakehost].imgs[var.bakebase].source_image.type, "")
  image    = try(module.osimgs[var.bakehost].imgs[var.bakebase].fingerprint, "")
  running  = true
  profiles = ["default"]

  config = {
    "cloud-init.network-config" = sensitive(local.cloudinits.network-config)
    "cloud-init.user-data"      = sensitive(local.cloudinits.user-data)
  }

  # we'll only remove this manually in lxdbake.yml
  lifecycle {
    ignore_changes = all
  }
}

###

resource "ansible_vault" "sshprivkey" {
  for_each   = toset(keys(local.plexhocmap))
  vault_file = "${local.home}/keys/host/${each.value}.${local.domain}-id_rsa"

  vault_password_file = "${local.home}/bin/ansvault"
}

resource "incus_instance" "plexhocs" {
  for_each    = local.plexhocmap
  name        = each.key
  project     = data.incus_project.plex[each.value.plex].name
  remote      = each.value.plex
  description = "${each.value.plex}-plexhoc-${each.key}"

  type     = each.value.virt
  image    = module.imgdata[each.value.plex].imgs[each.value.fimg].fingerprint
  running  = true
  profiles = ["default"]

  lifecycle {
    ignore_changes = [image]
  }

  wait_for {
    type = "ipv4"
  }

  config = {
    "cloud-init.network-config" = <<-HERE
      #
      ---
      version: 2
      ethernets:
        eth0:
          addresses:
            - ${format("%s/%s", local.hostdb[each.key], local.masklen)}
          routes:
            - to: 0.0.0.0/0
              via: ${local.hostdb[local.gatebyplex[each.value.plex]]}
          nameservers:
            addresses:
              - 8.8.8.8
              - 8.8.4.4
    HERE

    # bake-time user-data is more complicated, but for nodes
    # instantiated from baked images, we only set hostname and ssh key
    #
    "cloud-init.user-data" = <<-HERE
      #cloud-config
      ---
      fqdn: ${each.key}.${local.domain}
      hostname: ${each.key}
      manage_etc_hosts: false
      manage_resolv_conf: false
      create_hostname_file: true
      prefer_fqdn_over_hostname: true
      preserve_sources_list: true
      ssh_keys:
        rsa_private: ${jsonencode(ansible_vault.sshprivkey[each.key].yaml)}
        rsa_public: ${jsonencode(file(format(
          "%s/keys/host/%s.%s-id_rsa.pub",
          local.home, each.key, local.domain)))}
      write_files:
        - path: /etc/hosts
          owner: root:root
          permissions: '0644'
          content: ${jsonencode(file("${local.home}/crypt/hostfiles/hosts"))}
    HERE
  }
}
