variable "environment" {
  description = "Environment name, for example UAT or Production. Used in resource names and the SSM path."
  type        = string
}

variable "hostname" {
  description = "Public hostname for the portal, for example uat.client.prestigeinhomecare.com.au."
  type        = string
}

variable "vpc_id" {
  description = "VPC the portal runs in. Must be the same VPC as the shared load balancer."
  type        = string
}

variable "shared_alb_name" {
  description = "Name of the existing, shared Application Load Balancer. The portal is added to it as a hostname rule."
  type        = string
}

variable "listener_rule_priority" {
  description = "Priority of the portal's rule on the shared HTTPS listener. Must not clash with an existing rule."
  type        = number
}

variable "health_check_path" {
  description = "Path the load balancer calls to check the portal is healthy."
  type        = string
  default     = "/ping"
}
