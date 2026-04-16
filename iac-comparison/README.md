# IaC Comparison: ARM vs Bicep vs Pulumi vs Terraform

Five implementations of the **exact same Azure infrastructure** using different
Infrastructure-as-Code tools - perfect for AZ-400 exam preparation.

Pulumi is shown in both Python and C# to demonstrate that general-purpose
languages give you a choice of runtime - great for .NET teams who want to stay
in familiar territory.

## What gets deployed

| Resource               | Details                            |
|------------------------|----------------------------: https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/automation/automation-runbook-gallery.md--------|
| Resource Group         | `rg-iac-<tool>-demo`              |
| Storage Account        | StorageV2, Standard_LRS, TLS 1.2  |
| App Service Plan       | Linux, B1 SKU                      |
| Web App (App Service)  | .NET 8, HTTPS-only                 |
| **Connection**         | Storage connection string injected as `StorageConnectionString` app setting |

## Directory structure

```
iac-comparison/
├── arm/
│   ├── azuredeploy.json              # ARM template (subscription-level)
│   ├── azuredeploy.parameters.json   # Parameter file
│   └── deploy.sh
├── bicep/
│   ├── main.bicep                    # Entry point (subscription scope)
│   ├── resources.bicep               # Module scoped to the resource group
│   └── deploy.sh
├── pulumi/
│   ├── __main__.py                   # Pulumi program (Python)
│   ├── Pulumi.yaml                   # Project metadata
│   ├── requirements.txt
│   └── deploy.sh
├── pulumi-csharp/
│   ├── Program.cs                    # Pulumi program (C#)
│   ├── Pulumi.yaml
│   ├── iac-pulumi-csharp-demo.csproj
│   └── deploy.sh
└── terraform/
    ├── main.tf                       # Terraform configuration
    └── deploy.sh
```

## How to deploy each one

> **Prerequisite:** `az login` (all tools authenticate via the Azure CLI).

### ARM

```bash
cd arm
az deployment sub create \
  --location westeurope \
  --template-file azuredeploy.json \
  --parameters @azuredeploy.parameters.json
```

### Bicep

```bash
cd bicep
az deployment sub create \
  --location westeurope \
  --template-file main.bicep
```

### Pulumi

```bash
cd pulumi
python3 -m venv venv && source venv/bin/activate
pip install -r requirements.txt
pulumi stack init dev
pulumi up
```

### Pulumi (C#)

```bash
cd pulumi-csharp
pulumi stack init dev
pulumi up
```

### Terraform

```bash
cd terraform
terraform init
terraform plan -out=tfplan
terraform apply tfplan
```

## State management - how each tool tracks what exists

State is the mechanism an IaC tool uses to know **what it previously deployed**
so it can calculate the difference between the desired configuration (your code)
and the actual infrastructure. Understanding state is critical for the AZ-400
exam and for day-to-day operations.

### ARM / Bicep - implicit state (Azure is the source of truth)

ARM and Bicep do **not** maintain a separate state file. Azure Resource Manager
itself is the source of truth.

```
You write template  ──▶  ARM compares it to what already exists in Azure  ──▶  creates/updates delta
```

- **Deployment mode: Incremental** (default) - ARM only touches resources
  declared in the template. Anything already in the resource group that is *not*
  in the template is left alone.
- **Deployment mode: Complete** - ARM deletes resources in the resource group
  that are *not* in the template. This is the closest ARM gets to full
  lifecycle management but is dangerous if multiple templates target the same
  resource group.
- **Deployment history** - Azure keeps the last 800 deployments per resource
  group (`az deployment group list`). This is an audit log, not state - you
  cannot roll back to a previous deployment entry.

**Consequence:** ther: https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/automation/automation-runbook-gallery.mde is no local file to lose, corrupt, or lock. But ARM
cannot detect out-of-band changes - if someone manually renames a resource, ARM
will simply create a new one next time rather than updating the renamed one.

### Terraform - explicit state file

Terraform keeps a **state file** (`terraform.tfstate`) that maps every resource
in your `.tf` files to a real Azure resource ID.

```
You write .tf  ──▶  Terraform compares .tf to tfstate  ──▶  compares tfstate to Azure  ──▶  plan
```

The flow on every `terraform plan` / `terraform apply`:

1. **Read** the state file to learn what Terraform previously created.
2. **Refresh** - query Azure to detect drift (real-world state vs recorded
   state).
3. **Diff** - compare the refreshed state against your `.tf` code to produce a
   plan of create / update / delete actions.
4. **Apply** - execut: https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/automation/automation-runbook-gallery.mde the plan and write the new state back.

Where state lives:

| Backend              | How it works                                                    |
|----------------------|-----------------------------------------------------------------|
| **Local** (default)  | `terraform.tfstate` on disk. Fine for learning, risky for teams - no locking, easy to lose. |
| **Azure Blob Storage** | Store state in a Storage Account container with blob lease locking. The standard choice for Azure teams. |
| **Terraform Cloud / HCP** | Managed SaaS backend with built-in locking, history, and RBAC. |

Example backend configuration for Azure:

```hcl
terraform {
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "stterraformstate"
    container_name       = "tfstate"
    key                  = "demo.terraform.tfstate"
  }
}
```

**Key risks:**
- **Lost state** = Terraform forgets everything it deployed. You must `terraform import` each resource manually to recover.
- **Concurrent writes** without locking corrupt the file. Always use a remote backend with locking for team use.
- **Secrets in state** - the state file contains resource attribute values in plain text (including the storage connection string from our demo). Treat it as sensitive.

### Pulumi - explicit: https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/automation/automation-runbook-gallery.md state (managed or self-hosted)

Pulumi's state model is conceptually identical to Terraform's - a file that
maps program resources to real cloud resource IDs - but the default storage
is a managed service instead of a local file.

```
You write code  ──▶  Pulumi compares code to state  ──▶  compares state to Azure  ──▶  preview
```

Where state lives:

| Backend              | How it works                                                    |
|----------------------|-----------------------------------------------------------------|
| **Pulumi Cloud** (default) | Managed SaaS at `app.pulumi.com`. State is encrypted at rest, has built-in locking, history, and RBAC. Free tier available. |
| **Self-hosted file** | `pulumi login --local` stores state in `~/.pulumi/stacks/`. Same trade-offs as Terraform's local backend. |
| **Azure Blob Storage** | `pulumi login azblob://<container>` stores state in a blob container, similar to Terraform's `azurerm` backend. |
| **S3 / GCS**         | Also supported if you work multi-cloud.                          |

**Key difference from Terraform:** Pulumi Cloud encrypts secrets in state by
default (using a per-stack key). Terraform stores them in plain text unless you
add a separate encryption layer.

### Side-by-side summary

```
ARM / Bicep           Terraform                 Pulumi
─────────────         ─────────────             ─────────────
No state file         terraform.tfstate         Pulumi Cloud / local file

Azure IS the          State file records         State file records
source of truth       resource IDs + attrs       resource IDs + attrs

Drift detection:      Drift detection:           Drift detection:
NOT built-in          "terraform refresh"        "pulumi refresh"
(re-deploy to         compares state to          compares state to
 converge)            real Azure resources       real Azure resources

Locking:              Locking:                   Locking:
Azure handles it      Backend-dependent          Built-in (Pulumi Cloud)
                      (blob lease, DynamoDB,     or backend-dependent
                       Terraform Cloud)

Secrets:              Secrets:                   Secrets:
N/A                   Plain text in state        Encrypted by default
                      (encrypt separately)       (Pulumi Cloud)
```

### What this means in practice

- **Solo developer, learning:** any backend works. Terraform local or
  `pulumi login --local` is fine. ARM/Bicep need nothing extra.
- **Team / CI-CD pipeline:** you need remote state with locking.
  - Terraform → Azure Blob backend with `lease` locking, or Terraform Cloud.
  - Pulumi → Pulumi Cloud (easiest) or `azblob://` backend.
  - ARM/Bicep → no extra setup, but you lose the ability to detect drift or
    do deletes-of-removed-resources (unless you use Complete mode).
- **Recovering from disaster:** if Terraform or Pulumi state is lost, you must
  import every resource. ARM/Bicep don't have this problem because there is no
  separate state to lose.

## Quick comparison

| Aspect                | ARM Template         | Bicep               | Pulumi (Python)     | Pulumi (C#)         | Terraform (HCL)    |
|-----------------------|----------------------|---------------------|---------------------|---------------------|---------------------|
| Language              | JSON                 | DSL (compiles to ARM) | Python            | C#                  | HCL                 |
| State management      | Azure (implicit)     | Azure (implicit)    | Pulumi Cloud / local | Pulumi Cloud / local | Local file / remote backend |
| Resource Group create | Subscription-level deploy + nested template | `targetScope = 'subscription'` + module | Direct resource     | Direct resource     | Direct resource     |
| Connection string     | `listKeys()` + `concat()` | `listKeys()` inline | `list_storage_account_keys()` Output chain | `ListStorageAccountKeys` + `Output.Tuple` | `primary_connection_string` attribute |
| Verbosity             | High (~100 lines)    | Low (~60 lines)     | Medium (~70 lines)  | Medium (~80 lines)  | Medium (~70 lines)  |
| Tooling required      | Azure CLI            | Azure CLI            | Pulumi CLI + Python | Pulumi CLI + .NET 8 SDK | Terraform CLI       |

### Pulumi: Python vs C# - what to highlight for students

The two Pulumi examples deploy **identical infrastructure** but show how the
same SDK adapts to different language ecosystems:

| Concern               | Python (`pulumi/`)          | C# (`pulumi-csharp/`)            |
|-----------------------|-----------------------------|----------------------------------|
| Async pattern         | `Output.all().apply()`      | `Output.Tuple().Apply()`         |
| Project file          | `requirements.txt`          | `.csproj` with NuGet packages    |
| Entry point           | `__main__.py`               | `Program.cs` (top-level statements) |
| Type safety           | Dynamic                     | Full compile-time checking       |

## IaC vs operational automation - where Azure Automation Runbooks fit in

The tools above are all about **provisioning** infrastructure (day 0 / day 1).
Azure Automation Runbooks and PowerShell Workflows solve a different problem:
**operating** infrastructure after it exists (day 2+).

### The distinction

| Concern | IaC (ARM, Bicep, Pulumi, Terraform) | Azure Automation Runbooks |
|---|---|---|
| **Purpose** | Define and provision infrastructure | Run operational tasks against existing infrastructure |
| **When** | "Create me an App Service with a Storage Account" | "Every night, clean up blobs older than 30 days" |
| **Trigger** | CI/CD pipeline, developer CLI | Schedule, webhook, Azure Monitor alert, manual |
| **Idempotent by design** | Yes - declarative desired state | No - you write the logic yourself |
| **State** | Tracks what's deployed | Stateless (fire-and-forget scripts) |

### When to use Azure Automation Runbooks

- **Scheduled maintenance** - rotate storage keys, scale down App Service Plans
  at night, clean up orphaned resources, expire old blobs.
- **Incident response** - triggered by an Azure Monitor alert to restart a
  service, snapshot a disk, or isolate a compromised VM.
- **Cross-system glue** - a single runbook can call Azure APIs, send emails,
  update a CMDB, and : https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/automation/automation-runbook-gallery.mdopen a ServiceNow ticket in one script.
- **Self-service for ops teams** - expose a runbook via webhook so someone
  without Azure Portal access can trigger a controlled action.
- **Hybrid automation** - Runbooks can target on-premises servers via the
  Hybrid Runbook Worker, which none of the IaC tools handle natively.

### PowerShell Workflows - mostly legacy

PowerShell Workflows (`workflow` keyword) were relevant in the early days of
Azure Automation because they offered:

- **Checkpointing** - resume a long-running job after a failure mid-way.
- **Parallel execution** - run blocks in parallel with `-Parallel`.
- **Suspend/resume** - pause a runbook and continue later.

**In practice, Microsoft now recommends PowerShell 7.2+ runbooks over
Workflows.** Here's why:

| | PowerShell Workflow | PowerShell 7.2 Runbook |
|---|---|---|
| Runtime | Windows PowerShell 5.1 only | PowerShell 7.2 (cross-platform) |
| Syntax | Restricted subset (no `$using:`, serialization quirks) | Full PowerShell |
| Parallel | `foreach -Parallel` (workflow-based) | `ForEach-Object -Parallel` (native) |
| Checkpointing | Built-in | Not built-in - use idempotent design instead |
| Microsoft guidance | Legacy, avoid for new work | Recommended |

The only reason to still use Workflows is if you need **built-in checkpointing**
for very long operations (hours) that must survive a platform restart. For
everything else, use a standard PowerShell 7.2 runbook.

### How they fit together in a real pipeline

```
CI/CD Pipeline (Azure DevOps / GitHub Actions)
  │
  ├──  IaC step: Terr: https://github.com/MicrosoftDocs/azure-docs/blob/main/articles/automation/automation-runbook-gallery.mdaform / Bicep / Pulumi provisions infrastructure
  │      ↓
  │    App Service, Storage Account, Automation Account now exist
  │
  └──  Post-deploy step: upload runbooks to the Automation Account
         ↓
       Runbooks handle day-2 operations on a schedule / trigger
```

IaC provisions the Automation Account and its runbooks, then the runbooks handle
ongoing operations. They are **complementary layers**, not alternatives - you
don't pick one *or* the other.

### When to pick what - decision tree

```
"I need to..."
  │
  ├── Create / change / delete Azure resources?
  │     → Use IaC (ARM, Bicep, Pulumi, Terraform)
  │
  ├── Run a recurring task against existing resources?
  │     → Use an Azure Automation Runbook (PowerShell 7.2)
  │
  ├── React to an Azure alert automatically?
  │     → Azure Monitor alert  →  webhook  →  Automation Runbook
  │
  ├── Run something on an on-premises server?
  │     → Automation Runbook + Hybrid Runbook Worker
  │
  └── Need checkpointing for a multi-hour operation?
        → PowerShell Workflow (only remaining valid use case)
```
