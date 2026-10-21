# The two Elastic Beanstalk applications for the PX2 workers. Each is shared by its UAT and Production environments
# (paf-px2-consumer-dotnetapp-uat and -env, paf-px2-isolator-dotnetapp-uat and -env), which is why they live in this
# "shared" stack and not in either environment's: deleting an application would delete both environments' versions, so
# Terraform is told never to destroy them.
#
# Neither has a version lifecycle rule enabled (a disabled one exists), so application versions pile up (about 124 each).
# Whether to keep only the newest N is a separate, later decision.

resource "aws_elastic_beanstalk_application" "consumer" {
  name = "paf-px2-consumer-dotnetapp"

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_elastic_beanstalk_application" "isolator" {
  name = "paf-px2-isolator-dotnetapp"

  lifecycle {
    prevent_destroy = true
  }
}
