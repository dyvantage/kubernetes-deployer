# AWS Account Settings

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

