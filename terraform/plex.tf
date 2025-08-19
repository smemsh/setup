#
# if only we could use a function in a terraform.tfvars
# TODO maybe put this in a module and have it as an output
#

locals {
  plexhocnodes = toset(flatten([
    for host, osimgs in var.plexhocs : [
      for base, types in osimgs : [
        for type, nodes in types : [
          for nodenum in nodes : {
            plex = host
            base = base # modules.osimgs key
            type = type
            fimg = "${base}_${type}" # modules.typeimgs key
            virt = (substr(base, -1, -1) == "v"
              ? "virtual-machine"
              : "container"
            )
            name = format("%s%d",
              replace(host, "/us$/", "plex"),
              nodenum
            )
          }
        ]
      ]
    ]
  ]))

  plexhocmap = tomap({for node in local.plexhocnodes : node.name => node})
  imgtypes = toset(distinct([for node in local.plexhocnodes : node.type]))
  allfimgs = toset(distinct([for node in local.plexhocnodes : node.fimg]))
}
