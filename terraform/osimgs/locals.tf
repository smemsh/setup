#

locals {
  osvers    = toset([["ubuntu", 22]]) # img[0]
  virtypes  = toset(["virtual-machine", "container"]) # img[1]
  allimgs   = setproduct(local.osvers, local.virtypes)

  osimgstrs = {
    ubuntu = { prefix = "ubuntu/", suffix = ".04/cloud" }
  }

  osimgs = {
    for img in local.allimgs : format("%s%d%s",
      substr(img[0][0], 0, 1), img[0][1], substr(img[1], 0, 1)
    ) => {
      "virtype" = img[1]
      "imgname" = format("%s%d%s",
        local.osimgstrs[img[0][0]].prefix,
        img[0][1],
        local.osimgstrs[img[0][0]].suffix
      )
    }
  }
}
