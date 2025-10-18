#

locals {
  kubevers = {
    api = "v1beta4",
  }
  kubeattrs = {
    token  = "${file("${local.home}/crypt/kube/bootstrap.key")}"
    admrc  = "/etc/kubernetes/kubeadm-config.yml"
    apiver = "apiVersion: kubeadm.k8s.io/${local.kubevers.api}"
    mask   = 16  # pod and service net overlays
  }
  kubemasters = { for k, v in local.plexhocmap : k => v if v.num == 1 }
  kubeplay = "${local.home}/kubestrap.yml"
}
