#

terraform {
  required_version = "1.9.0"
  required_providers {
    incus = {
      source  = "lxc/incus"
      version = "0.3.1"
    }
    ansible = {
      source  = "ansible/ansible"
      version = "1.3.0"
    }
    external = {
      source  = "hashicorp/external"
      version = "2.3.4"
    }
  }
}
