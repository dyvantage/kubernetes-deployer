output "master_target_group_arn" {
  value = aws_alb_target_group.alb_front_http.arn
}

output "master_load_balancer_dns_name" {
  value = aws_alb.alb_front.dns_name
}
