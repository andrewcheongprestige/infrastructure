# Instances: reachable only from the shared load balancer.
resource "aws_security_group" "instance" {
  name        = "${local.name_prefix}-instance"
  description = "Client portal instances"
  vpc_id      = var.vpc_id

  tags = { Name = "${local.name_prefix}-instance" }
}

# One rule per security group attached to the shared load balancer.
resource "aws_vpc_security_group_ingress_rule" "instance_from_alb" {
  for_each = data.aws_lb.shared.security_groups

  security_group_id            = aws_security_group.instance.id
  description                  = "HTTP from the shared load balancer only"
  ip_protocol                  = "tcp"
  from_port                    = 80
  to_port                      = 80
  referenced_security_group_id = each.value
}

# The VPC has an interface endpoint for SSM with private DNS switched on, so the instance's calls to SSM are
# redirected to it. The endpoint's own security group only accepts HTTPS from approved groups, so without this
# rule the instance cannot fetch the environment's secrets and the deploy fails with an "i/o timeout".
# This adds one rule to the endpoint's group. It does not change the endpoint itself.
data "aws_vpc_endpoint" "ssm" {
  vpc_id       = var.vpc_id
  service_name = "com.amazonaws.${data.aws_region.current.region}.ssm"
}

resource "aws_vpc_security_group_ingress_rule" "ssm_endpoint_from_instance" {
  for_each = data.aws_vpc_endpoint.ssm.security_group_ids

  security_group_id            = each.value
  description                  = "HTTPS from the ${local.name_prefix} instances"
  ip_protocol                  = "tcp"
  from_port                    = 443
  to_port                      = 443
  referenced_security_group_id = aws_security_group.instance.id
}

# Instances need outbound access (through the NAT gateway) for AWS APIs, the Prestige API
# and Cybersource. Tighten this later if the destinations can be pinned down.
resource "aws_vpc_security_group_egress_rule" "instance_all" {
  security_group_id = aws_security_group.instance.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
