variable "name" {
  description = "Name of the pipeline and the build project, following the other portals (for example ClientPortal-UAT)."
  type        = string
}

variable "github_repository" {
  description = "GitHub repository in owner/name form."
  type        = string
}

variable "branch" {
  description = "Branch that triggers the pipeline when pushed to."
  type        = string
}

variable "connection_arn" {
  description = "Existing CodeConnections connection to GitHub. It is reused, not created here."
  type        = string
}

variable "eb_application_name" {
  description = "Elastic Beanstalk application to deploy to."
  type        = string
}

variable "eb_environment_name" {
  description = "Elastic Beanstalk environment to deploy to."
  type        = string
}

variable "eb_environment_id" {
  description = "Elastic Beanstalk's ID for the environment (e-...). Its CloudFormation stack is awseb-<id>-stack."
  type        = string
}

variable "build_image" {
  description = "CodeBuild image. The other portals use aws/codebuild/standard:7.0."
  type        = string
  default     = "aws/codebuild/standard:7.0"
}

variable "log_retention_days" {
  description = "How long CloudWatch keeps the build logs."
  type        = number
  default     = 30
}

variable "artifact_retention_days" {
  description = "How long pipeline artifacts are kept in S3."
  type        = number
  default     = 30
}
