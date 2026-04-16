# NuGet Package - Azure DevOps Artifacts

A minimal example that builds a .NET class library into a NuGet package and
publishes it to an Azure DevOps Artifacts feed - perfect for AZ-400 exam
preparation.

## What gets created

| Artifact                     | Details                                      |
|------------------------------|----------------------------------------------|
| Class library                | `Nforza.Demo.Utilities` targeting .NET 8     |
| NuGet package                | `.nupkg` produced by `dotnet pack`           |
| Artifacts feed (you provide) | Azure DevOps Artifacts feed to publish into  |

## Directory structure

```
packages/nuget/
├── src/
│   └── Nforza.Demo.Utilities/
│       ├── Nforza.Demo.Utilities.csproj   # Project with NuGet metadata
│       └── StringExtensions.cs            # Sample library code
├── nuget.config                           # Feed source + credential config
├── azure-pipelines.yml                    # CI/CD pipeline definition
├── deploy.sh                              # Local build + pack + push script
└── README.md
```

## Prerequisites

- .NET 8 SDK
- An Azure DevOps organization with an Artifacts feed
- A Personal Access Token (PAT) with **Packaging > Read & Write** scope (for
  local use only; CI uses `NuGetAuthenticate` instead)

## How to set up your feed

1. In Azure DevOps, go to **Artifacts** and create a new feed (or use an
   existing one).
2. Copy the feed URL - it looks like:
   ```
   https://pkgs.dev.azure.com/{org}/{project}/_packaging/{feed}/nuget/v3/index.json
   ```
3. Update `nuget.config` and replace the placeholder URL with your feed URL.

## How to publish locally

```bash
cd packages/nuget

# Set your PAT as an environment variable
export AZURE_ARTIFACTS_PAT=<your-pat>

# Build, pack, and push (defaults to version 1.0.0)
./deploy.sh

# Or specify a version
./deploy.sh 1.2.3
```

## How to publish from Azure Pipelines

The included `azure-pipelines.yml` handles the full flow:

1. **Build** the project.
2. **Pack** with an auto-incrementing version (`1.0.<BuildId>`).
3. **Authenticate** using the built-in `NuGetAuthenticate@1` task - no PAT or
   secrets needed because the pipeline's identity already has access to feeds
   in the same organization.
4. **Push** the `.nupkg` to the feed.

Update the `feedName` variable in `azure-pipelines.yml` to match your feed.

## How to consume the package

In a consuming project, add the Artifacts feed as a source and install the
package:

```bash
dotnet nuget add source "https://pkgs.dev.azure.com/{org}/{project}/_packaging/{feed}/nuget/v3/index.json" \
  --name AzureArtifacts \
  --username az \
  --password <PAT> \
  --store-password-in-clear-text

dotnet add package Nforza.Demo.Utilities
```

Or add the feed to a `nuget.config` in the consuming project (recommended for
teams).

## Key concepts for AZ-400

| Concept               | What to know                                                                                       |
|-----------------------|----------------------------------------------------------------------------------------------------|
| **Artifacts feed**    | A hosted NuGet (or npm/Maven/Python) repository inside Azure DevOps. Supports upstream sources.    |
| **Feed views**        | `@local`, `@prerelease`, `@release` - promote packages through quality stages.                     |
| **Upstream sources**  | A feed can proxy nuget.org so consumers only need one source configured.                           |
| **Retention**         | Feeds can auto-delete old package versions based on count or age policies.                         |
| **Authentication**    | Locally: PAT or credential provider. In pipelines: `NuGetAuthenticate@1` (no secrets to manage).  |
| **Versioning**        | Use SemVer. In CI, append the build ID for uniqueness (`1.0.$(Build.BuildId)`).                   |
| **Immutability**      | Once a version is published it cannot be overwritten - you must bump the version.                  |
