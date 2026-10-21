# The CodeConnections policy that lets a pipeline use the shared GitHub connection. It is named for the Production
# pipeline (AdminHubReact-PROD), but it is also attached to the UAT pipeline's role (two attachments), so it is
# owned here once. Each pipeline's stack manages only its own attachment, by this policy's ARN.
resource "aws_iam_policy" "connection" {
  name        = "CodePipeline-CodeConnections-ap-southeast-2-AdminHubReact-PROD"
  path        = "/service-role/"
  description = "Policy used in trust relationship with CodePipeline for CodeConnections Action"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["codeconnections:UseConnection", "codestar-connections:UseConnection"]
      Resource = ["arn:aws:codestar-connections:*:421089614203:connection/977bfeb1-6c7b-470c-ab55-b70939019ef1", "arn:aws:codeconnections:*:421089614203:connection/977bfeb1-6c7b-470c-ab55-b70939019ef1"]
    }]
  })

  lifecycle {
    prevent_destroy = true
  }
}
