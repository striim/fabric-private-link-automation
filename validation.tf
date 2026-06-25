# Conditional input validation.
#
# Terraform variable `validation` blocks can only reference the variable being
# validated, so cross-variable rules (e.g. "X is required when Y is true") have
# to live on a resource. `terraform_data` is the no-op resource of choice — it
# never creates anything in any provider and is evaluated at plan time.
resource "terraform_data" "input_validation" {
  lifecycle {
    precondition {
      condition     = !var.create_fabric_resources || (var.fabric_capacity_id != "" && var.fabric_workspace_name != "")
      error_message = "When create_fabric_resources = true, both fabric_capacity_id and fabric_workspace_name must be provided."
    }

    precondition {
      condition     = var.create_fabric_resources || (var.fabric_workspace_id != "" && var.fabric_sql_endpoint != "")
      error_message = "When create_fabric_resources = false, both fabric_workspace_id and fabric_sql_endpoint must be provided (attach-to-existing mode)."
    }
  }
}
