output "pipeline_name" {
  value = aws_codepipeline.this.name
}

output "codebuild_project_name" {
  value = aws_codebuild_project.this.name
}

output "artifact_bucket" {
  value = aws_s3_bucket.artifacts.bucket
}
