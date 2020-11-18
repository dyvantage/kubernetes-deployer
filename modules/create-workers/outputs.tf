output "worker_instance_ids" {
  value       = aws_instance.k8worker[*].id
}

output "worker_private_ips" {
  value = {
    for instance in aws_instance.k8worker:
    lookup(instance.tags,"Name") => instance.private_ip
  }
}

output "worker_public_ips" {
  value = {
    for instance in aws_instance.k8worker:
    lookup(instance.tags,"Name") => instance.public_ip
  }
}

output "worker_pod_cidrs" {
  value = {
    for instance in aws_instance.k8worker:
    lookup(instance.tags,"Name") => lookup(instance.tags,"Pod_CIDR")
  }
}

output "worker_private_dns" {
  value = {
    for instance in aws_instance.k8worker:
    lookup(instance.tags,"Name") => instance.private_dns
  }
}

output "worker_public_dns" {
  value = {
    for instance in aws_instance.k8worker:
    lookup(instance.tags,"Name") => instance.public_dns
  }
}

