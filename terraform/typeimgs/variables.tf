#

variable "remote" {
  type        = string
  description = "type-image-host-plex-name"
}

variable "allfimgs" {
  type        = set(string)
  description = "list-of-all-image-type-strings"
}

variable "bakename" {
  type        = string
  description = "bake-source-instance-name"
}
