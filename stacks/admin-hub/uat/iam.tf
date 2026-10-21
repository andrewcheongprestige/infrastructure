# The pipeline's role and its two customer-managed policies, imported as they are. The third policy attached to the
# role (CodeConnections, named for the PROD pipeline) is owned by stacks/admin-hub/shared; only its attachment is
# managed here.
#
# Unlike the recruitment and partner portals' roles, this service policy was written by hand and is narrower: it
# limits CloudFormation access to three named Elastic Beanstalk stacks (this environment's is awseb-e-mv3pthuawx-stack;
# the other two are not this stack's). Like theirs it has no read access to AWS's regional bucket
# (elasticbeanstalk-ap-southeast-2), so a deploy that changes the environment's configuration may be refused with
# "S3 error: Access Denied". Plain version swaps work. It is kept faithful here on purpose: narrowing or widening it
# is a separate, planned change.

resource "aws_iam_role" "pipeline" {
  name                 = "AWSCodePipelineServiceRole-ap-southeast-2-AdminHubReact-UAT"
  path                 = "/service-role/"
  max_session_duration = 3600

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "CodePipelineTrustPolicy"
      Effect = "Allow"
      Action = "sts:AssumeRole"
      Principal = {
        Service = "codepipeline.amazonaws.com"
      }
      Condition = {
        StringEquals = {
          "aws:SourceAccount" = "421089614203"
        }
      }
    }]
  })
}

resource "aws_iam_policy" "pipeline_service" {
  name        = "AWSCodePipelineServiceRole-ap-southeast-2-AdminHubReact-UAT"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodePipeline for service role"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid      = "AllowS3BucketAccess"
        Effect   = "Allow"
        Action   = ["s3:GetBucketVersioning", "s3:GetBucketAcl", "s3:GetBucketLocation"]
        Resource = ["arn:aws:s3:::codepipeline-ap-southeast-2-2428601742"]
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = "421089614203"
          }
        }
      },
      {
        Sid      = "AllowS3ObjectAccess"
        Effect   = "Allow"
        Action   = ["s3:PutObject", "s3:PutObjectAcl", "s3:GetObject", "s3:GetObjectVersion"]
        Resource = ["arn:aws:s3:::codepipeline-ap-southeast-2-2428601742/*"]
        Condition = {
          StringEquals = {
            "aws:ResourceAccount" = "421089614203"
          }
        }
      },
      {
        Sid      = "AllowCodeBuildAccess"
        Effect   = "Allow"
        Action   = ["codebuild:StartBuild", "codebuild:BatchGetBuilds"]
        Resource = "arn:aws:codebuild:ap-southeast-2:421089614203:project/AdminHubReact"
      },
      {
        Sid      = "AllowElasticBeanstalkDeployment"
        Effect   = "Allow"
        Action   = ["elasticbeanstalk:CreateApplicationVersion", "elasticbeanstalk:DescribeApplicationVersions", "elasticbeanstalk:UpdateEnvironment"]
        Resource = "*"
      },
      {
        Sid      = "AllowElasticBeanstalkS3BucketManagement"
        Effect   = "Allow"
        Action   = ["s3:CreateBucket", "s3:PutBucketPolicy", "s3:PutBucketAcl", "s3:GetBucketLocation", "s3:PutObject", "s3:PutObjectAcl", "s3:GetObject", "s3:GetObjectVersion", "s3:DeleteObject", "s3:ListBucket", "s3:GetObjectAcl", "s3:GetBucketPolicy"]
        Resource = ["arn:aws:s3:::elasticbeanstalk-ap-southeast-2-421089614203", "arn:aws:s3:::elasticbeanstalk-ap-southeast-2-421089614203/*"]
      },
      {
        Sid      = "AllowElasticBeanstalkDescribe"
        Effect   = "Allow"
        Action   = ["elasticbeanstalk:DescribeEnvironments"]
        Resource = "*"
      },
      {
        Sid      = "AllowCloudFormationGetTemplate"
        Effect   = "Allow"
        Action   = ["cloudformation:GetTemplate", "cloudformation:DescribeStackResource", "cloudformation:DescribeStackResources", "cloudformation:UpdateStack", "cloudformation:DescribeStacks", "cloudformation:ValidateTemplate", "cloudformation:GetTemplateSummary"]
        Resource = ["arn:aws:cloudformation:ap-southeast-2:421089614203:stack/awseb-e-vgqjm6bi2p-stack/*", "arn:aws:cloudformation:ap-southeast-2:421089614203:stack/awseb-e-w3svz5jsct-stack/*", "arn:aws:cloudformation:ap-southeast-2:421089614203:stack/awseb-e-mv3pthuawx-stack/*"]
      },
      {
        Effect   = "Allow"
        Action   = ["autoscaling:SuspendProcesses", "autoscaling:ResumeProcesses", "autoscaling:DescribeAutoScalingGroups"]
        Resource = "*"
      },
      {
        Sid      = "AllowElasticBeanstalkPolling"
        Effect   = "Allow"
        Action   = ["elasticbeanstalk:DescribeEvents", "elasticbeanstalk:DescribeEnvironmentHealth"]
        Resource = "*"
      },
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetObjectAcl"]
        Resource = ["arn:aws:s3:::codepipeline-ap-southeast-2-2428601742/*"]
      },
      {
        Effect   = "Allow"
        Action   = "s3:ListBucket"
        Resource = "arn:aws:s3:::codepipeline-ap-southeast-2-2428601742"
      },
      {
        Sid      = "AllowElasticBeanstalkEnvResourcesAccess"
        Effect   = "Allow"
        Action   = ["s3:GetObject", "s3:GetObjectVersion", "s3:GetBucketLocation"]
        Resource = ["arn:aws:s3:::elasticbeanstalk-env-resources-ap-southeast-2", "arn:aws:s3:::elasticbeanstalk-env-resources-ap-southeast-2/*"]
      },
      {
        Sid      = "AllowEC2DescribeKeyPairs"
        Effect   = "Allow"
        Action   = ["ec2:DescribeKeyPairs", "ec2:DescribeImages"]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_policy" "codebuild" {
  name        = "CodePipeline-CodeBuild-ap-southeast-2-AdminHubReact-UAT"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodePipeline for CodeBuild Action"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["codebuild:BatchGetBuilds", "codebuild:StartBuild", "codebuild:BatchGetBuildBatches", "codebuild:StartBuildBatch"]
      Resource = ["arn:aws:codebuild:*:421089614203:project/AdminHubReact"]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "pipeline_service" {
  role       = aws_iam_role.pipeline.name
  policy_arn = aws_iam_policy.pipeline_service.arn
}

resource "aws_iam_role_policy_attachment" "codebuild" {
  role       = aws_iam_role.pipeline.name
  policy_arn = aws_iam_policy.codebuild.arn
}

# The policy is owned by stacks/admin-hub/shared (it is also attached to the Production pipeline's role), so it is
# referred to here by its ARN.
resource "aws_iam_role_policy_attachment" "connection" {
  role       = aws_iam_role.pipeline.name
  policy_arn = "arn:aws:iam::421089614203:policy/service-role/CodePipeline-CodeConnections-ap-southeast-2-AdminHubReact-PROD"
}
