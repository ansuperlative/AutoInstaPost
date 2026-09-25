#!/bin/bash
# Loads .env and starts n8n at http://localhost:5678
cd "$(dirname "$0")"
set -a; source .env; set +a
exec npx -y -p node@24 -p n8n@latest n8n start
