###
# original impetus:
#   sadly, we have to triple this block to have appropriate dependencies:
#   plexwrks depend on plexctls, and plexnons depend on neither. after much
#   research and testing, there was no way found to do this with depends_on
#   because invariably it resulted in self-referential dependencies or required
#   an evaluative expression, which is disallowed in that context.
#   furthermore, terraform does not add specific instances to the dependency
#   tree.  probably the best we can do is try to make this into a module and
#   "call" with different arguments
#

resource "incus_instance" "knode" {
  for_each    = var.nodemap
  name        = each.key
  project     = var.project
  remote      = each.value.plex
  description = "${each.value.plex}-${each.key}"

  type     = each.value.virt
  image    = var.imgdata.imgs[each.value.fimg].fingerprint
  profiles = var.profiles[each.key]

  wait_for { type = "ipv4" }

  lifecycle {
    ignore_changes       = [image, config]
    replace_triggered_by = [terraform_data.master]
  }

  provisioner "local-exec" {
    command = "tfpvn create ${each.key}"
  }
  provisioner "local-exec" {
    when    = destroy
    command = "tfpvn destroy ${each.key}"
  }

  config = {
    "cloud-init.network-config" = var.netconfig[each.key]
    "cloud-init.user-data"      = var.userdata[each.key]
  }
}

locals {
  is_slave  = nonsensitive(var.master) != null
  is_master = !local.is_slave
}

# for slaves, the indirect dependency on master node allows an evaluative
# expression to work in replace_triggered_by context.  coupled with depends_on
# in the module for ordering dependency.  todo: this means we have a useless
# terraform_data for the kubemasters module instance, which will just have a
# null output (see note about attempts to use count), but potentially this
# resource could be used to hold other state for some later purpose
#
resource "terraform_data" "master" {

  # todo: for volatile.id, resubmit issue 326
  input = local.is_slave ? var.master.mac_address : null

  # after deleting a slave node, using either of these expressions results in:
  # no change found for terraform_data.master in module.kubemasters[<plexhost>]
  # so until this is solved, we have to keep a stubbed resource even if unused.
  #
  # count = local.is_slave ? 1 : 0
  # lifecycle { enabled = local.is_slave ? true: false }
  # lifecycle { enabled = length(var.nodemap) > 1 }
}

# so we don't bootstrap a workload until least two slaves.  see notes on
# terraform_data.master, which also apply here (map count is heuristic only).
#
resource "terraform_data" "ready" {
  input      = length(var.nodemap) >= 2
  depends_on = [incus_instance.knode]
  provisioner "local-exec" {
    command = "tfpvn fluxinit ${var.nodemap[keys(var.nodemap)[0]].kctl}"
  }
  lifecycle {
    replace_triggered_by = [terraform_data.master]
    enabled              = local.is_slave ? true: false
  }
}
