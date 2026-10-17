resource "aws_codepipeline" "this" {
  name          = var.name
  role_arn      = aws_iam_role.pipeline.arn
  pipeline_type = "V2"

  execution_mode = var.execution_mode

  artifact_store {
    type     = "S3"
    location = aws_s3_bucket.artifacts.bucket
  }

  # A push to the branch starts a run.
  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      output_artifacts = ["source_output"]

      configuration = {
        ConnectionArn        = var.connection_arn
        FullRepositoryId     = var.github_repository
        BranchName           = var.branch
        OutputArtifactFormat = "CODE_ZIP"
        DetectChanges        = "true"
      }
    }

    dynamic "on_failure" {
      for_each = var.retry_source_on_failure ? [1] : []

      content {
        result = "RETRY"

        retry_configuration {
          retry_mode = "ALL_ACTIONS"
        }
      }
    }
  }

  stage {
    name = "Build"

    action {
      name             = "Build"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["source_output"]
      output_artifacts = ["build_output"]

      configuration = {
        ProjectName = aws_codebuild_project.this.name
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "Deploy"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      version         = "1"
      input_artifacts = ["build_output"]

      configuration = {
        ApplicationName = var.eb_application_name
        EnvironmentName = var.eb_environment_name
      }
    }
  }
}
