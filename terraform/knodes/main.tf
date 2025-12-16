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
    replace_triggered_by = [terraform_data.kubedata]
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
  is_slave  = var.master != null
  is_master = !local.is_slave
}

# for slaves, the indirect dependency on master node allows an evaluative
# expression to work in replace_triggered_by context.  coupled with depends_on
# in the module for ordering dependency.  todo: this means we have a useless
# terraform_data for the kubemasters module instance, which will just have a
# null output (see note about attempts to use count), but potentially this
# resource could be used to hold other state for some later purpose
#
resource "terraform_data" "kubedata" {

  # todo: after deleting one of the slaves, having this count results in:
  # no change found for terraform_data.kubedata in module.kubemasters["omnius"]
  #count = (var.master == null ? 0 : 1)

  # todo: for volatile.id, resubmit issue 326
  input = local.is_slave ? var.master.mac_address : null
}
