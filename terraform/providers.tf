#

provider "incus" {
  default_remote = "local"
  #accept_remote_certificate = true

  remote {
    name    = "local"
    address = "unix://"
  }

  remote {
    name    = "omnius"
    address = "https://omnius.smemsh.net:8443"
  }
  remote {
    name    = "vernius"
    address = "https://vernius.terra:8443"
  }

  remote {
    name     = "ghcr"
    address  = "https://ghcr.io"
    protocol = "oci"
    public   = true
  }
}
