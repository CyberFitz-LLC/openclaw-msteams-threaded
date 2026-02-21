#!/usr/bin/env bash
# apply.sh — Apply minimal thread sessions patches to an OpenClaw source install.
# Usage: cd /path/to/openclaw && /path/to/apply.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCHES_DIR="$SCRIPT_DIR/patches"

if [ ! -f "package.json" ]; then
  echo "ERROR: Run this script from the root of your OpenClaw source directory." >&2
  exit 1
fi

echo "Applying thread sessions patches..."

for patch in core-schema sent-message-cache message-handler messenger send-context; do
  file="$PATCHES_DIR/${patch}.patch"
  if [ ! -f "$file" ]; then
    echo "  SKIP: $file not found"
    continue
  fi
  if git apply --check "$file" 2>/dev/null; then
    git apply "$file"
    echo "  OK: $patch"
  else
    echo "  CONFLICT: $patch (try: git apply --3way $file)"
  fi
done

echo "Done. Run 'pnpm build' to verify."
