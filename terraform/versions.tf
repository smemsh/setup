#

terraform {
  required_version = "1.11.2"
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.0.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.5"
    }
  }
}
