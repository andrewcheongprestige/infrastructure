# The two Elastic Beanstalk applications for the PX2 workers. Each is shared by its UAT and Production environments
# (paf-px2-consumer-dotnetapp-uat and -env, paf-px2-isolator-dotnetapp-uat and -env), which is why they live in this
# "shared" stack and not in either environment's: deleting an application would delete both environments' versions, so
# Terraform is told never to destroy them.
#
# Each keeps the newest 10 application versions and deletes the zip in S3 along with each version it removes. Neither had
# a rule enabled (a disabled one existed), so versions piled up (about 128 each), and every application in the account
# shares Elastic Beanstalk's limit of 1,000 application versions per Region.

resource "aws_elastic_beanstalk_application" "consumer" {
  name = "paf-px2-consumer-dotnetapp"

  appversion_lifecycle {
    service_role          = "arn:aws:iam::421089614203:role/aws-elasticbeanstalk-service-role"
    max_count             = 10
    delete_source_from_s3 = true
  }

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_elastic_beanstalk_application" "isolator" {
  name = "paf-px2-isolator-dotnetapp"

  appversion_lifecycle {
    service_role          = "arn:aws:iam::421089614203:role/aws-elasticbeanstalk-service-role"
    max_count             = 10
    delete_source_from_s3 = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
