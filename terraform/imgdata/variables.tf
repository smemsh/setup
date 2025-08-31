#

variable "remote" {
  type        = string
  description = "imgdata-host-plex-name"
}

variable "allfimgs" {
  type        = set(string)
  description = "full-type-image-names"
}
