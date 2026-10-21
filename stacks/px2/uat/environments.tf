# The two PX2 UAT worker environments, imported as they are. Both are single-instance Worker environments on .NET 8 /
# Amazon Linux 2023, in the private subnets, with no load balancer: each reads messages from an Elastic Beanstalk
# SQS queue (created by Elastic Beanstalk, part of the environment's CloudFormation stack) through its worker daemon.
# The pipeline (pipeline.tf) deploys new versions to both.
#
# The configuration the apps need (including secrets) is baked into appsettings.Production.json by the build, not set
# here, so these settings hold no secrets and are safe in the state.
#
# Only the settings below are managed. Everything else is left to Elastic Beanstalk and does not appear in a plan: the
# AMI, the generated environment variable parameter, the health reporting document, and the security groups. Each
# instance has three groups: the account's default group (sg-08e027d43f13c12cc), ec2-rds-3 (sg-0c9a0a2725c888ef1,
# which lets it reach the SQL Server and must not be modified) and the group Elastic Beanstalk generated for it. They
# are not managed here because the generated group's ID changes if the environment is rebuilt.
#
# Both use the shared console-made instance role aws-elasticbeanstalk-ec2-role, which carries PXMasterPolicy that the
# workers need.
#
# Changing a setting here is a live configuration update of the environment. Terraform applies it with its own
# credentials, not the pipeline's: the pipeline role may be refused when a deploy changes the environment's
# configuration.
#
# The applications (paf-px2-consumer-dotnetapp, paf-px2-isolator-dotnetapp) are shared with the Production side and live
# in stacks/px2/shared.

data "aws_caller_identity" "current" {}

locals {
  eb_service_role_arn = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-elasticbeanstalk-service-role"
  vpc_id              = "vpc-0fb4846013ab42265"
  private_subnets     = "subnet-09c611b599e257a5b,subnet-0bb55669233793b0e"
}

resource "aws_elastic_beanstalk_environment" "consumer" {
  name                = "paf-px2-consumer-dotnetapp-uat"
  application         = "paf-px2-consumer-dotnetapp"
  tier                = "Worker"
  solution_stack_name = "64bit Amazon Linux 2023 v3.11.10 running .NET 8"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = local.eb_service_role_arn
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

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
    value     = local.private_subnets
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  # Plain settings the app reads: the environment name and the names of the SQS queues it works with (created elsewhere).
  # NON-SECRET values only, because they are stored in the Terraform state.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "Environment"
    value     = "UAT"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "HighPriorityQueueName"
    value     = "px2-uat-api-requests-high-priority"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "NormalPriorityQueueName"
    value     = "px2-uat-api-requests-normal-priority"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "LowPriorityQueueName"
    value     = "px2-uat-api-requests-low-priority"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "TlwHighPriorityQueueName"
    value     = "px2-uat-tlw-api-requests-high-priority"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "TlwNormalPriorityQueueName"
    value     = "px2-uat-tlw-api-requests-normal-priority"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "TlwLowPriorityQueueName"
    value     = "px2-uat-tlw-api-requests-low-priority"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "WebhookQueueName"
    value     = "px2-uat-webhook-input.fifo"
  }

  # Managed platform updates, kept as they were set up. The window is Wednesday 22:58 UTC, which is Thursday 9:58 am in
  # Sydney (working hours). Moving it to the weekend is a separate decision.
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "WED:22:58"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  lifecycle {
    prevent_destroy = true

    # The pipeline moves the version on every release, and managed updates move the platform.
    ignore_changes = [version_label, solution_stack_name]
  }
}

resource "aws_elastic_beanstalk_environment" "isolator" {
  name                = "paf-px2-isolator-dotnetapp-uat"
  application         = "paf-px2-isolator-dotnetapp"
  tier                = "Worker"
  solution_stack_name = "64bit Amazon Linux 2023 v3.11.10 running .NET 8"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = local.eb_service_role_arn
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

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
    value     = local.private_subnets
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "Environment"
    value     = "UAT"
  }

  # Managed platform updates, kept as they were set up. The window is Tuesday 00:49 UTC, which is Tuesday 11:49 am in
  # Sydney (working hours). Moving it to the weekend is a separate decision.
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "TUE:00:49"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  lifecycle {
    prevent_destroy = true

    # The pipeline moves the version on every release, and managed updates move the platform.
    ignore_changes = [version_label, solution_stack_name]
  }
}
