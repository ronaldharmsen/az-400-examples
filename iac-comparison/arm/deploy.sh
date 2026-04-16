#!/usr/bin/env bash
# Deploy the ARM template at subscription level (creates the resource group + nested resources)

az deployment sub create \
  --location westeurope \
  --template-file azuredeploy.json \
  --parameters @azuredeploy.parameters.json
