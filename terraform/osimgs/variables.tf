#

variable "remote" {
  type        = string
  description = "os-image-host-plex-name"
}

variable "osimgs" {
  type = map(object({
    virtype = string
    imgname = string
  }))
  description = "os-image-type-name-objects"
}
