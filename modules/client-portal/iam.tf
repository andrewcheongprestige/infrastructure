data "aws_caller_identity" "current" {}

data "aws_region" "current" {}

locals {
  name_prefix = "client-portal-${lower(var.environment)}"

  # Parameters are created by hand (the values are secret) under this path.
  ssm_parameter_path = "/${var.environment}/ClientPortal"
}

# Dedicated instance role. The portal does not share the default aws-elasticbeanstalk-ec2-role.
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

# Read only this portal's own parameters, and decrypt them through SSM.
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
        Resource = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter${local.ssm_parameter_path}/*"
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
