#!/usr/bin/env bash
# Remove any Google OAuth tokens from terraform.tfstate* in this directory.

set -euo pipefail
shopt -s nullglob

for f in terraform.tfstate terraform.tfstate.backup ; do
  [ -f "$f" ] || continue
  # jq: delete all `token` strings that contain `"access_token"` or `"refresh_token"`
  tmp="${f}.clean"
  jq 'walk(
        if type=="object" and has("token") then
          .token = "REDACTED"
        else .
        end )' "$f" > "$tmp"
  mv "$tmp" "$f"
done
