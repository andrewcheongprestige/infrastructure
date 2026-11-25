# The Production key for bank account details saved from the client portal (HUB-709). PAF encrypts with it, and only encrypts.
#
# NOT YET APPLIED. Check the role below before applying: Hub 1.0 Production is not in Terraform, so this assumes it runs as the same
# shared instance role as UAT (aws-elasticbeanstalk-ec2-role). If it uses a different instance profile, change the ARN first. There is
# no personal or testing grant here on purpose.
module "bank_account_key" {
  source = "../../../modules/bank-account-key"

  environment = "Production"

  encrypt_principal_arns = [
    "arn:aws:iam::421089614203:role/aws-elasticbeanstalk-ec2-role",
  ]
}
