# Same image and size as the other portals' build project (RecruitmentPortalReact).
# Not privileged: it does not build Docker images, because Elastic Beanstalk builds the
# Dockerfile on the instance.
resource "aws_codebuild_project" "this" {
  name          = var.name
  description   = "Builds the client portal (${var.name})"
  service_role  = aws_iam_role.codebuild.arn
  build_timeout = 20

  # The pipeline supplies the source and receives the artifact.
  source {
    type = "CODEPIPELINE"
  }

  artifacts {
    type = "CODEPIPELINE"
  }

  environment {
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = var.build_image
    type                        = "LINUX_CONTAINER"
    image_pull_credentials_type = "CODEBUILD"
  }

  logs_config {
    cloudwatch_logs {
      group_name = aws_cloudwatch_log_group.build.name
    }
  }
}
