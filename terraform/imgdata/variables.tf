#

variable "remote" {
  description = "imgdata-host-plex-name"
  type        = string
}

variable "allfimgs" {
  description = "full-type-image-names"
  type        = set(string)
}
