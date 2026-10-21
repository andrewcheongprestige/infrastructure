# The two CodeBuild projects that build the PX2 workers. The PX2-UAT pipeline runs both in parallel, and they are shared
# with the Production side, so a change here affects Production builds too. Each project builds its own buildspec.yml
# (under PlatformX/PX2/ in the prestige repo), which bakes the app's configuration into appsettings.Production.json.
# Imported from the console-made projects as they were.
#
# NOTE: both projects are pointed at a personal GitHub repository (matthewcosier/prestige, branch feature/px2), not the
# company's Prestige-Inhome-Care/prestige. The pipelines supply their own source, so this does not affect pipeline
# builds, but a build started on the project itself would use that repository. Recorded as it is; to be decided.

resource "aws_codebuild_project" "consumer" {
  name               = "PX2-Consumer"
  project_visibility = "PRIVATE"
  queued_timeout     = 480
  build_timeout      = 60

  # The branch the project builds when it is started on its own, outside a pipeline.
  source_version = "feature/px2"

  # The existing console-made role shared by the PX projects, kept by ARN. Importing it is a later, separate step.
  service_role   = "arn:aws:iam::421089614203:role/service-role/PXMaster"
  encryption_key = "arn:aws:kms:ap-southeast-2:421089614203:alias/aws/s3"

  # The pipeline supplies the source and takes the output artifact, so the project has none of its own.
  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }

  # Logs go to CodeBuild's default group, /aws/codebuild/PX2-Consumer (the group resource below).
  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/matthewcosier/prestige.git"
    buildspec           = "PlatformX/PX2/PX2.PrestigeDataExchange.Consumer/buildspec.yml"
    git_clone_depth     = 1
    report_build_status = false

    git_submodules_config {
      fetch_submodules = false
    }
  }

  # Used by the Production side too: Terraform must never delete it.
  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_codebuild_project" "isolator" {
  name               = "PX2-Isolator"
  project_visibility = "PRIVATE"
  queued_timeout     = 480
  build_timeout      = 60

  # The branch the project builds when it is started on its own, outside a pipeline.
  source_version = "feature/px2"

  # The existing console-made role shared by the PX projects, kept by ARN. Importing it is a later, separate step.
  service_role   = "arn:aws:iam::421089614203:role/service-role/PXMaster"
  encryption_key = "arn:aws:kms:ap-southeast-2:421089614203:alias/aws/s3"

  # The pipeline supplies the source and takes the output artifact, so the project has none of its own.
  artifacts {
    type = "NO_ARTIFACTS"
  }

  cache {
    type = "NO_CACHE"
  }

  environment {
    type                        = "LINUX_CONTAINER"
    compute_type                = "BUILD_GENERAL1_MEDIUM"
    image                       = "aws/codebuild/amazonlinux-x86_64-standard:5.0"
    image_pull_credentials_type = "CODEBUILD"
    privileged_mode             = false
  }

  # Logs go to CodeBuild's default group, /aws/codebuild/PX2-Isolator (the group resource below).
  logs_config {
    cloudwatch_logs {
      status = "ENABLED"
    }
  }

  source {
    type                = "GITHUB"
    location            = "https://github.com/matthewcosier/prestige.git"
    buildspec           = "PlatformX/PX2/PX2.PrestigeDataExchange.Isolator/buildspec.yml"
    git_clone_depth     = 1
    report_build_status = false

    git_submodules_config {
      fetch_submodules = false
    }
  }

  # Used by the Production side too: Terraform must never delete it.
  lifecycle {
    prevent_destroy = true
  }
}

# CodeBuild's default log groups for the projects. Retention is as it was (kept forever); changing it is a separate
# decision.
resource "aws_cloudwatch_log_group" "consumer" {
  name              = "/aws/codebuild/PX2-Consumer"
  retention_in_days = 0

  lifecycle {
    prevent_destroy = true
  }
}

resource "aws_cloudwatch_log_group" "isolator" {
  name              = "/aws/codebuild/PX2-Isolator"
  retention_in_days = 0

  lifecycle {
    prevent_destroy = true
  }
}
