#!/usr/bin/env bash
# Deploy with Terraform

terraform init
terraform plan -out=tfplan
terraform apply tfplan
