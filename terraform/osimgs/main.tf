#

resource "incus_image" "osimgs" {
  for_each = local.osimgs
  remote   = var.remote
  aliases  = [each.key]
  source_image = {
    name         = each.value.imgname
    type         = each.value.virtype
    remote       = "images"
    architecture = "x86_64"
  }
}
