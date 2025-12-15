#

# if this instance is for kubemasters, we will have a null 'master' arg,
# meaning we are to provide the master as an output, so slaves can be dependent
#
output "master" {

  # this voodoo took some time to come up with... should document it more TODO
  # works with one() because of behavior of splat operator on an object:
  # https://developer.hashicorp.com/terraform/language/expressions/splat#single-values-as-lists
  #
  value = var.master == null ? one(values(one(incus_instance.knode[*]))) : null
}
