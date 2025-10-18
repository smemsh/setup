
locals {
  kuberc = "/etc/kubernetes/admin.conf"
  kubevers = {
    cni = "v0.27.3",  # flannel
  }
  kubeattrs = {
    init_join_timeout = 120
    cnicmd = format(
      "kubectl --kubeconfig %s apply -f %s/%s",
        local.kuberc,
        "https://github.com/flannel-io/flannel",
          "releases/download/${local.kubevers.cni}/kube-flannel.yml",
    )
  }
}
