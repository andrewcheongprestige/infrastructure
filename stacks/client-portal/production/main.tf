module "client_portal" {
  source = "../../../modules/client-portal"

  environment = "Production"
  hostname    = "client.prestigeinhomecare.com.au"

  # Existing Prestige VPC. Private subnets for the instances (private1 in 2a, private2 in 2b;
  # private3 has no route to the internet, so it is not used).
  vpc_id             = "vpc-0fb4846013ab42265"
  private_subnet_ids = ["subnet-09c611b599e257a5b", "subnet-0bb55669233793b0e"]

  # The Hub 1.0 Production load balancer (paf-adminhub-env), which also carries recruitment.
  shared_alb_name = "awseb--AWSEB-y2FDmgJ8MYiy"

  # Must not clash with an existing rule on the listener (10 is the recruitment portal).
  listener_rule_priority = 100

  # The Elastic Beanstalk application is shared with UAT, which creates it (stacks/client-portal/uat).
  eb_environment_name   = "paf-clientportal-reactapp-env"
  create_eb_application = false

  # Plain configuration. Not secret, so it lives here where changes are reviewed in git.
  # Each backend address must end with a slash (the portal's API client depends on it).
  environment_properties = {
    # The environment's name, the way the Hub and the recruitment portal use NODE_ENV: "UAT" in UAT and "Production"
    # here. The portal reads it in app/helpers/environment.server.ts (case-insensitive) to decide, for example, that
    # session cookies are Secure and when syslog logging may be switched on.
    NODE_ENV                 = "Production"
    PORTAL_ORIGIN            = "https://client.prestigeinhomecare.com.au"
    AUTH_API_BASE_URI        = "https://thehub.prestigeinhomecare.com.au/auth/"
    INTEGRATION_API_BASE_URI = "https://thehub.prestigeinhomecare.com.au/integration/"
    PAYMENTS_API_BASE_URI    = "https://thehub.prestigeinhomecare.com.au/payments/"
  }

  # Secrets: Elastic Beanstalk reads these from SSM when the instance starts, so the values never appear
  # in the console, the bundle, the build log or the Terraform state. Create each one by hand first
  # (aws ssm put-parameter --type SecureString ...), before the environment is applied.
  environment_secrets = {
    SESSION_SECRET = "arn:aws:ssm:ap-southeast-2:421089614203:parameter/Production/ClientPortal/SESSION_SECRET"
  }
}
