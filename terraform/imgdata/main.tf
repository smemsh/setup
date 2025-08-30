#

data "incus_image" "imgdata" {
  for_each = local.allfimgs
  remote   = var.remote
  name     = each.value
}
