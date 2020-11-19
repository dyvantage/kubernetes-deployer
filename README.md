# Kubernetes Cluster Deployer (Bootstrapper)
This process that is codified in this repo (Terraform & Bash) is based on processes, content, and configurations detailed in Kelsey Hightower's [Kubernetes The Hard Way](https://github.com/kelseyhightower/kubernetes-the-hard-way/).

Kelsey's tutorial uses the Google Cloud SDK to operate against Google Cloud Platform, and he provides a detailed process for bootstrapping a Kubernetes cluster -- from generation of TLS certificates and kubeconfigs for the controller and worker nodes, all the way to bringing up the control plane (including clustered etcd), configuring CNI, attaching the worker nodes, configuring DNS, and configuring the HTTPS load-balancer for accessing the Kubernetes API.

The code in this repo implements Kelsey's process -- on AWS instead of GCP -- and automates the entire process using Terraform and Bash.

# Getting Started
To get started, you'll need an AWS account.  Free Tier is fine, although you might incur a few dollars worth of charges.

# Setting Up The Control Node (to run Terraform & operating against AWS)
The control node should run Ubuntu 18.04 or 20.04.  Once this repo is cloned into ~/kubernetes-deployer, install the following prerequisites:
* AWS Client
```
bash scripts/install-awscli.sh
aws configure
```
* Cloud Flare's PKI toolkit (cfssl and cfssljson)
```
bash scripts/install-cfssl.sh
```
* kubectl
```
bash scripts/install-kubectl.sh
```
* jq
```
bash scripts/install-jq.sh
```

# AWS Prerequisites
Using the AWS Console, create an SSH key-pair named 'kubernetes-deployer' in pem format.  Save the private key in `~/.ssh/kubernetes-deployer.pem`

# Building a Kubernetes Cluster
Terraform will create a new VPC and limit all operation to that VPC.

When Terraform is invoked, it will provision all the infrastructure necessary to support a Kubernetes cluster: subnets, security groups, instances, network routes (for Pod networks), load-balancer.It will also invoke a script located in `bootstrap-cluster/INSTALL_CONTROL_PLANE.sh` to bootstrap the Kubernetes control plane and attach the worker nodes.

To invoke Terraform, run:
```
terraform init
terraform apply -auto-approve -var 'num_masters=1' -var 'num_workers=1'
```

You can change `num_masters` to 1, 3, or 5 - due to etcd requirements. Each Kubernetes controller node runs an instance of etcd.

# Cleaning Up
To delete the VPC and everything in it, run:
```
terraform destroy -auto-approve
```
