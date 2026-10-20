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

variable "private_subnet_ids" {
  description = "Private subnets (routed through a NAT gateway) for the instances. Use two availability zones."
  type        = list(string)
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

variable "instance_type" {
  description = "EC2 instance type for the portal."
  type        = string
  default     = "t3.micro"
}

variable "min_size" {
  description = "Minimum number of instances."
  type        = number
  default     = 1
}

variable "max_size" {
  description = "Maximum number of instances."
  type        = number
  default     = 1
}

variable "eb_application_name" {
  description = "Elastic Beanstalk application, shared by all environments."
  type        = string
  default     = "paf-clientportal-reactapp"
}

variable "create_eb_application" {
  description = "Create the Elastic Beanstalk application. True in the first environment built (UAT), false in the others."
  type        = bool
  default     = true
}

variable "eb_environment_name" {
  description = "Elastic Beanstalk environment name, following the other portals (for example paf-clientportal-reactapp-uat, and -env for Production)."
  type        = string
}

variable "service_role" {
  description = "Existing Elastic Beanstalk service role (holds AWS-managed policies only)."
  type        = string
  default     = "aws-elasticbeanstalk-service-role"
}

variable "platform_name_regex" {
  description = "Picks the newest matching Elastic Beanstalk platform when the environment is first created."
  type        = string
  default     = "^64bit Amazon Linux 2023 (.*) running Docker$"
}

variable "maintenance_window_start" {
  description = "When managed platform updates may start, in UTC (day:hh:mm). Sat 15:00 UTC is Sunday 1 or 2 am in Sydney."
  type        = string
  default     = "Sat:15:00"
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the instance logs."
  type        = number
  default     = 30
}

variable "environment_properties" {
  description = "Plain environment variables for the app. NON-SECRET values only, as they are stored in the Terraform state."
  type        = map(string)
  default     = {}

  # Stops a placeholder from being deployed by accident.
  validation {
    condition     = alltrue([for v in values(var.environment_properties) : !strcontains(v, "REPLACE-ME")])
    error_message = "An environment property still contains the placeholder REPLACE-ME. Put the real value in stacks/client-portal/<env>/main.tf."
  }
}

variable "environment_secrets" {
  description = "Environment variables whose values Elastic Beanstalk reads from SSM at startup. Map of variable name to SSM parameter ARN."
  type        = map(string)
  default     = {}
}
