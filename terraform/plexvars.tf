#

locals {

  plexgates  = [for h in var.plexhosts : replace(h, "/us$/", "plex")]
  gatebyplex = zipmap(var.plexhosts, local.plexgates)

  # master list of provisioned plexhocs, 3 dimensions: plexhost, base, type.
  # at each leaf is a list of hocnodes.  on each plexhost, plexnodes
  # numbering <plexgate>N are provisioned using typeimage <osimg>_<type>
  #
  plexhocnodes = toset(flatten([
    for host, osimgs in var.plexhocs : [
      for base, types in osimgs : [
        for type, nodespec in types : [
          for rangestr in try(
            #
            # the node lists can be given in any of four formats:
            #
            #    [1, 2]     list of numbers  (join yes)
            #    "1, 3-14"  ranges string    (join no, split yes)
            #    "1"        string number    (join no, split no, tostring yes)
            #    1          single number    (join no, split no, tostring yes)
            #
            # other syntaxes will cause error.  spaces are ok in a ranges
            # string.  we do the try() tests, first one succeeds, result will
            # be in a format able to parse in RHS of the for-expression which
            # follows.  this is not robust against malformed inputs. the user
            # is expected to know the syntax.
            #
            # unfortunately, all of the leaves have to be in the same format.
            # this is not true if it's a local, but if defined in tfvars, the
            # user has to choose because we have to specify the type of the
            # values and 'any' value in a map still needs to all be the same
            # type.  we cannot use an object since we don't know all the keys.
            #
            #
            split(",", join(",", nodespec)),
            split(",", nodespec),
            [tostring(nodespec)],
          ) : [
            #
            # in any of the three cases that took, result will be a string we
            # can parse which looks like one of these variants:
            #
            #    "1, 3-14, 21"
            #    "1, 2, 3"
            #    "1"
            #
            # for each commasep substring, we decompose into a node range():
            #
            #   - start is always the initial number
            #   - if string contains "-" then range is N-M, ie range(N, M+1)
            #   - without a "-" it's a single number, which is range(N, N+1)
            #
            # all the result lists are flattened to one list of unique values
            # for 'nodenum' for filling instances of the map expression.
            #
            # the duplicated subexpressions are an unfortunate necessity of
            # declarative syntax without assignment registers available to
            # store intermediate test outcomes.  we have to use branching and
            # some duplicate tests, but wasn't that bad.
            #
            for nodenum in range(
              strcontains(rangestr, "-")
                ? tonumber(split("-", trimspace(rangestr))[0])
                : tonumber(trimspace(rangestr))
              ,
              strcontains(rangestr, "-")
                ? tonumber(split("-", trimspace(rangestr))[1]) + 1
                : tonumber(trimspace(rangestr)) + 1
            ) :
            {
              plex = host
              base = base # modules.osimgs key
              type = type
              fimg = "${base}_${type}" # modules.typeimgs key
              virt = endswith(base, "v") ? "virtual-machine" : "container"
              name = format("%s%d", replace(host, "/us$/", "plex"), nodenum)
              num  = nodenum
            }
          ]
        ]
      ]
    ]
  ]))

  # all plexhoc nodes
  plexhocmap = {
    for node in local.plexhocnodes : node.name => node
  }

  # kube masters
  plexctlmap = {
    for node in local.plexhocnodes : node.name => node
      if local.plexhocmaps_is_kctl[node.name]
  }

  # kube slaves
  plexwrkmap = {
    for node in local.plexhocnodes : node.name => node
      if local.plexhocmaps_is_kwrk[node.name]
  }

  # global non-kube nodes
  plexnonmap = {
    for node in local.plexhocnodes : node.name => node
      if ! local.plexhocmaps_is_knode[node.name]
  }

  # node attr bools indexed by nodename
  #
  plexhocmaps_is_vos = {
    for node in local.plexhocnodes : node.name => node.virt == "container"
  }
  plexhocmaps_is_knode = {
    for node in local.plexhocnodes : node.name => node.type == "kube"
  }
  plexhocmaps_is_kctl = {
    for node in local.plexhocnodes : node.name =>
      local.plexhocmaps_is_knode[node.name] && node.num == 1
  }
  plexhocmaps_is_kwrk = {
    for node in local.plexhocnodes : node.name =>
      local.plexhocmaps_is_knode[node.name] && node.num != 1
  }

  #
  plexhocmaps_kubemasters = {
    for node in local.plexhocnodes : node.name =>
      "${local.gatebyplex[node.plex]}1"
  }

  #
  plexhocmaps_profiles = {
    for node in local.plexhocnodes : node.name => concat(
      ["default"],
      local.plexhocmaps_is_knode[node.name] ? ["knode"] : [],
      (local.plexhocmaps_is_knode[node.name]
       && local.plexhocmaps_is_vos[node.name]) ? ["nestpriv"] : []
    )
  }
}
