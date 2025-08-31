#

resource "incus_image" "osimgs" {
  for_each = var.osimgs
  remote   = var.remote

  alias {
    name = each.key
  }

  source_image = {
    name         = each.value.imgname
    type         = each.value.virtype
    remote       = "images"
    architecture = "x86_64"
  }
}
