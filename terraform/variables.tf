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
  type        = list(string)
  description = "host-type-variants"
}

variable "osvers" {
  type        = list(tuple([string, number]))
  description = "os-base-versions"
}
