#!/usr/bin/env bash
set -euo pipefail

mkdir -p .github/workflows
cp docs/github-workflows/nextjs-trycloudflare.yml .github/workflows/nextjs-trycloudflare.yml

echo "Workflow copied to .github/workflows/nextjs-trycloudflare.yml"
echo "Commit and push this file with a GitHub token/user that has workflow permission."
