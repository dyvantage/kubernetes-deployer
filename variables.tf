################################################################################
# define providers
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 2.70"
    }
  }
}

provider "aws" {
  profile = lookup(var.aws_metadata,"profile")
  region  = lookup(var.aws_metadata,"region")
}

variable "num_masters" {
  default = 1
  description = "Number of kubernetes masters to launch"
}

variable "num_workers" {
  default = 1
  description = "Number of kubernetes workers to launch"
}

variable "alb_metadata" {
  type    = map(string)
  default = {
    "port" = "6443"
    "protocol" = "HTTPS"
    "cert_private_key" = "bootstrap-cluster/certs/kubernetes-key.pem"
    "cert_body" = "bootstrap-cluster/certs/kubernetes.pem"
  }
}
