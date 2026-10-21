# The Elastic Beanstalk application for Hub 1.0 ("The Hub", PAF.AdminHub). It is shared by the UAT environment
# (paf-thehub-app-uat) and the Production environment (paf-adminhub-env), which is why it lives in this "shared" stack and
# not in either environment's: deleting it would delete both environments' versions, so Terraform is told never to
# destroy it.
#
# It keeps the newest 50 application versions and deletes the zip in S3 along with each version it removes. That rule
# was already on the application and is recorded here as it was.
resource "aws_elastic_beanstalk_application" "hub" {
  name = "paf-adminhub-app"

  appversion_lifecycle {
    service_role          = "arn:aws:iam::421089614203:role/aws-elasticbeanstalk-service-role"
    max_count             = 50
    delete_source_from_s3 = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
