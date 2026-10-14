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
}
