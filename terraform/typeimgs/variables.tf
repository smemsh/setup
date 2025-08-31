#

variable "remote" {
  description = "type-image-host-plex-name"
  type        = string
}

variable "bakename" {
  description = "bake-source-instance-name"
  type        = string
}

variable "allfimgs" {
  description = "full-image-names"
  type        = set(string)
}
