# The portal shares an existing load balancer (owned by an Elastic Beanstalk environment).
# We add only a certificate, a target group and a hostname rule. We never modify the load
# balancer or its listener themselves.
data "aws_lb" "shared" {
  name = var.shared_alb_name
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

# The DNS for prestigeinhomecare.com.au is not in this account's Route 53, so the validation
# record is added by hand. This resource just waits until ACM reports the certificate as issued.
resource "aws_acm_certificate" "this" {
  domain_name       = var.hostname
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_acm_certificate_validation" "this" {
  certificate_arn = aws_acm_certificate.this.arn

  timeouts {
    create = "60m"
  }
}

# Adds the certificate to the shared listener. The listener picks the right one by hostname (SNI).
resource "aws_lb_listener_certificate" "this" {
  listener_arn    = data.aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate_validation.this.certificate_arn
}

# The group of instances that receive the portal's traffic.
# The Elastic Beanstalk environment's Auto Scaling group is attached to it in the next step.
resource "aws_lb_target_group" "this" {
  name                 = local.name_prefix
  port                 = 80
  protocol             = "HTTP"
  vpc_id               = var.vpc_id
  target_type          = "instance"
  deregistration_delay = 30

  health_check {
    path    = var.health_check_path
    matcher = "200"
  }
}

# Requests for the portal's hostname go to the portal's target group.
resource "aws_lb_listener_rule" "this" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = var.listener_rule_priority

  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.this.arn
  }

  condition {
    host_header {
      values = [var.hostname]
    }
  }
}
