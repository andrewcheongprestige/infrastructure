# The parts of the Hub 1.0 UAT traffic path that were added by hand to the environment's own load balancer. A visitor to
# https://uat.thehub.prestigeinhomecare.com.au goes:
#
#   DNS (outside AWS) -> the certificate below -> the load balancer's HTTPS listener (built by Elastic Beanstalk from
#   the aws:elbv2:listener:443 settings in environment.tf) -> its default action: the environment's default target group
#   -> the environment's instance.
#
# The load balancer and its listener belong to this environment's Elastic Beanstalk stack. They are looked up here,
# never owned. The recruitment and client portals add their own host rules and certificates to the same listener from
# their own stacks, so rebuilding this environment would take their front door with it.
# Everything below carries live traffic, so Terraform is told never to destroy it.

data "aws_lb" "environment" {
  name = "awseb--AWSEB-pJ8SZGoYPqFo"
}

data "aws_lb_listener" "https" {
  load_balancer_arn = data.aws_lb.environment.arn
  port              = 443
}

# Issued by ACM and validated by a DNS record in the external DNS, which must stay in place or automatic renewal
# fails.
resource "aws_acm_certificate" "thehub" {
  domain_name               = "uat.thehub.prestigeinhomecare.com.au"
  subject_alternative_names = ["uat.thehub.prestigeinhomecare.com.au"]
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

# Adds the certificate to the HTTPS listener. The listener chooses the right certificate by hostname (SNI). The
# listener's default certificate (adminhub.platformx-api.com) is part of the environment's settings, not managed here.
resource "aws_lb_listener_certificate" "thehub" {
  listener_arn    = data.aws_lb_listener.https.arn
  certificate_arn = aws_acm_certificate.thehub.arn

  lifecycle {
    prevent_destroy = true
  }
}
