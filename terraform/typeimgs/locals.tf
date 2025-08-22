#

locals {

  # hardcode rather than derive from plex inventory so the images stay
  # around even if no currently instantiated node exists
  #
  allfimgs = toset([for v in ["v", "c"] : "u22${v}_adm"])
}
