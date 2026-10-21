# The parts of the Admin Hub React UAT traffic path that were added by hand to the environment's own load balancer. A
# visitor to https://uat.thehub2.prestigeinhomecare.com.au goes:
#
#   DNS (outside AWS) -> the certificate below -> the HTTPS listener below -> its default action: the environment's
#   default target group (created by Elastic Beanstalk) -> the environment's instance.
#
# The load balancer, its port 80 listener and its default target group belong to this environment's Elastic Beanstalk
# stack. They are looked up here, never owned: if the environment is rebuilt, the load balancer goes with it, and this
# listener (and the Partner Portal and Variphy rules on it) must be recreated. Other applications' rules and
# certificates on this listener (Partner Portal in stacks/partner-portal/uat, Variphy not managed yet) are not
# managed here.
# Everything below carries live traffic, so Terraform is told never to destroy it.

data "aws_lb" "environment" {
  name = "awseb--AWSEB-gTxOTz5Amz1n"
}

data "aws_lb_target_group" "default" {
  name = "awseb-AWSEB-HTIOVP8LZFAH"
}

# Issued by ACM and validated by a DNS record in the external DNS, which must stay in place or automatic renewal
# fails.
resource "aws_acm_certificate" "uat" {
  domain_name               = "uat.thehub2.prestigeinhomecare.com.au"
  subject_alternative_names = ["uat.thehub2.prestigeinhomecare.com.au"]
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

# The HTTPS listener, with this certificate as its default. The other certificates on it (Partner Portal's and
# Variphy's) are added to it separately and are not managed here.
resource "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.environment.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-TLS13-1-2-Res-2021-06"
  certificate_arn   = aws_acm_certificate.uat.arn

  default_action {
    order = 1
    type  = "forward"

    forward {
      stickiness {
        enabled  = false
        duration = 3600
      }

      target_group {
        arn    = data.aws_lb_target_group.default.arn
        weight = 1
      }
    }
  }

  lifecycle {
    prevent_destroy = true

    # The default action sends traffic to the environment's own target group, which Elastic Beanstalk owns. Terraform
    # does not manage that action, so the first writes to this shared listener are limited to its tags and can never
    # change routing for Admin Hub, Partner Portal or Variphy.
    ignore_changes = [default_action]
  }
}
