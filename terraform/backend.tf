#

terraform {
  backend "local" {
    # path = ".terraform/terraform.tfstate"
    # todo: gcs, but must also setup encryption, and what about when lan
    #  but no internet? and what if gcs bucket became inaccessible?
    #  possibly, periodic statefile copies from gcs to local might
    #  accomplish this, backend could be switched to local then, as long
    #  as statefile is same format/information.  obviously if using gce
    #  nodes, if gcs is gone gce will probably be gone also so it would
    #  only matter for non-gce nodes
  }
}
