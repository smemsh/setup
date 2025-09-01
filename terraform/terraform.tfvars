#

# main
plexhosts = ["omnius", "vernius"]
domain    = "smemsh.net"
project   = "plex"
masklen   = 22 # 2^(32-n) hosts
volsz     = 32 # n * 2^30 bytes

# module.osimgs
osvers = [
  ["ubuntu", 22],
  ["ubuntu", 24],
]

# module.typeimgs
imgtypes = ["adm"]
