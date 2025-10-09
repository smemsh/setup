#

provider "incus" {
  remote {
    name    = "local"
    scheme  = "unix"
    default = true
  }

  # :8443
  remote {
    name    = "omnius"
    scheme  = "https"
    address = "omnius.smemsh.net"
  }
  remote {
    name    = "vernius"
    scheme  = "https"
    address = "vernius.proxima"
  }
}
