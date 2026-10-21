# The Elastic Beanstalk application that BOTH Recruitment Portal environments (UAT and Production) belong to. That is
# why it lives in this "shared" stack and not in either environment's: deleting it would delete both environments'
# versions, so Terraform is told never to destroy it.
#
# It has no version lifecycle rule today, so application versions (build-N from the build, code-pipeline-N from each
# deploy) pile up. Whether to keep only the newest N (the client portal keeps 25) is a separate, later decision.
resource "aws_elastic_beanstalk_application" "recruitment" {
  name = "paf-recruitmentportal-reactapp"

  lifecycle {
    prevent_destroy = true
  }
}
