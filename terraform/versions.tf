#

terraform {
  required_version = "1.12.2"
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "1.1.1"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.4.0"
    }
  }
}
