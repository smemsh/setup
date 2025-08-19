#

resource "incus_image" "typeimgs" {
  for_each = var.allfimgs
  remote   = var.remote
  aliases  = [each.value]

  source_instance = {
    name = var.bakename
  }

  lifecycle {
    # image should remain until manually deleted or refreshed
    ignore_changes = all
  }
}
