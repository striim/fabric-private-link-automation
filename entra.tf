data "azuread_client_config" "current" {}

resource "azuread_application" "spn" {
  display_name = var.app_registration_name
  owners       = [data.azuread_client_config.current.object_id]
}

resource "azuread_service_principal" "spn" {
  client_id = azuread_application.spn.client_id
  owners    = [data.azuread_client_config.current.object_id]
}

resource "time_offset" "spn_secret_expiry" {
  offset_days = var.client_secret_rotation_days
}

resource "azuread_application_password" "spn" {
  application_id = azuread_application.spn.id
  display_name   = "striim-fabric"
  end_date       = time_offset.spn_secret_expiry.rfc3339
}
