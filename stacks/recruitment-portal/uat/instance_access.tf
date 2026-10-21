# What the Recruitment Portal UAT instance runs as and who it can talk to. New resources only: nothing here is
# used until the Elastic Beanstalk environment is switched to this role and security group.
#
# The environment currently runs as the shared console-made role aws-elasticbeanstalk-ec2-role (which also carries
# PXMasterPolicy) and in an Elastic Beanstalk generated security group (open on ports 22 and 80 to the world, and
# deleted with the environment's CloudFormation stack). This replaces both, following the client portal
# (modules/client-portal): a role that can read only its own parameters, and a group reachable only from the shared
# load balancer.

data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix = "recruitment-portal-uat"
  vpc_id      = "vpc-0fb4846013ab42265"

  # The portal's own parameters live under this path. The values are secret, so they are created by hand.
  ssm_parameter_path = "/UAT/RecruitmentPortal"

  # The issuer's signing key is shared with the auth server, so it lives under the auth server's path.
  issuer_signing_key_parameter = "/PrestigeAuthServer/IssuerSigningKey"
}

resource "aws_iam_role" "instance" {
  name = "${local.name_prefix}-instance"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

# Standard Elastic Beanstalk instance permissions (deployment bundle in S3, CloudWatch logs).
resource "aws_iam_role_policy_attachment" "web_tier" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AWSElasticBeanstalkWebTier"
}

# Lets us open a shell through Session Manager, so no SSH key or open port 22 is needed.
resource "aws_iam_role_policy_attachment" "ssm_core" {
  role       = aws_iam_role.instance.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# Read only the portal's own parameters. The issuer key is a plain String parameter, so only SESSION_SECRET (a
# SecureString) needs decrypting, which is allowed only through SSM.
resource "aws_iam_role_policy" "read_parameters" {
  name = "read-portal-parameters"
  role = aws_iam_role.instance.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = [
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_parameter_path}/*",
          "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.issuer_signing_key_parameter}"
        ]
      },
      {
        Effect   = "Allow"
        Action   = "kms:Decrypt"
        Resource = "arn:aws:kms:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:key/*"
        Condition = {
          StringEquals = {
            "kms:ViaService" = "ssm.${data.aws_region.current.region}.amazonaws.com"
          }
        }
      }
    ]
  })
}

resource "aws_iam_instance_profile" "instance" {
  name = "${local.name_prefix}-instance"
  role = aws_iam_role.instance.name
}

# Instances: reachable only from the shared load balancer.
resource "aws_security_group" "instance" {
  name        = "${local.name_prefix}-instance"
  description = "Recruitment portal UAT instances"
  vpc_id      = local.vpc_id

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
  vpc_id       = local.vpc_id
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

# Instances need outbound access (through the NAT gateway) for AWS APIs and the Prestige APIs. Tighten this later
# if the destinations can be pinned down.
resource "aws_vpc_security_group_egress_rule" "instance_all" {
  security_group_id = aws_security_group.instance.id
  description       = "All outbound traffic"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
