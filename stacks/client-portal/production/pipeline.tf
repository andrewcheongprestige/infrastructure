module "client_portal_pipeline" {
  source = "../../../modules/client-portal-pipeline"

  name              = "ClientPortal-PROD"
  github_repository = "Prestige-Inhome-Care/client-portal"
  branch            = "production"

  # A GitHub release (a tag such as production-2026.11.06-1) starts a deploy, not a push to the branch.
  tag_patterns = ["production-*"]

  # Existing connection to GitHub, shared with the other portals' pipelines.
  connection_arn = "arn:aws:codeconnections:ap-southeast-2:421089614203:connection/977bfeb1-6c7b-470c-ab55-b70939019ef1"

  # Match the recruitment portal's pipeline: run every push in order, and retry a failed GitHub fetch.
  execution_mode          = "QUEUED"
  retry_source_on_failure = true

  eb_application_name = module.client_portal.eb_application_name
  eb_environment_name = module.client_portal.eb_environment_name
  eb_environment_id   = module.client_portal.eb_environment_id
}
