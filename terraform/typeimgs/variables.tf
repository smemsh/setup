#

variable "remote" {
  type        = string
  description = "type-image-host-plex-name"
}

variable "bakename" {
  type        = string
  description = "bake-source-instance-name"
}

variable "allfimgs" {
  type        = set(string)
  description = "full-image-names"
}
