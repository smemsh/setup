#

locals {
  bakerbyhost = zipmap(local.plexhosts, [for p in local.plexgates : "${p}0"])
}

resource "incus_profile" "baker" {
  name        = "baker"
  for_each    = var.baketime ? local.plexhosts : []
  remote      = each.value
  description = "baker-profile-cloudinit"
  config = {
    "cloud-init.network-config" = <<-HERE
      #
      ---
      version: 2
      ethernets:
        eth0:
          # this should get the first ethernet interface, might be named
          # ens2 but then with net.ifnames=1 and biosdevnames=0 kernel
          # args it should be called eth0.  note that the parent's name is
          # irrelevant, only used as a reference, and doesn't really mean
          # eth0; only the 'match' clause matters, if it's supplied
          # (otherwise, it does use its name as the match value)
          match:
            name: e*
          addresses:
            - ${format("%s/%s",
                  local.hostdb[local.bakerbyhost[each.value]],
                  local.masklen
              )}
          gateway4: ${local.hostdb[local.plexbyhost[each.value]]}
          nameservers:
            addresses:
              - 8.8.8.8
              - 8.8.4.4
      HERE

      "cloud-init.user-data" = data.external.cloudinit[0].result.user-data
      # "cloud-init.user-data" = <<-HERE
      #   ...
      # HERE
  }
}

resource "incus_instance" "imgbake" {
  profiles = ["default", "baker"]
}

# has the problem that when used as a replace_triggered_by, the trigger
# will always fire on any change of the value from its previous value,
# which includes giving false after it was last true.  which means there
# would always be an extra, unnecessary build triggered just to reset
# the state.  instead we are preferring to invoke by -destroy and target
# the resource, rather than use a variable indirection.
#
resource "terraform_data" "imgrefresh" {
  for_each = toset(var.imgtypes)
  input    = try(var.reimg[each.value], null)
}

# also tried adding this to the image resources definition, did not work

lifecycle {
  replace_triggered_by = [
    k for k in terraform_data.imgrefresh[var.imgtypes] if k != false
  ]
}

variable "imgtypes" {
  type = list(string)
  default = ["adm"]
}
variable "reimg" {
  type = map(bool)
  default = {
    adm = false
  }
}

# u22v
nodetypes = toset(["adm"])
allimgs   = setproduct(osvers, virtypes, nodetypes, hosts)

dynamic "settings" {
  for_each = local.ubuvers

resource "aws_ssm_patch_group" "environment_patch_group" {
  for_each = {
    for pair in local.os_for_env : "${pair[0]}:${pair[1]}" => {
      env = pair[0]
      os  = pair[1]
    }
  }
  count       = length(local.os_for_env)
  patch_group = "${each.value.env}_patch_group"
  baseline_id = data.aws_ssm_patch_baseline.baselines[each.value.os].id
}

variable "plexobjs" {
  description = "unrolled-plexhoc-node-object-list"
  type = list(
    map(object({
        plex = string
        base = string
        type = string
        nodes = list(number)
    }))
  )
  default = []
}

variable "instance_config" {
  type = map(object({
    instance_name  = string # omniplex1
    instance_image = string # u22v
    instance_type  = string # adm
  }))
  default = {}
}

variable "bakevirtype" {
  description = "instance-type-virt"
  type        = string
  default     = ""
}


  #provisioner "local-exec" {
  #  command = join(" ", [
  #    "ansible -m wait_for -a '",
  #      "host=${each.value.name} port=${var.sshport}",
  #      "timeout=${local.sshtimeout}",
  #      "search_regex=SSH",
  #    "'",
  #    "${each.value.plex}",
  #  ])
  #}

  ## allow kube init/join to finish, etc
  #provisioner "local-exec" {
  #  command = join(" ", [
  #    "ssh ${each.value.name}",
  #      "timeout ${local.kubeattrs.init_join_timeout}",
  #        "cloud-init status --wait",
  #  ])
  #}

# maintain each kube's master config in ~/.kube/<plex>.yml automatically
#resource "terraform_data" "kubeconfig" {
#  for_each = local.kubemasters
#
#  provisioner "local-exec" {
#    working_dir = local.home
#    command     = format(
#      "ssh %s sudo cat %s > .kube/%s.yml",
#      each.value.name,
#      local.kuberc,
#      local.gatebyplex[local.plexhocmap[each.value.name].plex],
#    )
#  }
#  triggers_replace = [incus_instance.plexhocs[each.value.name]]
#  lifecycle {
#    ignore_changes = all
#  }
#}

#resource "terraform_data" "kmasters" {
#  for_each = local.kubemasters
#
#  #lifecycle {
#  #  replace_triggered_by = [incus_instance.plexhocs[each.key]]
#  #}
#
#  input = {
#    dependency_trigger = incus_instance.plexhocs[each.key]
#
#    # lookup(local.kubemasters, each.value.name, null) == null
#    #? incus_instance.plexhocs[local.plexhocmap[ each.key == var.primary_node_key ? "primary" : terraform_data.node_order[var.primary_node_key].id
#  }
#}

  #input = {
  #  kubemaster_trigger = "test"
  #}

  #lifecycle {
  #  ignore_changes = all
  #}
  #depends_on = [
  #  incus_instance.plexhocs[
  #    local.plexhocmaps_kubemasters["verniplex1"]
  #  ]
  #]
  #  #    lookup(local.kubemasters, each.value.name, null) == null
  #  #  ? incus_instance.plexhocs[local.plexhocmap[

  # artificial dependency on the master so it always gets created first.
  # we cannot use depends_on because it needs a reference, not expression
  #
  #tags = {
  #  master = terraform_data.kubemaster[local.plexhocmaps_kubemasters[each.key]]
  #}
  #depends_on = [terraform_data.kubemasters]

  #  incus_instance.plexhocs[
  #    local.plexhocmaps_kubemasters["verniplex1"]
  #  ]
  #]
  #  #    lookup(local.kubemasters, each.value.name, null) == null
  #  #  ? incus_instance.plexhocs[local.plexhocmap[

  #description = join("-", [
  #  each.value.plex, "plexhoc", each.key,
  #  local.plexhocmaps_is_kctl[each.key] ? "master" : "slave-of",
  #  local.plexhocmaps_is_kwrk[each.key]  # artificial dependency on master
  #    ? terraform_data.kmasters[local.plexhocmaps_kubemasters[each.key]].id
  #    : "0"
  #  ]
  #)

#resource "local_file" "autodev_hook" {
#  content  = <<-HERE
#    #!/bin/bash
#    # so privileged container udev won't inject device add events to host
#    set -x
#    for path in /sys/{class/{drm,graphics,input},devices/pci*/*/drm/card?}
#    do mount -t tmpfs tmpfs $${path%drm/card?} -o ro,nosuid,nodev; done
#  HERE
#  filename        = pathexpand("~/.terraform.d/lxc-hook-autodev-headless.sh")
#  file_permission = "0755"
#}

  #file {
  #  target_path = "/etc/resolv.conf"
  #  content     = format("nameserver %s\n", "8.8.8.8")
  #}
  #device {
  #  name = "ociregfwd"
  #  type = "proxy"
  #  properties = {
  #    connect = "tcp:127.0.0.1:5000"
  #    listen = "tcp:${local.hostdb[local.gatebyplex[each.key]]}:5000"
  #  }
  #}


#resource "incus_storage_bucket" "oci_cache_bucket" {
#  for_each = var.plexhosts
#  name     = "ociblobs"
#  pool     = incus_storage_pool.vpool[each.key].name
#  project  = incus_project.default[each.key].name
#  remote   = each.key
#  config = {
#    size = local.ocisz
#  }
#  description = "kube-oci-cache-s3"
#}
#
#resource "incus_storage_bucket_key" "oci_bucket_key" {
#  for_each       = var.plexhosts
#  name           = "ocikey"
#  role           = "admin"
#  remote         = each.key
#  pool           = incus_storage_pool.vpool[each.key].name
#  project        = incus_project.default[each.key].name
#  storage_bucket = incus_storage_bucket.oci_cache_bucket[each.key].name
#  description    = "kube-oci-bucket-key"
#}

#resource "incus_server" "plexes" {
#  for_each = toset(["omnius", "vernius"])
#  remote = each.key
#  #config = {
#  #  "images.auto_update_interval" = "0"
#  #}
#}
