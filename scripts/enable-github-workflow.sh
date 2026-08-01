#!/usr/bin/env bash
set -euo pipefail

choice="${1:-cloudflare}"
mkdir -p .github/workflows

case "$choice" in
  cloudflare|trycloudflare)
    cp docs/github-workflows/nextjs-trycloudflare.yml .github/workflows/nextjs-trycloudflare.yml
    echo "Cloudflare workflow copied to .github/workflows/nextjs-trycloudflare.yml"
    ;;
  tailscale|ts)
    cp docs/github-workflows/nextjs-tailscale.yml .github/workflows/nextjs-tailscale.yml
    echo "Tailscale workflow copied to .github/workflows/nextjs-tailscale.yml"
    ;;
  all)
    cp docs/github-workflows/nextjs-trycloudflare.yml .github/workflows/nextjs-trycloudflare.yml
    cp docs/github-workflows/nextjs-tailscale.yml .github/workflows/nextjs-tailscale.yml
    echo "Cloudflare and Tailscale workflows copied to .github/workflows/"
    ;;
  *)
    echo "Usage: $0 [cloudflare|tailscale|all]" >&2
    exit 1
    ;;
esac

echo "Commit and push the copied workflow file with a GitHub token/user that has workflow permission."
