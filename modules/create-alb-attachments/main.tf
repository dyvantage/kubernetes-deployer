resource "aws_alb_target_group_attachment" "alb_backend_http" {
  count = length(var.nodeapp_instance_ids)
  target_group_arn = var.nodeapp_target_group_arn
  target_id        = var.nodeapp_instance_ids[count.index]
  port             = lookup(var.alb_metadata,"port")
}
