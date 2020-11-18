output "master_private_ips" {
  value = module.create_masters.master_private_ips
}

output "master_public_ips" {
  value = module.create_masters.master_public_ips
}

output "worker_private_ips" {
  value = module.create_workers.worker_private_ips
}

output "worker_public_ips" {
  value = module.create_workers.worker_public_ips
}

output "master_load_balancer_dns_name" {
  value = module.create_alb.master_load_balancer_dns_name
}

output "worker_pod_cidrs" {
  value = module.create_workers.worker_pod_cidrs
}

output "designated_master_public_dns" {
  value = module.create_masters.designated_master_public_dns
}

output "master_private_dns" {
  value = module.create_masters.master_private_dns
}

output "master_public_dns" {
  value = module.create_masters.master_public_dns
}

output "worker_private_dns" {
  value = module.create_workers.worker_private_dns
}

output "worker_public_dns" {
  value = module.create_workers.worker_public_dns
}

