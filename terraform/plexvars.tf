#

locals {

  plexgates  = [for h in var.plexhosts : replace(h, "/us$/", "plex")]
  gatebyplex = zipmap(var.plexhosts, local.plexgates)

  # master list of provisioned plexhocs, 3 dimensions: plexhost, base, type
  # if only we could use expressions in terraform.tfvars, even just range()
  #
  plexhocs = {
    "omnius" = {
      "u22v" = {
        "adm" = []
      }
      "u22c" = {
        "adm" = [1]
      }
    }
  }

  plexhocnodes = toset(flatten([
    for host, osimgs in local.plexhocs : [
      for base, types in osimgs : [
        for type, nodes in types : [
          for nodenum in nodes : {
            plex = host
            base = base # modules.osimgs key
            type = type
            fimg = "${base}_${type}" # modules.typeimgs key
            virt = endswith(base, "v") ? "virtual-machine" : "container"
            name = format("%s%d", replace(host, "/us$/", "plex"), nodenum)
          }
        ]
      ]
    ]
  ]))
  plexhocmap = tomap({for node in local.plexhocnodes : node.name => node})
}
