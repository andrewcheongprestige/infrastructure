# The CodeBuild project that deploys Hub 1.0. Hub 1.0 has no CodePipeline: this project's buildspec
# (PAF/PAF.AdminHub/buildspec.yml) builds the app and runs "dotnet eb deploy-environment" for the environment named by
# its ENVIRONMENT variable (UAT: paf-thehub-app-uat, otherwise Production: paf-adminhub-env). One project serves both, so
# it lives in this "shared" stack and a change here affects Production deploys. It is started by hand (no webhook).
# Imported from the console-made project as it was.
#
# NOTE: the project is pointed at a personal GitHub repository (matthewcosier/prestige), not the company's
# Prestige-Inhome-Care/prestige, through a CodeConnections connection (504688c9-...) that is not the shared one the
# pipelines use. Recorded as it is; to be decided.
resource "aws_codebuild_project" "deploy" {
  name               = "AdminHub"
  project_visibility = "PRIVATE"
  queued_timeout     = 480
  build_timeout      = 60

  # The branch the project builds when it is started on its own.
  source_version = "production"

  # The existing console-made role, kept by ARN. Importing the role is a later, separate step.
  service_role   = "arn:aws:iam::421089614203:role/service-role/codebuild-AdminHub-service-role"
  encryption_key = "arn:aws:kms:ap-southeast-2:421089614203:alias/aws/s3"

  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  # Privileged mode lets the build run Docker, which the deploy may need.
  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_LARGE"
    image                       = "aws/codebuild/standard:7.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = true
  }

  # Logs go to CodeBuild's default group, /aws/codebuild/AdminHub (the group resource below).
  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/matthewcosier/prestige"
    buildspec           = "PAF/PAF.AdminHub/buildspec.yml"
    git_clone_depth     = 1
    report_build_status = false

    auth {
      type     = "CODECONNECTIONS"
      resource = "arn:aws:codeconnections:ap-southeast-2:421089614203:connection/504688c9-2671-4845-b808-544caea9555a"
    }

    git_submodules_config {
      fetch_submodules = false
    }
  }

  # Used for Production deploys too: Terraform must never delete it.
  lifecycle {
    prevent_destroy = true
  }
}

# CodeBuild's default log group for the project. Retention is as it was (kept forever); changing it is a separate
# decision.
resource "aws_cloudwatch_log_group" "deploy" {
  name              = "/aws/codebuild/AdminHub"
  retention_in_days = 0

  lifecycle {
    prevent_destroy = true
  }
}
