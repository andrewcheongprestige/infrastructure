# The Hub 1.0 UAT Elastic Beanstalk environment, imported as it is: the legacy "The Hub" ASP.NET Core app on .NET 8 /
# Amazon Linux 2023, behind its own Elastic Beanstalk application load balancer (a LoadBalanced environment).
#
# This environment OWNS its load balancer: the load balancer, its HTTPS listener (built by Elastic Beanstalk from the
# aws:elbv2:listener:443 settings below), its default target group and their security groups belong to its
# CloudFormation stack. The recruitment and client portals add host rules and certificates to that listener from their
# own stacks, so rebuilding this environment would take their front door with it.
#
# Hub 1.0 is deployed without a pipeline: a CodeBuild project (AdminHub, in stacks/hub1/shared) runs
# "dotnet eb deploy-environment" for the environment named by its ENVIRONMENT variable.
#
# Only the settings below are managed here. Everything else is left to Elastic Beanstalk and does not appear in a plan:
# the AMI, the generated environment variable parameter, the health reporting document, the notification settings
# (the environment notifies a personal e-mail address through an Elastic Beanstalk SNS topic; that address is left out
# of this file on purpose) and the two security groups that Elastic Beanstalk generated (the instance's and the load
# balancer's). Both the account's default group and the generated one are attached to the instance.
#
# Like the Partner Portal and Admin Hub, it uses the shared console-made instance role aws-elasticbeanstalk-ec2-role.
#
# Changing a setting here is a live configuration update of the environment, and, through the listener settings, of the
# shared load balancer. Terraform applies it with its own credentials.
#
# The application (paf-adminhub-app) is shared with Production (paf-adminhub-env) and lives in stacks/hub1/shared.

data "aws_region" "current" {}

data "aws_caller_identity" "current" {}

locals {
  ssm_arn_prefix = "arn:aws:ssm:${data.aws_region.current.region}:${data.aws_caller_identity.current.account_id}:parameter"
}

resource "aws_elastic_beanstalk_environment" "uat" {
  name                = "paf-thehub-app-uat"
  description         = "UAT environment for The Hub"
  application         = "paf-adminhub-app"
  tier                = "WebServer"
  solution_stack_name = "64bit Amazon Linux 2023 v3.11.10 running .NET 8"

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:role/aws-elasticbeanstalk-service-role"
  }

  # Its own application load balancer (the environment type itself is the default, LoadBalanced).
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "LoadBalancerType"
    value     = "application"
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
    value     = "t3.small"
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

  # Network: the instance in one private subnet (no public address), the load balancer in two public subnets.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = "vpc-0fb4846013ab42265"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = "subnet-09c611b599e257a5b"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "ELBSubnets"
    value     = "subnet-03438ff699fa4937e,subnet-0e0ffaa9f62a14f7d"
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  # How Elastic Beanstalk checks the instance's health, and how the load balancer's default target group does.
  setting {
    namespace = "aws:elasticbeanstalk:application"
    name      = "Application Healthcheck URL"
    value     = "/"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Port"
    value     = "80"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "Protocol"
    value     = "HTTP"
  }

  # The app's anonymous health endpoint (Program.cs: MapGet("/ping")). The root path redirects to Hub 2.0 (a 302), so a
  # check of "/" can never return 200. The target group's check was originally set to this path outside the
  # environment's settings, and an update that made Elastic Beanstalk re-apply its own settings reset it to "/" and
  # turned the environment Red; recording the path here keeps it from being reset again.
  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckPath"
    value     = "/ping"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "MatcherHTTPCode"
    value     = "200"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckInterval"
    value     = "15"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthCheckTimeout"
    value     = "5"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "HealthyThresholdCount"
    value     = "3"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "UnhealthyThresholdCount"
    value     = "5"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "DeregistrationDelay"
    value     = "20"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessEnabled"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessType"
    value     = "lb_cookie"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment:process:default"
    name      = "StickinessLBCookieDuration"
    value     = "86400"
  }

  # The load balancer's HTTPS listener, which Elastic Beanstalk builds from these settings. Its default certificate is
  # adminhub.platformx-api.com (shared with another load balancer, so referenced by ARN here). The certificates of the
  # other applications on this listener are added to it separately.
  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "ListenerEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "Protocol"
    value     = "HTTPS"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLCertificateArns"
    value     = "arn:aws:acm:ap-southeast-2:421089614203:certificate/493c625a-0f08-4a49-9b87-f2765905a670"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "SSLPolicy"
    value     = "ELBSecurityPolicy-TLS13-1-3-2021-06"
  }

  setting {
    namespace = "aws:elbv2:listener:443"
    name      = "DefaultProcess"
    value     = "default"
  }

  # Plain settings the app reads. NON-SECRET values only, because they are stored in the Terraform state. The
  # Cybersource host and merchant ID are the test (sandbox) ones.
  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "ASPNETCORE_ENVIRONMENT"
    value     = "UAT"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "Cybersource__Host"
    value     = "apitest.cybersource.com"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environment"
    name      = "Cybersource__MerchantId"
    value     = "nabsandboxdemo040001001"
  }

  # Secrets: Elastic Beanstalk reads these from SSM when the instance starts. Only the ARN is stored here.
  setting {
    namespace = "aws:elasticbeanstalk:application:environmentsecrets"
    name      = "Cybersource__KeyId"
    value     = "${local.ssm_arn_prefix}/UAT/CybersourceKeyId"
  }

  setting {
    namespace = "aws:elasticbeanstalk:application:environmentsecrets"
    name      = "Cybersource__SharedSecret"
    value     = "${local.ssm_arn_prefix}/UAT/CybersourceSharedSecret"
  }

  # Managed platform updates, kept as they were set up. The window is Saturday 12:27 UTC, which is Saturday 11:27 pm in
  # Sydney (outside working hours).
  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = "SAT:12:27"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  lifecycle {
    prevent_destroy = true

    # The deploy moves the version on every release, and managed updates move the platform.
    ignore_changes = [version_label, solution_stack_name]
  }
}
