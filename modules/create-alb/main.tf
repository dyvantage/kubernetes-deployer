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

# import certificate
resource "aws_acm_certificate" "k8s_master_cert" {
  private_key      = file(lookup(var.alb_metadata,"cert_private_key"))
  certificate_body = file(lookup(var.alb_metadata,"cert_body"))
}

# add TLS cert (for Kubernete master nodes)
resource "aws_alb_listener_certificate" "k8s_master_api" {
  listener_arn    = aws_alb_listener.alb_front_http.arn
  certificate_arn = aws_acm_certificate.k8s_master_cert.arn
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
