# The existing Recruitment Portal UAT pipeline, imported as it is. This is a faithful record
# of what runs today, not a redesign: do not "improve" it here without a plan that shows what changes.
#
# Source: GitHub branch uat, through the shared CodeConnections connection.
# Build:  the shared CodeBuild project RecruitmentPortalReact (also used by the Production pipeline).
# Deploy: Elastic Beanstalk environment paf-recruitmentportal-reactapp-uat.
resource "aws_codepipeline" "uat" {
  name           = "RecruitmentPortal-UAT"
  pipeline_type  = "V2"
  execution_mode = "QUEUED"
  role_arn       = aws_iam_role.pipeline.arn

  # The shared artifact bucket, created by the console wizard and used by other pipelines too.
  artifact_store {
    location = "codepipeline-ap-southeast-2-2428601742"
    type     = "S3"
  }

  stage {
    name = "Source"

    action {
      name             = "Source"
      category         = "Source"
      owner            = "AWS"
      provider         = "CodeStarSourceConnection"
      version          = "1"
      namespace        = "SourceVariables"
      output_artifacts = ["SourceArtifact"]

      configuration = {
        BranchName           = "uat"
        ConnectionArn        = "arn:aws:codeconnections:ap-southeast-2:421089614203:connection/977bfeb1-6c7b-470c-ab55-b70939019ef1"
        DetectChanges        = "true"
        FullRepositoryId     = "Prestige-Inhome-Care/recruitment-portal"
        OutputArtifactFormat = "CODE_ZIP"
      }
    }

    on_failure {
      result = "RETRY"

      retry_configuration {
        retry_mode = "ALL_ACTIONS"
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
      namespace        = "BuildVariables"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["recruitmentportalreact"]

      configuration = {
        EnvironmentVariables = "[{\"name\":\"BUILD_ENV\",\"value\":\"UAT\",\"type\":\"PLAINTEXT\"},{\"name\":\"APP_ENV_NAME\",\"value\":\"paf-recruitmentportal-react-uat\",\"type\":\"PLAINTEXT\"}]"
        ProjectName          = "RecruitmentPortalReact"
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
      namespace       = "DeployVariables"
      input_artifacts = ["recruitmentportalreact"]

      configuration = {
        ApplicationName = "paf-recruitmentportal-reactapp"
        EnvironmentName = "paf-recruitmentportal-reactapp-uat"
      }
    }

    on_failure {
      result = "ROLLBACK"
    }
  }
}
