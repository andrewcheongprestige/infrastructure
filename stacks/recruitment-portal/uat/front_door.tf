# The traffic path of the Recruitment Portal UAT site, imported as it is. A visitor to
# https://uat.recruitment.prestigeinhomecare.com.au goes:
#
#   DNS (outside AWS) -> the certificate below -> the Hub 1.0 UAT load balancer's HTTPS listener
#   -> the host rule (priority 10) -> the target group Recruitment-UAT -> the environment's instance.
#
# The load balancer and its listener belong to the Hub 1.0 UAT Elastic Beanstalk environment (paf-thehub-app-uat).
# They are looked up here, never owned: if that environment is rebuilt, the load balancer and this rule go with it.
# Everything below carries live traffic, so Terraform is told never to destroy it.

data "aws_lb" "shared" {
  name = "awseb--AWSEB-pJ8SZGoYPqFo"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

# Issued by ACM in March 2026 and validated by a DNS record in the external DNS, which must stay in place or
# automatic renewal fails.
resource "aws_acm_certificate" "uat" {
  domain_name               = "uat.recruitment.prestigeinhomecare.com.au"
  subject_alternative_names = ["uat.recruitment.prestigeinhomecare.com.au"]
  key_algorithm             = "RSA_2048"
  validation_method         = "DNS"

  options {
    certificate_transparency_logging_preference = "ENABLED"
    export                                      = "DISABLED"
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Adds the certificate to the shared HTTPS listener. The listener chooses the right certificate by hostname (SNI).
resource "aws_lb_listener_certificate" "uat" {
  listener_arn    = data.aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate.uat.arn

  lifecycle {
    prevent_destroy = true
  }
}

# The group of servers behind the rule. The environment's Auto Scaling group is registered with it by hand (that
# registration comes with the environment import).
resource "aws_lb_target_group" "uat" {
  name        = "Recruitment-UAT"
  vpc_id      = "vpc-0fb4846013ab42265"
  port        = 80
  protocol    = "HTTP"
  target_type = "instance"

  deregistration_delay = "300"

  health_check {
    enabled             = true
    path                = "/"
    port                = "traffic-port"
    protocol            = "HTTP"
    matcher             = "200"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  stickiness {
    type            = "lb_cookie"
    enabled         = false
    cookie_duration = 86400
  }

  lifecycle {
    prevent_destroy = true
  }
}

# Requests for the portal's hostname go to the target group above.
resource "aws_lb_listener_rule" "uat" {
  listener_arn = data.aws_lb_listener.https.arn
  priority     = 10

  action {
    order = 1
    type  = "forward"

    forward {
      stickiness {
        enabled  = false
        duration = 3600
      }

      target_group {
        arn    = aws_lb_target_group.uat.arn
        weight = 10
      }
    }
  }

  condition {
    host_header {
      values = ["uat.recruitment.prestigeinhomecare.com.au"]
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
