#

locals {

  # hardcode rather than derive from plex inventory so the images stay
  # around even if no currently instantiated node exists
  #
  allfimgs = toset(flatten([
    for vtype in ["v", "c"] : [
      for ubuver in [22, 24] :
        format("u%d%s_adm", ubuver, vtype)
    ]
  ]))
}
