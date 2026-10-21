# The Partner Portal UAT Elastic Beanstalk environment, imported as it is. One Docker instance on Amazon Linux 2023,
# in the account's default VPC with a public address, behind the Admin Hub UAT load balancer (front_door.tf). The
# pipeline (pipeline.tf) deploys new versions to it.
#
# Only the settings below are managed here. Everything else is left to Elastic Beanstalk and does not appear in a
# plan: the AMI, the generated environment variable parameter, the health reporting document, the network settings
# (none are set, so it uses the default VPC and subnets) and the security group (Elastic Beanstalk's own generated
# group, which belongs to the environment's CloudFormation stack).
#
# Compared with the recruitment portal's environment, this one still uses the shared console-made instance role
# aws-elasticbeanstalk-ec2-role and the generated security group (open on ports 22 and 80 from anywhere). Moving it
# to a dedicated role and group is a separate, later change.
#
# Changing a setting here is a live configuration update of the environment. Terraform applies it with its own
# credentials, not the pipeline's: the pipeline role is refused when a deploy changes the environment's configuration.
#
# The application (paf-partnerportal-reactapp) is shared with Production and lives in stacks/partner-portal/shared.

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  ssm_arn_prefix = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter"
}

resource "aws_elastic_beanstalk_environment" "uat" {
  name        = "paf-partnerportal-reactapp-uat"
  application = "paf-partnerportal-reactapp"
  tier        = "WebServer"

  # The platform at import. Managed platform updates move it on, so changes to it are ignored below.
  platform_arn = "arn:aws:elasticbeanstalk:ap-southeast-2::platform/Docker running on 64bit Amazon Linux 2023/4.13.9"

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
    value     = "aws-elasticbeanstalk-ec2-role"
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
    value     = "${local.ssm_arn_prefix}/PrestigeAuthServer/IssuerSigningKey"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environmentsecrets"
    name      = "SESSION_SECRET"
    value     = "${local.ssm_arn_prefix}/UAT/PartnerPortal/SESSION_SECRET"
  }

  # Managed platform updates, kept as they were set up. The window is Wednesday 9:56 am in Sydney (working hours).
  # Moving it to the weekend, like the client portal, is a separate decision.
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "TUE:22:56"
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
