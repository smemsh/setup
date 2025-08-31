#

data "incus_image" "imgdata" {
  for_each = var.allfimgs
  remote   = var.remote
  name     = each.value
}
