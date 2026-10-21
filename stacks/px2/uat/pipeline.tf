# The existing PX2 UAT pipeline, imported as it is. This is a faithful record of what runs today, not a redesign: do not
# "improve" it here without a plan that shows what changes.
#
# One pipeline serves both workers. Source: GitHub repo prestige, branch uat, through the shared CodeConnections
# connection. Build: two CodeBuild projects in parallel (PX2-Isolator and PX2-Consumer, shared with Production).
# Deploy: both Elastic Beanstalk worker environments, in parallel. There is no automatic rollback on a failed Deploy.
resource "aws_codepipeline" "uat" {
  name           = "PX2-UAT"
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
        FullRepositoryId     = "Prestige-Inhome-Care/prestige"
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
      name             = "BuildIsolator"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      namespace        = "BuildVariables"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["IsolatorBuildArtifact"]

      configuration = {
        ProjectName = "PX2-Isolator"
      }
    }

    action {
      name             = "BuildConsumer"
      category         = "Build"
      owner            = "AWS"
      provider         = "CodeBuild"
      version          = "1"
      input_artifacts  = ["SourceArtifact"]
      output_artifacts = ["ConsumerBuildArtifact"]

      configuration = {
        ProjectName = "PX2-Consumer"
      }
    }
  }

  stage {
    name = "Deploy"

    action {
      name            = "DeployIsolator"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      version         = "1"
      input_artifacts = ["IsolatorBuildArtifact"]

      configuration = {
        ApplicationName = "paf-px2-isolator-dotnetapp"
        EnvironmentName = "paf-px2-isolator-dotnetapp-uat"
      }
    }

    action {
      name            = "DeployConsumer"
      category        = "Deploy"
      owner           = "AWS"
      provider        = "ElasticBeanstalk"
      version         = "1"
      input_artifacts = ["ConsumerBuildArtifact"]

      configuration = {
        ApplicationName = "paf-px2-consumer-dotnetapp"
        EnvironmentName = "paf-px2-consumer-dotnetapp-uat"
      }
    }
  }
}
