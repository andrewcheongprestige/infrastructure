# The Elastic Beanstalk application that BOTH Recruitment Portal environments (UAT and Production) belong to. That is
# why it lives in this "shared" stack and not in either environment's: deleting it would delete both environments'
# versions, so Terraform is told never to destroy it.
#
# It keeps the newest 10 application versions (build-N from the build, code-pipeline-N from each deploy) and deletes the
# zip in S3 along with each version it removes. It had no rule before, so versions piled up (about 205), and every
# application in the account shares Elastic Beanstalk's limit of 1,000 application versions per Region.
resource "aws_elastic_beanstalk_application" "recruitment" {
  name = "paf-recruitmentportal-reactapp"

  appversion_lifecycle {
    service_role          = "arn:aws:iam::421089614203:role/aws-elasticbeanstalk-service-role"
    max_count             = 10
    delete_source_from_s3 = true
  }

  lifecycle {
    prevent_destroy = true
  }
}
