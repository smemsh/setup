#

locals {
  kubevers = {
    api = "v1beta4",
  }
  kubeattrs = {
    token  = "${file(pathexpand("~/crypt/kube/bootstrap.key"))}"
    apiver = "apiVersion: kubeadm.k8s.io/${local.kubevers.api}"
    admrc  = "/etc/kubernetes/kubeadm-config.yml"
    mask   = 16  # pod and service net overlays
  }
  kubeadms = {
    for node in var.nodemap : node.name =>
      var.is_knode[node.name] ? join(" ", [
          "kubeadm --config ${local.kubeattrs.admrc}",
          var.is_kctl[node.name]
            ? "init --ignore-preflight-errors=Port-2379,ExternalEtcdVersion"
            : "join",
      ]) : null
  }
}
