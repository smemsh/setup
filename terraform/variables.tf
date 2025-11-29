#

# set by an ansible play that initiates the bake and makes an image
variable "baketime" {
  description = "build-bakehost-yn"
  type        = bool
  default     = false
}

variable "bakehost" {
  description = "bakehost-remote"
  type        = string
  default     = ""
}

variable "bakenode" {
  description = "bakehost-nodename"
  type        = string
  default     = ""
}

variable "bakebase" {
  description = "osimgs-base"
  type        = string
  default     = ""
}

variable "imgtypes" {
  description = "host-type-variants"
  type        = list(string)
}

variable "osvers" {
  description = "os-base-versions"
  type        = list(tuple([string, number]))
}

variable "plexhosts" {
  description = "incus-plex-host-systems"
  type        = set(string)
}

variable "resolvers" {
  description = "upstream-dns-resolvers"
  type        = list(string)
}

variable "project" {
  description = "plex-base-project"
  type        = string
}

variable "domain" {
  description = "plex-base-internet-domain"
  type        = string
}

variable "masklen" {
  description = "plex-subnet-masklen"
  type        = number
}

variable "volsz" {
  description = "instance-disk-size-gigabytes"
  type        = number
}

variable "sshport" {
  description = "ssh-connect-to-port"
  type        = number
}

# <plexhost> = {<base> = {<type> = ["rangelist" | num | [num, ...], ...}}
# note: all leaves must be same type to pass validation, have to choose.
#
#"vernius" = {
#  "u24c" = { "adm" = 9 }
#  "u24v" = { "adm" = [10, 12, 19] }
#  "u22c" = { "adm" = "21" }
#  "u22v" = { "adm" = "31-34, 37" }
#}
#
variable "plexhocs" {
  description = "plexhocs-definition-plexhost-osimg-type-rangeexpr"
  type        = map(map(map(any)))
}
