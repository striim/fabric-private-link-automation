# Approve the inbound private endpoint connection from the Striim control plane
# to the storage account. Striim creates the PE out-of-band against the storage
# account's resource ID; this null_resource polls with exponential backoff for
# up to 10 minutes, then approves any Pending connections it finds.
#
# Idempotency: only re-runs when storage_account_id changes. A reapply after
# the connection is already Approved will not re-execute the provisioner.
resource "null_resource" "approve_storage_pe" {
  count = var.auto_approve_pe_connections ? 1 : 0

  triggers = {
    storage_account_id = azurerm_storage_account.this.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      storage_id="${azurerm_storage_account.this.id}"
      delay=5
      total=0
      max=600

      while [[ $${total} -lt $${max} ]]; do
        pending=$(az network private-endpoint-connection list \
          --id "$${storage_id}" \
          --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id" \
          -o tsv 2>/dev/null || true)

        if [[ -n "$${pending}" ]]; then
          for conn_id in $${pending}; do
            echo "Approving storage PE connection: $${conn_id}"
            az network private-endpoint-connection approve \
              --id "$${conn_id}" \
              --description "Approved by Striim Terraform module"
          done
          exit 0
        fi

        echo "No pending storage PE yet — waiting $${delay}s (elapsed $${total}s of $${max}s)"
        sleep $${delay}
        total=$((total + delay))
        delay=$((delay * 2))
        if [[ $${delay} -gt 60 ]]; then delay=60; fi
      done

      echo "ERROR: Timed out after $${max}s waiting for a pending storage PE connection."
      echo "Verify Striim has initiated the private endpoint against $${storage_id}."
      exit 1
    EOT
  }

  depends_on = [
    azurerm_storage_account.this,
    azapi_update_resource.storage_acls_and_public_access,
  ]
}
