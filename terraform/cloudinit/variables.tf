#

variable "nodemap" {
  description = "root-local-plexhocmap"
  type        = map(any)
}

variable "gatemap" {
  description = "root-local-gatebyplex"
  type        = map(string)
}

variable "hostdb"  {
  description = "root-local-hostdb"
  type        = map(string)
}

variable "domain"  {
  description = "root-var-domain"
  type        = string
}

variable "masklen" {
  description = "root-var-masklen"
  type        = number
}

variable "is_knode" {
  description = "root-local-plexhocmaps_is_knode"
  type        = map(bool)
}

variable "is_kctl" {
  description = "root-local-plexhocmaps_is_kctl"
  type        = map(bool)
}
