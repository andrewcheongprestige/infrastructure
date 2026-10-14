locals {
  eb_name = "paf-clientportal-reactapp-${lower(var.environment)}"
}

# Newest Docker platform on Amazon Linux 2023 at the time the environment is created.
data "aws_elastic_beanstalk_solution_stack" "docker" {
  most_recent = true
  name_regex  = var.platform_name_regex
}

# One application per environment, so UAT and Production can be built from separate Terraform states.
resource "aws_elastic_beanstalk_application" "this" {
  name        = local.eb_name
  description = "Client portal (${var.environment})"
}

resource "aws_elastic_beanstalk_environment" "this" {
  name                = local.eb_name
  application         = aws_elastic_beanstalk_application.this.name
  solution_stack_name = data.aws_elastic_beanstalk_solution_stack.docker.name

  # Network: private subnets, no public IP.
  setting {
    namespace = "aws:ec2:vpc"
    name      = "VPCId"
    value     = var.vpc_id
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "Subnets"
    value     = join(",", var.private_subnet_ids)
  }

  setting {
    namespace = "aws:ec2:vpc"
    name      = "AssociatePublicIpAddress"
    value     = "false"
  }

  # No load balancer of its own: traffic arrives through the shared ALB and our target group.
  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "EnvironmentType"
    value     = "SingleInstance"
  }

  setting {
    namespace = "aws:elasticbeanstalk:environment"
    name      = "ServiceRole"
    value     = var.service_role
  }

  # Instances: dedicated role and firewall, no SSH key, IMDSv1 off.
  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "IamInstanceProfile"
    value     = aws_iam_instance_profile.instance.name
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "SecurityGroups"
    value     = aws_security_group.instance.id
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "DisableDefaultEC2SecurityGroup"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "InstanceType"
    value     = var.instance_type
  }

  setting {
    namespace = "aws:autoscaling:launchconfiguration"
    name      = "DisableIMDSv1"
    value     = "true"
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MinSize"
    value     = tostring(var.min_size)
  }

  setting {
    namespace = "aws:autoscaling:asg"
    name      = "MaxSize"
    value     = tostring(var.max_size)
  }

  # Patching: Elastic Beanstalk applies minor platform updates in a weekly window.
  setting {
    namespace = "aws:elasticbeanstalk:healthreporting:system"
    name      = "SystemType"
    value     = "enhanced"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "ManagedActionsEnabled"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions"
    name      = "PreferredStartTime"
    value     = var.maintenance_window_start
  }

  setting {
    namespace = "aws:elasticbeanstalk:managedactions:platformupdate"
    name      = "UpdateLevel"
    value     = "minor"
  }

  # Logs go to CloudWatch and are kept after the environment is deleted.
  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "StreamLogs"
    value     = "true"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "DeleteOnTerminate"
    value     = "false"
  }

  setting {
    namespace = "aws:elasticbeanstalk:cloudwatch:logs"
    name      = "RetentionInDays"
    value     = tostring(var.log_retention_days)
  }

  dynamic "setting" {
    for_each = var.environment_properties

    content {
      namespace = "aws:elasticbeanstalk:application:environment"
      name      = setting.key
      value     = setting.value
    }
  }

  dynamic "setting" {
    for_each = var.environment_secrets

    content {
      namespace = "aws:elasticbeanstalk:application:environmentsecrets"
      name      = setting.key
      value     = setting.value
    }
  }

  lifecycle {
    # Managed updates move the platform version after creation. Do not fight them.
    ignore_changes = [solution_stack_name]
  }
}

# Registers the environment's Auto Scaling group with the target group, so the shared ALB
# sends the portal's traffic to it. If Elastic Beanstalk ever replaces its Auto Scaling group
# (a rebuild), this attachment is lost until the next terraform apply.
resource "aws_autoscaling_attachment" "this" {
  autoscaling_group_name = aws_elastic_beanstalk_environment.this.autoscaling_groups[0]
  lb_target_group_arn    = aws_lb_target_group.this.arn
}
