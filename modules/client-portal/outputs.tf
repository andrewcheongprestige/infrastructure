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

output "certificate_arn" {
  value = aws_acm_certificate.this.arn
}

output "ssm_parameter_path" {
  value = local.ssm_parameter_path
}
