output "master_instance_ids" {
  value       = aws_instance.k8master[*].id
}

output "designated_master_public_dns" {
  value       = aws_instance.k8master[0].public_dns
}

output "master_private_ips" {
  value = {
    for instance in aws_instance.k8master:
    lookup(instance.tags,"Name") => instance.private_ip
  }
}

output "master_public_ips" {
  value = {
    for instance in aws_instance.k8master:
    lookup(instance.tags,"Name") => instance.public_ip
  }
}

output "master_private_dns" {
  value = {
    for instance in aws_instance.k8master:
    lookup(instance.tags,"Name") => instance.private_dns
  }
}

output "master_public_dns" {
  value = {
    for instance in aws_instance.k8master:
    lookup(instance.tags,"Name") => instance.public_dns
  }
}
