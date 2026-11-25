variable "environment" {
  description = "Environment name, for example UAT or Production. Used in the key's alias."
  type        = string
}

variable "encrypt_principal_arns" {
  description = "IAM roles and users allowed to encrypt with the key, and only to encrypt. Nothing here can decrypt."
  type        = list(string)
}
