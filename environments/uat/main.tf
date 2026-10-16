module "client_portal" {
  source = "../../modules/client-portal"

  environment = "UAT"
  hostname    = "uat.client.prestigeinhomecare.com.au"

  # Existing Prestige VPC. Private subnets for the instances (private1 in 2a, private2 in 2b;
  # private3 has no route to the internet, so it is not used).
  vpc_id             = "vpc-0fb4846013ab42265"
  private_subnet_ids = ["subnet-09c611b599e257a5b", "subnet-0bb55669233793b0e"]

  # The Hub 1.0 UAT load balancer (also carries uat.recruitment).
  shared_alb_name = "awseb--AWSEB-pJ8SZGoYPqFo"

  # Must not clash with an existing rule on the listener (check with aws elbv2 describe-rules).
  listener_rule_priority = 100

  # UAT creates the shared Elastic Beanstalk application (Production will not).
  eb_environment_name   = "paf-clientportal-reactapp-uat"
  create_eb_application = true

  # Plain configuration. Not secret, so it lives here where changes are reviewed in git.
  # Each backend address must end with a slash (the portal's API client depends on it).
  environment_properties = {
    PORTAL_ORIGIN            = "https://uat.client.prestigeinhomecare.com.au"
    AUTH_API_BASE_URI        = "https://uat.thehub.prestigeinhomecare.com.au/auth/"
    INTEGRATION_API_BASE_URI = "https://uat.thehub.prestigeinhomecare.com.au/integration/"
    PAYMENTS_API_BASE_URI    = "https://uat.thehub.prestigeinhomecare.com.au/payments/"
  }

  # Secrets: Elastic Beanstalk reads these from SSM when the instance starts, so the values never appear
  # in the console, the bundle, the build log or the Terraform state. Create each one by hand first:
  # aws ssm put-parameter --type SecureString ... (see the SESSION_SECRET command in the runbook).
  environment_secrets = {
    SESSION_SECRET = "arn:aws:ssm:ap-southeast-2:421089614203:parameter/UAT/ClientPortal/SESSION_SECRET"
  }
}
