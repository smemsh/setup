#

# plexhost, baseimg, type, nodelist
# (type == kube) && (plexnum == 1) -> cluster-master
# (type == kube) && (plexnum > 1) -> cluster-slave
#
plexhocs = {
  #"omnius" = {
  #  "u24c" = { "kube" = 1 }
  #  "u24v" = { "adm" = 11 }
  #  "u22c" = { "adm" = 21 }
  #  "u22v" = { "adm" = 31 }
  #}
  #"vernius" = {
  #  "u24c" = { "kube" = 1 }
  #  "u24v" = { "adm" = [10, 12, 19] }
  #  "u22c" = { "adm" = "21" }
  #  "u22v" = { "adm" = "31-34, 37" }
  #}
}

# main
plexhosts = ["omnius", "vernius"]
resolvers = ["8.8.8.8", "8.8.4.4"]
domain    = "smemsh.net"
project   = "plex"
masklen   = 22  # 2^(32-n) hosts
volsz     = 32  # n * 2^30 bytes
sshport   = 22022

# module.osimgs
osvers = [
  ["ubuntu", 22],
  ["ubuntu", 24],
]

# module.typeimgs
imgtypes = ["adm", "kube"]
