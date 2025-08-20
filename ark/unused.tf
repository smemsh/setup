#

locals {
  bakerbyhost = zipmap(local.plexhosts, [for p in local.plexgates : "${p}0"])
}

resource "incus_profile" "baker" {
  name        = "baker"
  for_each    = var.baketime ? local.plexhosts : []
  remote      = each.value
  description = "baker-profile-cloudinit"
  config = {
    "cloud-init.network-config" = <<-HERE
      #
      ---
      version: 2
      ethernets:
        eth0:
          # this should get the first ethernet interface, might be named
          # ens2 but then with net.ifnames=1 and biosdevnames=0 kernel
          # args it should be called eth0.  note that the parent's name is
          # irrelevant, only used as a reference, and doesn't really mean
          # eth0; only the 'match' clause matters, if it's supplied
          # (otherwise, it does use its name as the match value)
          match:
            name: e*
          addresses:
            - ${format("%s/%s",
                  local.hostdb[local.bakerbyhost[each.value]],
                  local.masklen
              )}
          gateway4: ${local.hostdb[local.plexbyhost[each.value]]}
          nameservers:
            addresses:
              - 8.8.8.8
              - 8.8.4.4
      HERE

      "cloud-init.user-data" = data.external.cloudinit[0].result.user-data
      # "cloud-init.user-data" = <<-HERE
      #   ...
      # HERE
  }
}

resource "incus_instance" "imgbake" {
  profiles = ["default", "baker"]
}

# has the problem that when used as a replace_triggered_by, the trigger
# will always fire on any change of the value from its previous value,
# which includes giving false after it was last true.  which means there
# would always be an extra, unnecessary build triggered just to reset
# the state.  instead we are preferring to invoke by -destroy and target
# the resource, rather than use a variable indirection.
#
resource "terraform_data" "imgrefresh" {
  for_each = toset(var.imgtypes)
  input    = try(var.reimg[each.value], null)
}

# also tried adding this to the image resources definition, did not work

lifecycle {
  replace_triggered_by = [
    k for k in terraform_data.imgrefresh[var.imgtypes] if k != false
  ]
}

variable "imgtypes" {
  type = list(string)
  default = ["adm"]
}
variable "reimg" {
  type = map(bool)
  default = {
    adm = false
  }
}

# u22v
nodetypes = toset(["adm"])
allimgs   = setproduct(osvers, virtypes, nodetypes, hosts)

dynamic "settings" {
  for_each = local.ubuvers

resource "aws_ssm_patch_group" "environment_patch_group" {
  for_each = {
    for pair in local.os_for_env : "${pair[0]}:${pair[1]}" => {
      env = pair[0]
      os  = pair[1]
    }
  }
  count       = length(local.os_for_env)
  patch_group = "${each.value.env}_patch_group"
  baseline_id = data.aws_ssm_patch_baseline.baselines[each.value.os].id
}

variable "plexobjs" {
  description = "unrolled-plexhoc-node-object-list"
  type = list(
    map(object({
        plex = string
        base = string
        type = string
        nodes = list(number)
    }))
  )
  default = []
}

variable "instance_config" {
  type = map(object({
    instance_name  = string # omniplex1
    instance_image = string # u22v
    instance_type  = string # adm
  }))
  default = {}
}

variable "bakevirtype" {
  description = "instance-type-virt"
  type        = string
  default     = ""
}
