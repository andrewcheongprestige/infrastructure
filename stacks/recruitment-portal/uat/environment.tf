# The Recruitment Portal UAT Elastic Beanstalk environment, imported as it is. One Docker instance on
# Amazon Linux 2023, in private subnets, behind the shared Hub 1.0 UAT load balancer (front_door.tf). The pipeline
# (pipeline.tf) deploys new versions to it.
#
# Only the settings below are managed here. Everything else (the AMI, the generated environment variable
# parameter, the health reporting document and so on) is left to Elastic Beanstalk and does not appear in a plan.
#
# Changing a setting here is a live configuration update of the environment. Terraform applies it with its own
# credentials, not the pipeline's: the pipeline role is refused when a deploy changes the environment's configuration.
#
# The application (paf-recruitmentportal-reactapp) is shared with Production and lives in stacks/recruitment-portal/shared.

locals {
  ssm_arn_prefix = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter"
}

resource "aws_elastic_beanstalk_environment" "uat" {
  name        = "paf-recruitmentportal-reactapp-uat"
  application = "paf-recruitmentportal-reactapp"
  tier        = "WebServer"

  # The platform at import. Managed platform updates move it on, so changes to it are ignored below.
  platform_arn = "arn:aws:elasticbeanstalk:ap-southeast-2::platform/Docker running on 64bit Amazon Linux 2023/4.13.10"

  # The Elastic Beanstalk service role (holds AWS-managed policies only). The full ARN, because the name alone
  # shows up as a permanent difference.
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-elasticbeanstalk-service-role"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  # Instance
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.instance.name
  }

  # Our own group. Elastic Beanstalk also attaches the default group it generated for this environment
  # (sg-09cffef7ffdd931e6, which allows ports 22 and 80 from anywhere) because DisableDefaultEC2SecurityGroup is
  # false. That group belongs to the environment's CloudFormation stack and is not part of this setting. Setting
  # DisableDefaultEC2SecurityGroup to true would detach it, but that replaces the instance, so it is a separate change.
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.instance.id
  }

  # An existing key pair, kept as it was set up.
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "EC2KeyName"
    value     = "TaskHostKeyPair"
  }

  setting {
    namespace = "aws:ec2:instances"
    name      = "InstanceTypes"
    value     = "t3.micro"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = "1"
  }

  setting {
    namespace = "aws:autoscaling:updatepolicy:rollingupdate"
    name      = "RollingUpdateEnabled"
    value     = "false"
  }

  # Network: the private subnets, no public address on the instance.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = local.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "subnet-09c611b599e257a5b,subnet-0bb55669233793b0e"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  # Plain settings the app reads. NON-SECRET values only, because they are stored in the Terraform state.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NODE_ENV"
    value     = "UAT"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "AUTH_API_BASE_URI"
    value     = "https://uat.thehub.prestigeinhomecare.com.au/auth/"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "INTEGRATION_API_BASE_URI"
    value     = "https://uat.thehub.prestigeinhomecare.com.au/integration/"
  }

  # Secrets: Elastic Beanstalk reads these from SSM when the instance starts. Only the ARN is stored here. The values
  # are never in Terraform, the build or the zip.
  setting {
    namespace = "aws:elasticbeanstalk:application:environmentsecrets"
    name      = "ISSUER_SIGNING_KEY"
    value     = "${local.ssm_arn_prefix}${local.issuer_signing_key_parameter}"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environmentsecrets"
    name      = "SESSION_SECRET"
    value     = "${local.ssm_arn_prefix}${local.ssm_parameter_path}/SESSION_SECRET"
  }

  # Managed platform updates, kept as they were set up. The window is Wednesday 10:47 am in Sydney (working hours).
  # Moving it to the weekend, like the client portal, is a separate decision.
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "TUE:23:47"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  lifecycle {
    prevent_destroy = true

    # The pipeline moves the version on every release, and managed updates move the platform.
    ignore_changes = [version_label, platform_arn]
  }
}
