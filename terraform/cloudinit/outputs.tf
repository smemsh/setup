#

output "netconfig" {
  value = {
    for name, attrs in var.nodemap : name => templatefile(
      "${path.module}/netconfig.tftpl", {
        tmpl_hostcidr = "${var.hostdb[name]}/${var.masklen}"
        tmpl_gateway  = "${var.hostdb[var.gatemap[attrs.plex]]}"
        tmpl_nslist   = var.nslist
      }
    )
  }
}

output "userdata" {
  value = {
    for name, attrs in var.nodemap : name => templatefile(
      "${path.module}/userdata.tftpl", {
        tmpl_node      = name
        tmpl_domain    = var.domain
        tmpl_hostdata  = var.hostdb
        tmpl_plexname  = var.gatemap[attrs.plex]
        tmpl_is_knode  = var.is_knode[name]
        tmpl_is_kctl   = var.is_kctl[name]
        tmpl_kubeattrs = local.kubeattrs
        tmpl_kubeadm   = local.kubeadms[name]
        tmpl_rsakey    = ansible_vault.sshprivkey[name].yaml
      }
    )
  }
}
