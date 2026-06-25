# Striim Fabric Private Link — Customer Setup Guide

End-to-end guide for setting up a private-link path from Striim Cloud to your
Microsoft Fabric Warehouse, so streaming data flows over Microsoft's private
backbone and never traverses the public internet.

## What you'll end up with

```
        Striim Cloud (Striim's network)
              │
              │  Private link (Microsoft backbone — no public internet)
              ▼
       Microsoft.Fabric/privateLinkServicesForFabric ◄── created by this module
              │
              ▼
       Fabric Workspace (your Azure tenant) ◄── created by this module
              │
              ▼
       Fabric Warehouse (reachable via private SQL endpoint)
              │
              │  COPY INTO via Trusted Workspace Access
              ▼
       ADLS Gen2 Storage Account (your Azure tenant) ◄── created by this module
       (public access disabled — only the workspace can reach it)
```

---

## Prerequisites

| Requirement | Why |
|---|---|
| Azure CLI installed and `az login` to your tenant | Terraform and approval commands use the CLI's credentials |
| Terraform 1.6+ | Module pins `required_version = ">= 1.6.0"` |
| `jq` installed | Approval verification commands parse JSON |
| `Owner` or `Contributor` rights on the target Azure subscription | Needed to create resources and approve PE connections |
| A Microsoft.Fabric/capacities resource (F2 or higher) already provisioned, and Fabric capacity admin rights on it | Workspaces must attach to a capacity |
| **Striim Cloud service on version 5.4.0 or later** | Fabric Data Warehouse private-link DNS auto-wiring shipped in 5.4.0; earlier versions (e.g. 5.2.0.6) auto-wire storage PEs but not the `datawarehouse` subdomain, and the connection profile will fail with `Name or service not known`. Check version at the top of the service detail page in Striim Cloud UI. |
| **Fabric tenant admin has enabled "Configure workspace-level inbound network rules"** | Required for the workspace public-access toggle. A Fabric admin must enable this once at app.fabric.microsoft.com → Admin portal → Tenant settings → search "Configure workspace-level inbound network rules" → Enabled. Without it, the module's call to disable workspace public network access returns 403 `InboundRestrictionNotEligible` and `terraform apply` fails. See [Microsoft's setup doc § Prerequisites](https://learn.microsoft.com/en-us/fabric/security/security-workspace-level-private-links-set-up#prerequisites). |
| Tenant ID, subscription ID, region | Inputs |

---

## Phase 0 — Bootstrap path

This guide covers the **bootstrap** path: you have a Fabric capacity but no
workspace or warehouse yet, and the module creates everything (workspace,
warehouse, storage, SPN, and Private Link Service).

All commands below run inside `scenarios/bootstrap/`.

---

## Phase 1 — Provision Azure resources

### 1.1 Fill in your values

All customer-specific values live in **`terraform.tfvars`** — you don't need to
touch `main.tf`.

```bash
cd scenarios/bootstrap
```

Open `terraform.tfvars` in your editor and set all 10 values.
`terraform.tfvars.example` in the same folder has the same keys with
placeholder values and inline rules — use it as a reference if you prefer.

**Required values (7):**

| Variable | Description |
|---|---|
| `subscription_id` | Your Azure subscription GUID |
| `tenant_id` | Your Microsoft Entra tenant GUID (must match the Fabric tenant) |
| `resource_group_name` | Name for the new resource group the module will create (must not already exist) |
| `location` | Azure region — must match the region of your Fabric capacity |
| `storage_account_name` | Globally unique, 3-24 lowercase alphanumeric |
| `app_registration_name` | Display name for the new Entra ID app registration (SPN) |
| `pls_resource_name` | Name for the `Microsoft.Fabric/privateLinkServicesForFabric` resource |

**Additional values (3):**

| Variable | Description |
|---|---|
| `fabric_capacity_id` | Fabric capacity GUID — NOT the Azure ARM resource ID. See §1.2 to find it |
| `fabric_workspace_name` | Display name for the new Fabric workspace |
| `fabric_warehouse_name` | Display name for the new warehouse |

`terraform.tfvars` is gitignored — your values stay local.

### 1.2 Finding your Fabric capacity GUID

The module wants the **Fabric capacity GUID**, NOT the Azure ARM resource ID.
Get it with:

```bash
az rest --method GET \
  --url "https://api.fabric.microsoft.com/v1/capacities" \
  --resource "https://api.fabric.microsoft.com" \
  | jq '.value[] | {name: .displayName, id: .id, region: .region, sku: .sku, state: .state}'
```

Copy the `id` of the capacity you want to attach to into `fabric_capacity_id`
in `terraform.tfvars`.

### 1.3 Initialize and apply

```bash
terraform init
terraform plan    # review the resource list before applying
terraform apply
```

Type `yes` when prompted. Apply takes 3-8 minutes.

The Microsoft.Fabric resource provider registration is idempotent — the
module checks the current state via Azure CLI and only registers it if not
already registered. Subscriptions that have previously used Fabric will see
a "Skipping" message in the apply output, not an error.

### 1.4 Capture outputs

After a successful apply:

```bash
terraform output
```

Note these output values — you'll paste them into Striim UI in Phase 2:

| Output | Used for |
|---|---|
| `fabric_pls_id` | Service Alias when creating the Fabric Private Endpoint in Striim UI |
| `storage_account_id` | Service Alias when creating the Storage Private Endpoint in Striim UI |
| `spn_application_id` | Client ID in Striim's Fabric connection profile |
| `spn_client_secret` | Client Secret in Striim's Fabric connection profile (`terraform output -raw spn_client_secret`) |
| `fabric_private_sql_endpoint` | SQL Connection String in Striim's Fabric connection profile (after Phase 3) |
| `storage_account_name` | Azure Account Name in Striim's ADLS Gen2 connection profile |

---

## Phase 2 — Create Private Endpoints in Striim Cloud UI

Two private endpoints to create — one to your Fabric workspace, one to your
storage account.

In Striim Cloud, navigate to your service → **Secure Connection** → **Private
Endpoints** → **Create Private Endpoint**.

### 2.1 Fabric PE

| Field | Value |
|---|---|
| Name | any short name, e.g. `fabricwh` |
| Service Alias | paste the `fabric_pls_id` output from Phase 1 |
| Target Type | No Selection |
| Sub-resource | `workspace` (lowercase) |

Submit. The PE will show status **Pending**.

### 2.2 Storage PE

Click **Create Private Endpoint** again.

| Field | Value |
|---|---|
| Name | any short name, e.g. `fabricstorage` |
| Service Alias | paste the `storage_account_id` output from Phase 1 |
| Target Type | No Selection |
| Sub-resource | `blob` (lowercase — IMPORTANT, must be exactly `blob`) |

Submit. The PE will show status **Pending**.

---

## Phase 3 — Approve the Pending Private Endpoints

Striim Cloud has now initiated two inbound private endpoint connections — one
against your Fabric PLS, one against your storage account. They sit in `Pending`
state until you approve them on your side.

### 3.1 Approve the Storage PE

```bash
storage_id=$(terraform output -raw storage_account_id)

for conn_id in $(az network private-endpoint-connection list \
  --id "$storage_id" \
  --query "[?properties.privateLinkServiceConnectionState.status=='Pending'].id" \
  -o tsv); do
  az network private-endpoint-connection approve \
    --id "$conn_id" \
    --description "Approved by Striim Terraform module"
done
```

### 3.2 Approve the Fabric PE

The Fabric PLS uses a different API surface than standard Azure resources, so
the approval command is `az rest` instead of `az network`:

```bash
pls_id=$(terraform output -raw fabric_pls_id)

for conn_id in $(az rest --method GET \
  --url "https://management.azure.com${pls_id}?api-version=2024-06-01" \
  | jq -r '.properties.privateEndpointConnections[]? | select(.properties.privateLinkServiceConnectionState.status=="Pending") | .id'); do
  az rest --method PUT \
    --url "https://management.azure.com${conn_id}?api-version=2024-06-01" \
    --body '{"properties":{"privateLinkServiceConnectionState":{"status":"Approved","description":"Approved by Striim Terraform module"}}}'
done
```

> **UI alternative:** if you prefer the portal, the Fabric PLS approval lives in
> the Fabric admin portal (not the Azure portal): `app.fabric.microsoft.com → search "private link" → Pending connections`.
> The CLI flow above is the recommended path.

### 3.3 Verify

Refresh **Striim UI → Secure Connection → Private Endpoints**. Both PEs should
flip from `Pending` to `Running` within 1-2 minutes.

Also verify in Azure portal:
- **Storage account → Networking → Private endpoints**: status `Approved`
- **Fabric PLS resource → JSON View**: `privateEndpointConnections[*].privateLinkServiceConnectionState.status` = `Approved`

---

## Phase 4 — Configure your Striim app to use the private endpoint

After both PEs are Approved, paste the captured outputs into Striim Cloud:

1. **Fabric Warehouse connection profile**:
   - Client ID = `spn_application_id`
   - Client Secret = `terraform output -raw spn_client_secret`
   - SQL Connection String = `fabric_private_sql_endpoint` (this is the
     private-endpoint-derived hostname; **don't** use the public endpoint here)
2. **ADLS Gen2 connection profile** (if your Striim app uses staging):
   - Azure Account Name = `storage_account_name`

Your Striim representative will guide you through:
- Creating the Fabric Warehouse Writer target
- Enabling the **Trusted Workspace Access** flag in the target configuration
- Test connection → should return Success
- Running the app and confirming traffic flows over the private link

---

## Phase 5 — Lock down the Fabric workspace to private access only

At this point the ADLS storage account is already public-access disabled by the
Terraform module (see [storage-acls.tf](storage-acls.tf)) — only the Fabric
workspace data path can read staging files through the trusted-workspace rule.
This final phase brings the **Fabric workspace itself** to the same posture:
no public internet access; the only allowed inbound path is the workspace-level
private link Striim is using.

After this phase, **both** the storage account and the Fabric workspace are
private-only.

### 5.1 Enable the tenant-level setting (one-time, Fabric admin)

This step is gated by the prerequisite listed in [Prerequisites](#prerequisites).
A Microsoft Entra user with the **Fabric Administrator** role must turn on the
tenant-wide unlock once before any workspace in the tenant can restrict inbound
network access. Skip this section if your Fabric admin has already done it.

1. Sign in to https://app.fabric.microsoft.com as a Fabric administrator.
2. Top-right **gear icon** → **Admin portal**.
3. **Tenant settings** (left nav) → scroll to **Advanced networking**, or use
   the search box at the top with the term `Configure workspace-level inbound
   network rules`.
4. Expand the setting and toggle to **Enabled**. Leave the scope as "entire
   organization" unless you have a specific reason to restrict it to a security
   group.
5. Click **Apply**. Microsoft propagates the change tenant-wide within ~15 min.

### 5.2 Restrict the workspace to private link only

Pick whichever path is more convenient — both produce the same end state.

**Option A — Fabric portal (UI):**

1. Open your workspace in https://app.fabric.microsoft.com (e.g.
   `striim-fabric-bootstrap-ws`).
2. **Workspace settings** → **Inbound networking** (under **Advanced networking**).
3. Select **"Allow connections from selected networks and workspace level
   private links"**.
4. Click **Apply**.

**Option B — Azure CLI (API):**

```bash
ws_id=$(terraform output -raw fabric_workspace_id)

az rest --method PUT \
  --url "https://api.fabric.microsoft.com/v1/workspaces/${ws_id}/networking/communicationPolicy" \
  --resource "https://api.fabric.microsoft.com" \
  --body '{"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}'
```

Expected: HTTP 204 (empty body). This is the same API the Terraform module
calls automatically in bootstrap mode — running it manually here is only needed
if you deployed in *attach-to-existing* mode (`create_fabric_resources = false`)
or are re-applying the lockdown after a recovery.

### 5.3 Verify

```bash
ws_id=$(terraform output -raw fabric_workspace_id)

az rest --method GET \
  --url "https://api.fabric.microsoft.com/v1/workspaces/${ws_id}/networking/communicationPolicy" \
  --resource "https://api.fabric.microsoft.com"
```

Should echo back:

```json
{"inbound":{"publicAccessRules":{"defaultAction":"Deny"}}}
```

You can also visit the workspace in Fabric portal from your laptop's browser —
you should now see **"Access Restricted"**. That is the expected behavior: the
workspace can only be reached over the workspace-level private link. Striim
Cloud's Test Connection from Phase 4 should continue to succeed (it goes
through the private link, not public internet).

### 5.4 Recovery — re-enable public access if you need to

The `set-network-communication-policy` API is **not** gated by the workspace's
own inbound rules, so this command works from anywhere even if your laptop is
locked out of the Fabric portal:

```bash
ws_id=$(terraform output -raw fabric_workspace_id)

az rest --method PUT \
  --url "https://api.fabric.microsoft.com/v1/workspaces/${ws_id}/networking/communicationPolicy" \
  --resource "https://api.fabric.microsoft.com" \
  --body '{"inbound":{"publicAccessRules":{"defaultAction":"Allow"}}}'
```

Save this command somewhere safe before running 5.2 so you always have a way
back.

---

## Tearing it down

Order matters — do these in sequence or `terraform destroy` will fail
midway with a 409 Conflict on the Fabric Private Link Service ("Private
link service cannot be deleted: active private endpoint exists.").

### Step 1 — Re-enable workspace public access (if locked down in Phase 5)

If you previously restricted the Fabric workspace to private-link-only
access, **re-enable public access first** — otherwise the Fabric Terraform
provider can't refresh workspace state from your machine and `terraform
destroy` fails with `RequestDeniedByInboundPolicy`:

```bash
ws_id=$(terraform output -raw fabric_workspace_id)

az rest --method PUT \
  --url "https://api.fabric.microsoft.com/v1/workspaces/${ws_id}/networking/communicationPolicy" \
  --resource "https://api.fabric.microsoft.com" \
  --body '{"inbound":{"publicAccessRules":{"defaultAction":"Allow"}}}'
```

### Step 2 — Delete the Striim-side private endpoints

Azure refuses to delete a `Microsoft.Fabric/privateLinkServicesForFabric`
resource while any private endpoint is still attached to it. Remove the
Striim-side PEs *before* running `terraform destroy`:

1. Open **Striim Cloud → Manage Striim → Secure Connection → Private Endpoints**.
2. Click **Delete** on the Fabric PE (`fabricwh`).
3. Click **Delete** on the Storage PE (`fabricstorage`).

You can also delete the corresponding connection profiles under **Manage
Striim → Connection Profiles** at this point if you no longer need them
(not required for destroy to succeed).

### Step 3 — Run terraform destroy

```bash
terraform destroy
```

This removes all resources the module created. The Fabric workspace identity
will be deprovisioned automatically. The SPN client secret will be revoked.
Typical duration: 5-10 minutes (Fabric workspace deletion is the slowest
step).

Note: `terraform destroy` does NOT unregister the `Microsoft.Fabric` resource
provider, regardless of whether the module registered it during apply or it
was already registered out-of-band. This is intentional — other resources in
your subscription may rely on it.

### Step 4 — Post-destroy validation

Verify the teardown was complete:

```bash
# 1. Resource group should be gone
az group show --name <your-resource-group-name>
# expect: error "ResourceGroupNotFound"

# 2. Microsoft.Fabric should still be Registered (intentional)
az provider show --namespace Microsoft.Fabric \
  --subscription <your-subscription-id> \
  --query 'registrationState' -o tsv
# expect: Registered

# 3. Terraform state should be empty
terraform state list
# expect: no output (or only data sources, no managed resources)
```
