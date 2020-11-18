# define variables
variable "num_instances" {
  description = "Number of instances to launch"
}

variable "target_subnet_id" {
  description = "subnet id to place instance on"
}

variable "instance_metadata" {
  type    = map(string)
  description = "instance metadata"
}

variable "instance_security_groups" {
  description = "security groups to attach to instances"
}

