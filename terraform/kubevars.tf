#

locals {
  kuberc = "/etc/kubernetes/admin.conf"
  kubevers = {
    api = "v1beta4",
    cni = "v0.27.3",  # flannel
  }
  kubeattrs = {
    token  = "${file("${local.home}/crypt/kube/bootstrap.key")}"
    admrc  = "/etc/kubernetes/kubeadm-config.yml"
    apiver = "apiVersion: kubeadm.k8s.io/${local.kubevers.api}"
    cnicmd = format(
      "kubectl --kubeconfig %s apply -f %s/%s",
        local.kuberc,
        "https://github.com/flannel-io/flannel",
          "releases/download/${local.kubevers.cni}/kube-flannel.yml",
    )
    init_join_timeout = 120
  }
  kubemasters = { for k, v in local.plexhocmap : k => v if v.num == 1 }
}
