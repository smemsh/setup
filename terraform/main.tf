#

data "external" "env" {
  program = ["jq", "-n", "env"]
}

data "external" "hosts" {
  program = [pathexpand("~/bin/tfhosts")]
}

data "external" "cloudinits" {
  count = var.baketime ? 1 : 0

  program = [pathexpand("~/bin/tfcloudinit")]
  query = {
    host = local.cloudinit_id
  }
}

###

module "osimgs" {
  source   = "./osimgs"
  for_each = var.plexhosts

  remote = each.value
  osimgs = local.osimgs
}

module "typeimgs" {
  source   = "./typeimgs"
  for_each = var.plexhosts

  remote   = each.value
  bakename = var.bakenode
  allfimgs = local.allfimgs
}

module "imgdata" {
  source   = "./imgdata"
  for_each = var.plexhosts

  remote   = each.value
  allfimgs = local.allfimgs
}

module "cloudinit" {
  source   = "./cloudinit"
  nodemap  = local.plexhocmap
  gatemap  = local.gatebyplex
  hostdb   = local.hostdb
  domain   = var.domain
  masklen  = var.masklen
  nslist   = var.resolvers
  is_knode = local.plexhocmaps_is_knode
  is_kctl  = local.plexhocmaps_is_kctl
}

###

resource "incus_network" "br0" {
  name        = "br0"
  for_each    = var.plexhosts
  remote      = each.value
  type        = "bridge"
  description = "host-bridged-br0"

  config = {
    "dns.mode"     = "none" # dnsmasq still starts, see upstream bug 1537
    "ipv6.address" = "none"
    "ipv4.address" = format(
      "%s/%d", local.hostdb[local.gatebyplex[each.value]], var.masklen
    )
    "ipv6.nat"      = "false"
    "ipv4.nat"      = "false"
    "ipv6.dhcp"     = "false"
    "ipv4.dhcp"     = "false"
    "ipv6.firewall" = "false"
    "ipv4.firewall" = "false"
  }

  lifecycle {
    prevent_destroy = true
  }
}

###

import {
  for_each = var.plexhosts

  to = incus_project.default[each.value]
  id = "${each.value}:default"
}

# featured resources are shared by any projects that disable feature
resource "incus_project" "default" {
  name        = "default"
  for_each    = var.plexhosts
  remote      = each.value
  config      = local.lxdfeatures_preset["true"]
  description = "root-project"
}

#

resource "incus_project" "plex" {
  name        = "plex"
  for_each    = var.plexhosts
  remote      = each.value
  config      = local.lxdfeatures_preset["false"]  # share with default
  description = "plex-project"
}

###

resource "incus_storage_pool" "vpool" {
  for_each = var.plexhosts
  remote   = each.value

  name   = "vpool"
  driver = "lvm"
  config = {
    "lvm.thinpool_name" = "vthin"
    "lvm.vg_name"       = "vpool"
    "volume.size"       = local.volsz
  }

  lifecycle {
    prevent_destroy = true
  }
}

###

import {
  for_each = var.plexhosts

  id = "${each.value}:default"
  to = incus_profile.default[each.value]
}

resource "incus_profile" "default" {
  name        = "default"
  for_each    = var.plexhosts
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
      size = local.volsz
    }
  }
}

# systems that should be privileged and nest, ie k8s/podman/incus hosts
resource "incus_profile" "nestpriv" {
  name        = "nestpriv"
  for_each    = var.plexhosts
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
    # range should correspond to idmap size). same applies to k8s/docker
    # also.  note, changing /etc/sub[ug]id requires incus restart
    #
    "security.idmap.size" = local.uidspace_nestpriv
  }
}

resource "incus_profile" "knode" {
  name        = "knode"
  for_each    = var.plexhosts
  remote      = each.value
  description = "kubernetes-node"

  config = {
    "limits.cpu"            = "2"
    "limits.memory"         = "4GiB"
    "limits.memory.enforce" = "hard"
    "raw.lxc"               = <<-HERE
      lxc.cgroup2.devices.allow = a
      lxc.apparmor.profile      = unconfined
      lxc.mount.entry           = /dev/kmsg dev/kmsg none defaults,bind,create=file
      lxc.mount.auto            = proc:rw sys:rw
      lxc.log.level             = 1
      lxc.cap.drop              =
    HERE
  }

  device {
    name = "boot"
    type = "disk"
    properties = {
      readonly = true
      source   = "/boot"
      path     = "/boot"
    }
  }
  device {
    name = "kmsg"
    type = "unix-char"
    properties = {
      source = "/dev/kmsg"
    }
  }
}

#

resource "incus_profile" "protected" {
  name        = "protected"
  for_each    = var.plexhosts
  remote      = each.value
  description = "deletion-blocked"

  config = {
    "security.protection.delete" = "true"
  }
}

###

resource "incus_instance" "scytus" {
  name        = "scytus"
  remote      = "vernius"
  profiles    = ["default", "protected"]
  description = "pki-host"

  lifecycle {
    prevent_destroy = true
  }
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
      path   = "/data"
      shift  = "true"
      source = "/var/lib/incus/fs/tekius"
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}

###

# todo: this should be in its own root module with separate state.  likewise,
# the separate cloudinits baketime data source that comes running ansrole
# cloudinit, vs cloudinits module that comes from terraform templatefile(),
# will likely cause confusion if we haven't looked at this in a while.
#
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
# sadly, we have to triple this block to have appropriate dependencies:
# plexwrks depend on plexctls, and plexnons depend on neither. after much
# research and testing, there was no way found to do this with depends_on
# because invariably it resulted in self-referential dependencies or required
# an evaluative expression, which is disallowed in that context.  furthermore,
# terraform does not add specific instances to the dependency tree.  probably
# the best we can do is try to make this into a module and "call" with
# different arguments TODO
#

resource "incus_instance" "kubemasters" {
  for_each    = local.plexctlmap
  name        = each.key
  project     = var.project
  remote      = each.value.plex
  description = "${each.value.plex}-kubemaster-${each.key}"

  type     = each.value.virt
  image    = module.imgdata[each.value.plex].imgs[each.value.fimg].fingerprint
  profiles = local.plexhocmaps_profiles[each.key]

  wait_for  { type = "ipv4" }
  lifecycle { ignore_changes = [image, config] }

  provisioner "local-exec" { command = "tfpvn create ${each.key}" }

  config = {
    "cloud-init.network-config" = module.cloudinit.netconfig[each.key]
    "cloud-init.user-data"      = module.cloudinit.userdata[each.key]
  }
}

resource "incus_image" "registryimg" {
  for_each = var.plexhosts
  project  = incus_project.default[each.key].name
  remote   = each.key
  source_image = {
    remote = "docker"
    name   = "registry"
  }
}

resource "incus_instance" "kubeslaves" {
  for_each    = local.plexwrkmap
  name        = each.key
  project     = var.project
  remote      = each.value.plex
  description = "${each.value.plex}-kubeslave-${each.key}-master-${
    incus_instance.kubemasters[local.plexhocmaps_kubemasters[each.key]].name
  }"

  type       = each.value.virt
  image      = module.imgdata[each.value.plex].imgs[each.value.fimg].fingerprint
  profiles   = local.plexhocmaps_profiles[each.key]
  depends_on = [incus_instance.kubemasters]

  wait_for {
    type = "ipv4"
  }

  lifecycle {
    ignore_changes       = [image, config]
    #replace_triggered_by = [incus_instance.kubemasters]  # todo: multi-master
  }

  provisioner "local-exec" {
    command = "tfpvn create ${each.key}"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "tfpvn destroy ${each.key}"
  }

  config = {
    "cloud-init.network-config" = module.cloudinit.netconfig[each.key]
    "cloud-init.user-data"      = module.cloudinit.userdata[each.key]
  }
}

###

# each plexhost-oci:5000 is an oci registry pull-through cache for k8s.io
resource "incus_instance" "plexocireg" {
  for_each    = var.plexhosts
  name        = "${local.gatebyplex[each.key]}-oci"
  description = "${local.gatebyplex[each.key]}-oci-registry-cache"

  profiles = ["default"]
  project  = incus_project.default[each.key].name
  remote   = each.key
  image    = incus_image.registryimg[each.key].fingerprint
  config = {
    "environment.REGISTRY_PROXY_REMOTEURL" = "https://registry.k8s.io"
    "environment.OTEL_TRACES_EXPORTER"     = "none"
    "raw.lxc" = <<-HERE
      lxc.log.level = 1
      lxc.net.0.ipv4.gateway = ${local.hostdb[local.gatebyplex[each.key]]}
      lxc.net.0.ipv4.address = ${format("%s/%d",
        local.hostdb["${local.gatebyplex[each.value]}-oci"], var.masklen
      )}
      # lxc.mount.entry has no way to subtract.
      # todo: /var/lib/incus/containers/*/network/ files should not mount.
      # this has something to do with incus forknet.
      #
      lxc.hook.mount = /bin/sh -c '${join("; ", concat(
        ["root=$LXC_ROOTFS_MOUNT"],
        ["umount -l $root/etc/resolv.conf"],
        [for ns in var.resolvers :
          "echo nameserver ${ns} >> $root/tmp/resolv.conf"],
        ["mv $root/tmp/resolv.conf $root/etc/"],
      ))}'
    HERE
  }
  lifecycle { ignore_changes = [image, config] }
}

resource "incus_instance" "plexnons" {
  for_each    = local.plexnonmap
  name        = each.key
  project     = var.project
  remote      = each.value.plex
  description = "${each.value.plex}-plexnon-${each.key}"

  type     = each.value.virt
  image    = module.imgdata[each.value.plex].imgs[each.value.fimg].fingerprint
  profiles = local.plexhocmaps_profiles[each.key]

  wait_for  { type = "ipv4" }
  lifecycle { ignore_changes = [image, config] }

  config = {
    "cloud-init.network-config" = module.cloudinit.netconfig[each.key]
    "cloud-init.user-data"      = module.cloudinit.userdata[each.key]
  }
}
