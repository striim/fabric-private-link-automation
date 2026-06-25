# Approve the inbound private endpoint connection from the Striim control plane
# to the Fabric Private Link Service. Uses az rest directly because
# `az network private-endpoint-connection approve` does not consistently
# support Microsoft.Fabric/privateLinkServicesForFabric in current CLI builds.
#
# Verified ARM shape for Microsoft.Fabric/privateLinkServicesForFabric:
#   - GET the PLS itself returns connections inline at
#     .properties.privateEndpointConnections[] (no separate collection endpoint).
#   - Approve via PUT on the connection resource with the new state in the
#     body — there is no /approve action sub-resource.
resource "null_resource" "approve_fabric_pe" {
  count = var.auto_approve_pe_connections ? 1 : 0

  triggers = {
    fabric_pls_id = azapi_resource.fabric_pls.id
  }

  provisioner "local-exec" {
    interpreter = ["bash", "-c"]
    command     = <<-EOT
      set -e
      pls_id="${azapi_resource.fabric_pls.id}"
      delay=5
      total=0
      max=600

      while [[ $${total} -lt $${max} ]]; do
        # Microsoft.Fabric/privateLinkServicesForFabric exposes connections
        # inline at .properties.privateEndpointConnections, not at a
        # /privateEndpointConnections collection sub-resource.
        list_json=$(az rest --method GET \
          --url "https://management.azure.com$${pls_id}?api-version=2024-06-01" \
          2>/dev/null || echo '{"properties":{"privateEndpointConnections":[]}}')

        pending_ids=$(echo "$${list_json}" | jq -r '.properties.privateEndpointConnections[]? | select(.properties.privateLinkServiceConnectionState.status=="Pending") | .id')

        if [[ -n "$${pending_ids}" ]]; then
          for conn_id in $${pending_ids}; do
            echo "Approving Fabric PE connection: $${conn_id}"
            az rest --method PUT \
              --url "https://management.azure.com$${conn_id}?api-version=2024-06-01" \
              --body '{"properties":{"privateLinkServiceConnectionState":{"status":"Approved","description":"Approved by Striim Terraform module"}}}'
          done
          exit 0
        fi

        echo "No pending Fabric PE yet — waiting $${delay}s (elapsed $${total}s of $${max}s)"
        sleep $${delay}
        total=$((total + delay))
        delay=$((delay * 2))
        if [[ $${delay} -gt 60 ]]; then delay=60; fi
      done

      echo "ERROR: Timed out after $${max}s waiting for a pending Fabric PE connection."
      echo "Verify Striim has initiated the private endpoint against $${pls_id}."
      exit 1
    EOT
  }

  depends_on = [
    azapi_resource.fabric_pls,
    fabric_workspace_role_assignment.workspace_identity_contributor,
  ]
}
