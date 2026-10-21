# The CodeBuild project that BOTH Partner Portal pipelines (PartnerPortalReactUAT and PartnerPortalReact-PROD) use.
# That is why it lives in this "shared" stack and not in either environment's: a change here affects Production
# builds as well as UAT ones. Each pipeline passes its own BUILD_ENV, and the repo's buildspec.yml does the build.
# Imported from the console-made project as it was.
resource "aws_codebuild_project" "build" {
  name               = "PartnerPortalReact"
  project_visibility = "PRIVATE"
  queued_timeout     = 480
  build_timeout      = 60

  # The existing console-made role, kept by ARN. Importing the role is a later, separate step.
  service_role   = "arn:aws:iam::421089614203:role/service-role/codebuild-PartnerPortalReact-service-role"
  encryption_key = "arn:aws:kms:ap-southeast-2:421089614203:alias/aws/s3"

  # The pipelines supply the source and take the output artifact, so the project has none of its own.
  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_SMALL"
    image                       = "aws/codebuild/standard:7.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }

  # Logs go to CodeBuild's default group, /aws/codebuild/PartnerPortalReact (the group resource below).
  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  # GitHub through the shared CodeConnections connection; buildspec.yml is read from the repo root.
  source {
    type                = "GITHUB"
    location            = "https://github.com/Prestige-Inhome-Care/partner-portal"
    git_clone_depth     = 1
    report_build_status = false

    auth {
      type     = "CODECONNECTIONS"
      resource = "arn:aws:codeconnections:ap-southeast-2:421089614203:connection/977bfeb1-6c7b-470c-ab55-b70939019ef1"
    }

    git_submodules_config {
      fetch_submodules = false
    }
  }

  # Used by the Production pipeline too: Terraform must never delete it.
  lifecycle {
    prevent_destroy = true
  }
}

# CodeBuild's default log group for the project. Retention is as it was (kept forever); the recruitment portal's
# equivalent was changed to 30 days, which is a separate decision for this one.
resource "aws_cloudwatch_log_group" "build" {
  name              = "/aws/codebuild/PartnerPortalReact"
  retention_in_days = 0

  lifecycle {
    prevent_destroy = true
  }
}
