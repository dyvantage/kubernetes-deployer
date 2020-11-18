# create alb (application load-balancer: layer-7, request-based)
resource "aws_alb" "alb_front" {
  name                       = "front-alb"
  internal                   = false
  enable_deletion_protection = false
  security_groups            = var.alb_security_groups
  subnets                    = var.alb_subnets
}

# add listener to alb
resource "aws_alb_listener" "alb_front_http" {
  load_balancer_arn = aws_alb.alb_front.arn
  port              = lookup(var.alb_metadata,"port")
  protocol          = lookup(var.alb_metadata,"protocol")
  default_action {
    target_group_arn = aws_alb_target_group.alb_front_http.arn
    type             = "forward"
  }
}

# create target group
resource "aws_alb_target_group" "alb_front_http" {
  name     = "alb-front-http"
  vpc_id   = var.target_vpc_id
  port     = lookup(var.alb_metadata,"port")
  protocol = lookup(var.alb_metadata,"protocol")
  health_check {
    path                = "/healthcheck"
    port                = lookup(var.alb_metadata,"port")
    protocol            = lookup(var.alb_metadata,"protocol")
    healthy_threshold   = 2
    unhealthy_threshold = 2
    interval            = 5
    timeout             = 4
    matcher             = "200-308"
  }
}
