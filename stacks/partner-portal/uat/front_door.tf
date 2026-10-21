# The traffic path of the Partner Portal UAT site, imported as it is. A visitor to
# https://uat.partnerportal.prestigeinhomecare.com.au goes:
#
#   DNS (outside AWS) -> the certificate below -> the Admin Hub UAT load balancer's HTTPS listener
#   -> the host rule (priority 10) -> the target group PartnerPortal-UAT -> the environment's instance.
#
# The load balancer and its listener belong to the Admin Hub UAT Elastic Beanstalk environment
# (paf-adminhub-reactapp-uat). They are looked up here, never owned: if that environment is rebuilt, the load
# balancer and this rule go with it. Other applications share the same listener (for example the Variphy rule at
# priority 20 and its certificate); they are not managed here.
# Everything below carries live traffic, so Terraform is told never to destroy it.

data "aws_lb" "shared" {
  name = "awseb--AWSEB-gTxOTz5Amz1n"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.shared.arn
  port              = 443
}

# Issued by ACM and validated by a DNS record in the external DNS, which must stay in place or automatic renewal
# fails.
resource "aws_acm_certificate" "uat" {
  domain_name               = "uat.partnerportal.prestigeinhomecare.com.au"
  subject_alternative_names = ["uat.partnerportal.prestigeinhomecare.com.au"]
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

# The group of servers behind the rule. The environment's Auto Scaling group is registered with it (see
# target_group_attachment.tf, added with the environment). The VPC is the account's default VPC, not the private
# one the recruitment and client portals use.
resource "aws_lb_target_group" "uat" {
  name        = "PartnerPortal-UAT"
  vpc_id      = "vpc-0448b7de87ba5442d"
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
        weight = 1
      }
    }
  }

  condition {
    host_header {
      values = ["uat.partnerportal.prestigeinhomecare.com.au"]
    }
  }

  lifecycle {
    prevent_destroy = true
  }
}
