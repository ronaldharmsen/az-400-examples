#!/usr/bin/env bash
# Deploy with Pulumi

# First-time setup:
#   python3 -m venv venv
#   source venv/bin/activate
#   pip install -r requirements.txt
#   pulumi stack init dev

pulumi up --yes
