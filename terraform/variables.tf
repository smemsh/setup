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

# plexhost -> base -> type -> nodelist
variable "plexhocs" {
  description = "plexhoc-node-tree"
  type        = map(map(map(list(number))))
  default     = {}
}
