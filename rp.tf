# Microsoft.Fabric resource provider registration — idempotent.
#
# Replaces the previous `azurerm_resource_provider_registration` resource,
# which fails with "A resource with the ID ... already exists" on
# subscriptions where Microsoft.Fabric was registered out-of-band (any
# subscription that has previously used Fabric). The Azure CLI's
# `az provider register` is idempotent on the service side, so we just
# check the current state and call register only when not already
# registered. No work is performed on destroy — leaving the RP registered
# is the safe default because other resources in the subscription may
# depend on it.
resource "null_resource" "fabric_rp_registration" {
  triggers = {
    subscription_id = var.subscription_id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      state=$(az provider show --namespace Microsoft.Fabric --subscription "${var.subscription_id}" --query 'registrationState' -o tsv 2>/dev/null || echo "NotRegistered")
      if [ "$state" = "Registered" ]; then
        echo "Microsoft.Fabric resource provider is already registered on subscription ${var.subscription_id}. Skipping."
      else
        echo "Microsoft.Fabric current state: $state. Registering..."
        az provider register --namespace Microsoft.Fabric --subscription "${var.subscription_id}" --wait
        echo "Microsoft.Fabric resource provider registered."
      fi
    EOT
  }
}
