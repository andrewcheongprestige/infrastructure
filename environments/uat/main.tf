module "client_portal" {
  source = "../../modules/client-portal"

  environment = "UAT"
  hostname    = "uat.client.prestigeinhomecare.com.au"

  # Existing Prestige VPC, and the Hub 1.0 UAT load balancer (also carries uat.recruitment).
  vpc_id          = "vpc-0fb4846013ab42265"
  shared_alb_name = "awseb--AWSEB-pJ8SZGoYPqFo"

  # Must not clash with an existing rule on the listener (check with aws elbv2 describe-rules).
  listener_rule_priority = 100
}
