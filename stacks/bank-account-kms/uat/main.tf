# The UAT key for bank account details saved from the client portal (HUB-709). PAF encrypts with it, and only encrypts.
#
# Who may encrypt:
#  - aws-elasticbeanstalk-ec2-role: the instance role of the Hub 1.0 UAT environment, where PAF runs (see stacks/hub1/uat). It is
#    shared with other environments and is not managed in Terraform, so nothing about the role is changed here: the grant is made
#    in the key's own policy. Encrypting reveals nothing, so sharing the role is not a risk to the data.
#  - PXMaster: the IAM user used to run PAF locally against UAT. Remove it from this list once local testing is finished.
module "bank_account_key" {
  source = "../../../modules/bank-account-key"

  environment = "UAT"

  encrypt_principal_arns = [
    "arn:aws:iam::421089614203:role/aws-elasticbeanstalk-ec2-role",
    "arn:aws:iam::421089614203:user/PXMaster",
  ]
}
