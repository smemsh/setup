#

variable "remote" {
  description = "os-image-host-plex-name"
  type        = string
}

variable "osimgs" {
  description = "os-image-type-name-objects"
  type = map(object({
    virtype = string
    imgname = string
  }))
}
