# discover existing availability zones
data "aws_availability_zones" "available" {}

# create a new VPC
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "2.6.0"

  name                 = "kubernetes-vpc"
  cidr                 = "10.240.0.0/16"
  azs                  = data.aws_availability_zones.available.names
  public_subnets       = ["10.240.0.0/24","10.240.1.0/24","10.240.2.0/24"]
  private_subnets      = ["10.240.100.0/24","10.240.101.0/24","10.240.102.0/24"]
  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
}

# create security groups and rules
module "create_sgs" {
  source = "./modules/create-sgs"

  target_vpc_id = module.vpc.vpc_id
  target_vpc_cidr = module.vpc.vpc_cidr_block
}

# create instances (master nodes)
module "create_masters" {
  source = "./modules/create-masters"

  target_subnet_id = module.vpc.public_subnets[0]
  num_instances = var.num_masters
  instance_metadata = var.instance_metadata
  instance_security_groups = module.create_sgs.sg_ids
}

# create instances (worker nodes)
module "create_workers" {
  source = "./modules/create-workers"

  target_subnet_id = module.vpc.public_subnets[0]
  num_instances = var.num_workers
  instance_metadata = var.instance_metadata
  instance_security_groups = module.create_sgs.sg_ids
}

locals {
  bootstrap_args = module.create_masters.designated_master_public_dns
}

# run script on localhost (via ssh)
resource "null_resource" "bootstrap_controlplane" {
  provisioner "local-exec" {
    working_dir = "bootstrap-cluster/"
    command = "./INSTALL_CONTROL_PLANE.sh --lb-ip ${local.bootstrap_args}"
    interpreter = ["/bin/bash", "-c"]
  }

  # before running script to bootstrap the control plane, wait for the master/worker instances
  depends_on = [module.create_masters, module.create_workers]
}

# create load-balancer to front-end all master nodes
module "create_alb" {
  source = "./modules/create-alb"

  # initialize input variables
  target_vpc_id = module.vpc.vpc_id
  alb_subnets = module.vpc.public_subnets[*]
  alb_security_groups = module.create_sgs.sg_ids
  alb_metadata = var.alb_metadata
  aws_metadata = var.aws_metadata

  depends_on = [module.create_masters, module.create_workers]
}

module "create_alb_attachments" {
  source = "./modules/create-alb-attachments"

  # initialize input variables
  alb_metadata = var.alb_metadata
  nodeapp_instance_ids = module.create_masters.master_instance_ids
  nodeapp_target_group_arn = module.create_alb.master_target_group_arn

  # before creating the load-balancer, wait for control plane -- an artificact of which is the TLS nert needed for the HTTPS load-balancer
  #depends_on = [null_resource.bootstrap_controlplane]
}
