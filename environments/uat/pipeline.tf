module "client_portal_pipeline" {
  source = "../../modules/client-portal-pipeline"

  name              = "ClientPortal-UAT"
  github_repository = "Prestige-Inhome-Care/client-portal"
  branch            = "uat"

  # Existing connection to GitHub, shared with the other portals' pipelines.
  connection_arn = "arn:aws:codeconnections:ap-southeast-2:421089614203:connection/977bfeb1-6c7b-470c-ab55-b70939019ef1"

  eb_application_name = module.client_portal.eb_application_name
  eb_environment_name = module.client_portal.eb_environment_name
}
