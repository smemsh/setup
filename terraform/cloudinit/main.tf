#
# returns map of cloudinit user-data and network-config generated via
# templatefile() invocations for each given var.nodemap, indexed by name
# (the actual output calculation is in outputs.tf)
#

resource "ansible_vault" "sshprivkey" {
  for_each   = toset(keys(var.nodemap))
  vault_file = pathexpand("~/keys/host/${each.value}.${var.domain}-id_rsa")

  vault_password_file = pathexpand("~/bin/ansvault")
}
