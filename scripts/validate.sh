#!/usr/bin/env bash
# Validate the sage-x3-l4g skill layout.
# Mirrors what CI runs; run locally before opening a PR.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

ERRORS=0
fail() { echo "  ✗ $*"; ERRORS=$((ERRORS + 1)); }
ok()   { echo "  ✓ $*"; }

echo "→ Checking marketplace.json"
if ! jq empty .claude-plugin/marketplace.json 2>/dev/null; then
  fail "marketplace.json is not valid JSON"
else
  ok "JSON is valid"

  NAME=$(jq -r '.owner.name' .claude-plugin/marketplace.json)
  if [[ "$NAME" == *REPLACE* ]]; then
    fail "marketplace.json owner.name still contains a placeholder"
  else
    ok "owner.name = $NAME"
  fi

  URL=$(jq -r '.owner.url' .claude-plugin/marketplace.json)
  if [[ "$URL" == *REPLACE* ]]; then
    fail "marketplace.json owner.url still contains a placeholder"
  else
    ok "owner.url  = $URL"
  fi
fi

echo
echo "→ Checking SKILL.md frontmatter"
SKILL="plugins/sage-x3-l4g/SKILL.md"
if [[ ! -f "$SKILL" ]]; then
  fail "$SKILL not found"
else
  # Frontmatter must start at line 1 with --- and contain name + description
  FM=$(awk 'NR==1 && /^---$/ {flag=1; next} /^---$/ && flag {exit} flag' "$SKILL")
  if [[ -z "$FM" ]]; then
    fail "SKILL.md has no YAML frontmatter"
  else
    if echo "$FM" | grep -q '^name:'; then ok "name: present"; else fail "frontmatter missing name"; fi
    if echo "$FM" | grep -q '^description:'; then ok "description: present"; else fail "frontmatter missing description"; fi
  fi
fi

echo
echo "→ Checking reference cross-links"
REFDIR="plugins/sage-x3-l4g/references"
if [[ ! -d "$REFDIR" ]]; then
  fail "references/ directory missing"
else
  # Extract references of the form `foo.md` or `references/foo.md` from all markdown files
  # and confirm each target exists.
  MISSING=0
  while IFS= read -r line; do
    # Parse filename from the match
    TARGET=$(echo "$line" | sed -E 's/.*`([a-zA-Z0-9_-]+\.md)`.*/\1/')
    # Skip if the regex didn't extract a clean filename
    if [[ ! "$TARGET" =~ ^[a-zA-Z0-9_-]+\.md$ ]]; then
      continue
    fi
    # Skip top-level docs we know are siblings (README, CHANGELOG, etc.)
    case "$TARGET" in
      README.md|CHANGELOG.md|CONTRIBUTING.md|CLAUDE.md|LICENSE|README_FR.md) continue ;;
    esac
    # Check the file is somewhere under plugins/ or tests/ or examples/
    if ! find plugins tests examples -name "$TARGET" 2>/dev/null | grep -q .; then
      fail "reference not found: $TARGET"
      MISSING=$((MISSING + 1))
    fi
  done < <(grep -rhoE '`[a-zA-Z0-9_/-]+\.md`' plugins/ 2>/dev/null | sort -u)

  if [[ $MISSING -eq 0 ]]; then
    ok "all referenced files resolve"
  fi
fi

echo
echo "→ Checking examples"
if [[ -d "examples" ]]; then
  COUNT=$(find examples -maxdepth 1 \( -name "*.src" -o -name "*.trt" \) | wc -l | tr -d ' ')
  if [[ "$COUNT" -lt 1 ]]; then
    fail "examples/ has no .src or .trt files"
  else
    ok "$COUNT example file(s) found"
  fi
fi

echo
if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All checks passed."
  exit 0
else
  echo "❌ $ERRORS check(s) failed."
  exit 1
fi
