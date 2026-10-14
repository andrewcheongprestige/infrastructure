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

# Instances need outbound access (through the NAT gateway) for AWS APIs, the Prestige API
# and Cybersource. Tighten this later if the destinations can be pinned down.
resource "aws_vpc_security_group_egress_rule" "instance_all" {
  security_group_id = aws_security_group.instance.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
