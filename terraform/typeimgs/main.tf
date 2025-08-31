#

resource "incus_image" "typeimgs" {
  for_each = var.allfimgs
  remote   = var.remote

  alias {
    name = each.value
  }

  source_instance = {
    name = var.bakename
  }

  lifecycle {
    # image should remain until manually deleted or rebaked in ansible
    ignore_changes = all

    # we might consider this because a failed rebake leaves us unable to do
    # new provisions.  it needs to be tested with our bake pipeline TODO
    #
    #create_before_destroy = true
  }
}
