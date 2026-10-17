# The CodeBuild project that BOTH Recruitment Portal pipelines (RecruitmentPortal-UAT and
# RecruitmentPortal-PROD) use. That is why it lives in this "shared" stack and not in either environment's:
# a change here affects Production builds as well as UAT ones. Each pipeline passes its own BUILD_ENV, and the
# repo's buildspec.yml does the build. Imported from the console-made project (see imports.tf), then adjusted.
resource "aws_codebuild_project" "build" {
  name               = "RecruitmentPortalReact"
  project_visibility = "PRIVATE"
  queued_timeout     = 480

  # Was 60. Builds finish well inside this, and a hung build now fails sooner (decided 2026-10-17).
  build_timeout = 20

  # The existing console-made role, kept by ARN. Importing the role is a later, separate step.
  service_role   = "arn:aws:iam::421089614203:role/service-role/codebuild-RecruitmentPortalReact-service-role"
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

  # Logs go to the group below. It is the same group the project used before (CodeBuild's default name), now
  # named explicitly so it is part of this definition.
  logs_config {
    cloudwatch_logs {
      status     = "ENABLED"
      group_name = aws_cloudwatch_log_group.build.name
    }
  }

  # GitHub through the shared CodeConnections connection; buildspec.yml is read from the repo root.
  source {
    type                = "GITHUB"
    location            = "https://github.com/Prestige-Inhome-Care/recruitment-portal"
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

resource "aws_cloudwatch_log_group" "build" {
  name = "/aws/codebuild/RecruitmentPortalReact"

  # Was 0 (kept forever). Changed to 30 days on 2026-10-17; this deletes older build log events.
  retention_in_days = 30

  lifecycle {
    prevent_destroy = true
  }
}
