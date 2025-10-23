#

locals {
  kubemasters = { for k, v in local.plexhocmap : k => v if v.num == 1 }
  kubeplay    = pathexpand("~/kubestrap.yml")
}
