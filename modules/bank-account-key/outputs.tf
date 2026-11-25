output "key_arn" {
  description = "ARN of the key. PAF's configuration uses the alias; the ARN is for policies."
  value       = aws_kms_key.bank_account.arn
}

output "alias_name" {
  description = "The key's alias, for example alias/prestige-bank-account-uat."
  value       = aws_kms_alias.bank_account.name
}
