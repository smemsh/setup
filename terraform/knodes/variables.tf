#

variable "project" {
  description = "project-name"
  type = string
}
variable "imgdata" {
  description = "imgdata-map"
  type = map(any)
}
variable "nodemap" {
  description = "node-map"
  type = map(any)
}
variable "profiles" {
  description = "profile-map"
  type = map(any)
}
variable "master" {
  description = "primary-master-node-object"
  type = any
  default = null
}
variable "userdata" {
  description = "user-data"
  type = map(any)
}
variable "netconfig" {
  description = "net-config"
  type = map(any)
}
