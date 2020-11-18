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

variable "aws_metadata" {
  type    = map(string)
  default = {
    "profile" = "default"
    "region" = "us-east-1"
  }
}

variable "instance_metadata" {
  type    = map(string)
  default = {
    # For AWS Free-Tier, make sure you leave instance_type set to t2.micro
    "instance_type" = "t2.micro"
    "ami" = "ami-089e6b3b328e5a2c1"
    "key_name" = "kubernetes-deployer"
    "ami_os_user" = "ubuntu"
    "ami_os_private_key" = "~/.ssh/kubernetes-deployer.pem"
  }
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
    "protocol" = "HTTP"
  }
}

