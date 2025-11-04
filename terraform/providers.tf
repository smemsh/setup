#

provider "incus" {

  default_remote = "local"

  remote {
    name    = "local"
    address = "unix://"
  }

  # :8443
  remote {
    name    = "omnius"
    address = "https://omnius.smemsh.net:8443"
  }
  remote {
    name    = "vernius"
    address = "https://vernius.terra:8443"
  }
}
