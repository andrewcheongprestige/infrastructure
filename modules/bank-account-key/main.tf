data "aws_caller_identity" "current" {}

# The key that protects clients' bank account details (BSB and account number). PAF calls Encrypt on each value directly, with no data
# keys, and stores only the ciphertext in PrestigeDB, so the database never holds anything that can be decrypted without this key.
#
# Nothing in this module can decrypt. Decrypt is deliberately left out of the key policy for every named principal: the process that
# will push the details to Business Central is not designed yet, and it will get its own role and its own grant when it is. The
# account root statement below is the AWS default, which lets IAM policies grant access too, so anyone who can write IAM policies
# could give themselves Decrypt. Every use of the key, and every change to who can use it, is recorded in CloudTrail.
resource "aws_kms_key" "bank_account" {
  description              = "Protects bank account details (BSB and account number) saved from the client portal (${var.environment})"
  key_usage                = "ENCRYPT_DECRYPT"
  customer_master_key_spec = "SYMMETRIC_DEFAULT"
  enable_key_rotation      = true
  deletion_window_in_days  = 30

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        # The standard statement. Without it the key could become unmanageable if the principals below were ever deleted.
        Sid       = "AccountAdministration"
        Effect    = "Allow"
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" }
        Action    = "kms:*"
        Resource  = "*"
      },
      {
        # Encrypt only, and only when the caller supplies an encryption context, so a ciphertext is always tied to the client it
        # belongs to and cannot be moved to another client's row and decrypted there.
        Sid       = "EncryptWithAContext"
        Effect    = "Allow"
        Principal = { AWS = var.encrypt_principal_arns }
        Action    = "kms:Encrypt"
        Resource  = "*"
        Condition = {
          Null = { "kms:EncryptionContextKeys" = "false" }
        }
      }
    ]
  })
}

resource "aws_kms_alias" "bank_account" {
  name          = "alias/prestige-bank-account-${lower(var.environment)}"
  target_key_id = aws_kms_key.bank_account.key_id
}
