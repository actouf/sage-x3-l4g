#!/usr/bin/env bash
# Print the CHANGELOG.md section of one version (heading excluded), e.g.:
#   scripts/release-notes.sh 1.0.0
#   scripts/release-notes.sh v1.0.0
set -euo pipefail

V="${1:?usage: release-notes.sh <version>}"
V="${V#v}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

awk -v v="$V" '
  index($0, "## [" v "]") == 1 { found = 1; next }
  found && (/^## \[/ || /^\[[^]]+\]: /) { exit }
  found { print }
' "$ROOT/CHANGELOG.md" | awk 'NF { started = 1 } started' | sed -e :a -e '/^\n*$/{$d;N;ba' -e '}'
