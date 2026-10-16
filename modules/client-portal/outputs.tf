output "alb_dns_name" {
  description = "Point the portal hostname (a CNAME in the external DNS) at the shared load balancer."
  value       = data.aws_lb.shared.dns_name
}

output "target_group_arn" {
  value = aws_lb_target_group.this.arn
}

output "instance_security_group_id" {
  value = aws_security_group.instance.id
}

output "instance_profile_name" {
  value = aws_iam_instance_profile.instance.name
}

output "instance_role_name" {
  value = aws_iam_role.instance.name
}

output "certificate_arn" {
  value = aws_acm_certificate.this.arn
}

output "ssm_parameter_path" {
  value = local.ssm_parameter_path
}

output "eb_application_name" {
  description = "Use as APP_NAME in the portal's buildspec."
  value       = var.eb_application_name
}

output "eb_environment_name" {
  description = "The environment the pipeline deploys to."
  value       = aws_elastic_beanstalk_environment.this.name
}

output "eb_environment_id" {
  description = "Elastic Beanstalk's own ID for the environment (e-...). Its CloudFormation stack is named after it."
  value       = aws_elastic_beanstalk_environment.this.id
}
