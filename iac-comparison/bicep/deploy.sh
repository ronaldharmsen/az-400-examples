#!/usr/bin/env bash
# Deploy the Bicep template at subscription level (creates the resource group + nested resources)

az deployment sub create \
  --location westeurope \
  --template-file main.bicep
