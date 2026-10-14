output "alb_dns_name" {
  description = "Create a CNAME from uat.client.prestigeinhomecare.com.au to this."
  value       = module.client_portal.alb_dns_name
}

output "certificate_arn" {
  value = module.client_portal.certificate_arn
}

output "ssm_parameter_path" {
  value = module.client_portal.ssm_parameter_path
}
