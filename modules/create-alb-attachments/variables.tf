variable "alb_metadata" {
  type = map(string)
  description = ""
}

variable "nodeapp_instance_ids" {
  type = list(string)
}

variable "nodeapp_target_group_arn" {
  type = string
}
