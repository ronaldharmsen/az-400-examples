#!/usr/bin/env bash
# Build, pack, and push a NuGet package to an Azure DevOps Artifacts feed.

set -euo pipefail

# ── Configuration ────────────────────────────────────────────────────
PACKAGE_VERSION="${1:-1.0.0}"
FEED_NAME="AzureArtifacts"               # must match the source name in nuget.config
PROJECT_DIR="src/Nforza.Demo.Utilities"
OUTPUT_DIR="out"

# ── Build & Pack ─────────────────────────────────────────────────────
echo "==> Building project..."
dotnet build "$PROJECT_DIR" --configuration Release

echo "==> Packing version $PACKAGE_VERSION..."
dotnet pack "$PROJECT_DIR" \
  --configuration Release \
  --output "$OUTPUT_DIR" \
  -p:PackageVersion="$PACKAGE_VERSION"

# ── Push ─────────────────────────────────────────────────────────────
NUPKG=$(find "$OUTPUT_DIR" -name "*.nupkg" | head -1)

echo "==> Pushing $NUPKG to feed '$FEED_NAME'..."
dotnet nuget push "$NUPKG" \
  --source "$FEED_NAME" \
  --api-key az                            # Azure Artifacts ignores the key value; authentication comes from nuget.config or the credential provider

echo "==> Done. Package published to Azure Artifacts."
