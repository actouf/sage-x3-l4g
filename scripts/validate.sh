#!/usr/bin/env bash
# Validate the sage-x3-l4g skill layout.
# Mirrors what CI runs; run locally before opening a PR.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export LC_ALL=C.UTF-8

ERRORS=0
fail() { echo "  ✗ $*"; ERRORS=$((ERRORS + 1)); }
ok()   { echo "  ✓ $*"; }
warn() { echo "  ! $*"; }

PLUGIN="plugins/sage-x3-l4g"
SKILL="$PLUGIN/SKILL.md"
REFDIR="$PLUGIN/references"
EXDIR="$PLUGIN/examples"
PJ="$PLUGIN/.claude-plugin/plugin.json"
MK=".claude-plugin/marketplace.json"

echo "→ Checking manifests"
if ! jq empty "$MK" 2>/dev/null; then
  fail "marketplace.json is not valid JSON"
else
  ok "marketplace.json is valid JSON"
  for FIELD in .owner.name .owner.url; do
    VAL=$(jq -r "$FIELD" "$MK")
    if [[ "$VAL" == *REPLACE* || "$VAL" == "null" ]]; then
      fail "marketplace.json $FIELD is missing or a placeholder"
    fi
  done
  # A field set on the marketplace entry overrides plugin.json for users: keep plugin.json the only source.
  OVERRIDES=$(jq -r '.plugins[] | select(.name=="sage-x3-l4g") | keys[] | select(. == "version" or . == "description" or . == "keywords")' "$MK")
  if [[ -n "$OVERRIDES" ]]; then
    fail "marketplace.json entry overrides plugin.json: $(echo $OVERRIDES)"
  else
    ok "marketplace entry does not override version / description / keywords"
  fi
fi

VER=""
if ! jq empty "$PJ" 2>/dev/null; then
  fail "plugin.json missing or not valid JSON"
else
  [[ "$(jq -r .name "$PJ")" == "sage-x3-l4g" ]] && ok "plugin.json name = sage-x3-l4g" || fail "plugin.json name must be sage-x3-l4g"
  VER=$(jq -r '.version // empty' "$PJ")
  if [[ "$VER" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then ok "plugin.json version = $VER"; else fail "plugin.json version is not SemVer: '$VER'"; fi
fi

echo
echo "→ Checking version sync"
if [[ -n "$VER" ]]; then
  CLV=$(grep -m1 -oE '^## \[[0-9]+\.[0-9]+\.[0-9]+\]' CHANGELOG.md | tr -d '#[] ' || true)
  [[ "$CLV" == "$VER" ]] && ok "CHANGELOG top entry = $VER" || fail "CHANGELOG top entry ($CLV) != plugin.json ($VER)"
  grep -qE "^\[$VER\]: " CHANGELOG.md && ok "CHANGELOG link for $VER present" || fail "CHANGELOG has no [$VER]: link"
  if [[ "${GITHUB_REF_TYPE:-}" == "tag" ]]; then
    [[ "${GITHUB_REF_NAME#v}" == "$VER" ]] && ok "tag ${GITHUB_REF_NAME} matches" || fail "tag ${GITHUB_REF_NAME} != v$VER"
  fi
fi

echo
echo "→ Checking SKILL.md frontmatter"
if [[ ! -f "$SKILL" ]]; then
  fail "$SKILL not found"
else
  FM=$(awk 'NR==1 && /^---$/ {flag=1; next} /^---$/ && flag {exit} flag' "$SKILL")
  if [[ -z "$FM" ]]; then
    fail "SKILL.md has no YAML frontmatter"
  else
    NAME=$(echo "$FM" | sed -n 's/^name:[[:space:]]*//p')
    if [[ "$NAME" =~ ^[a-z0-9]+(-[a-z0-9]+)*$ && ${#NAME} -le 64 && "$NAME" != *anthropic* && "$NAME" != *claude* ]]; then
      ok "name: $NAME"
    else
      fail "name '$NAME' must be lowercase-hyphenated, ≤ 64 chars, without 'anthropic'/'claude'"
    fi
    [[ "$NAME" == "$(basename "$PLUGIN")" ]] || fail "name '$NAME' must match folder '$(basename "$PLUGIN")'"

    DESC=$(echo "$FM" | sed -n 's/^description:[[:space:]]*//p')
    DLEN=$(printf '%s' "$DESC" | wc -m | tr -d ' ')
    if [[ -z "$DESC" ]]; then
      fail "frontmatter missing description"
    elif [[ "$DLEN" -gt 1024 ]]; then
      fail "description is $DLEN chars (max 1024)"
    else
      ok "description: $DLEN chars (≤ 1024)"
    fi
    [[ "$DESC" == *"<"* || "$DESC" == *">"* ]] && fail "description must not contain < or >"

    BAD_KEYS=$(echo "$FM" | grep -oE '^[A-Za-z_-]+:' | tr -d ':' | grep -vxE 'name|description|license|compatibility|metadata|allowed-tools' || true)
    [[ -n "$BAD_KEYS" ]] && fail "frontmatter keys not accepted by claude.ai: $BAD_KEYS" || ok "frontmatter keys are portable"
  fi
  BODY=$(awk 'NR==1 && /^---$/ {fm=1; next} fm && /^---$/ {fm=0; next} !fm' "$SKILL" | wc -l | tr -d ' ')
  [[ "$BODY" -lt 500 ]] && ok "SKILL.md body: $BODY lines (< 500)" || fail "SKILL.md body is $BODY lines (must be < 500)"
fi

echo
echo "→ Checking references"
if [[ ! -d "$REFDIR" ]]; then
  fail "references/ directory missing"
else
  for F in "$REFDIR"/*.md; do
    B=$(basename "$F")
    N=$(wc -l < "$F" | tr -d ' ')
    [[ "$N" -gt 340 ]] && fail "$B: $N lines (max 340 — split it)"
    [[ "$N" -gt 300 && "$N" -le 340 ]] && warn "$B: $N lines (target ≤ 300)"
    if [[ "$N" -gt 100 ]] && ! grep -q '^## Contents' "$F"; then fail "$B: > 100 lines without '## Contents'"; fi
    grep -q '^## Sources' "$F" || fail "$B: missing '## Sources' section"
    grep -q "references/$B" "$SKILL" || fail "$B: not listed in SKILL.md"
    for DOC in README.md README_FR.md index.md; do
      grep -q "$B" "$DOC" || fail "$B: not listed in $DOC"
    done
  done
  ok "$(ls "$REFDIR"/*.md | wc -l | tr -d ' ') reference file(s) checked"
fi

echo
echo "→ Checking cross-links"
MISSING=0
while IFS= read -r TARGET; do
  TARGET=${TARGET//\`/}
  B=$(basename "$TARGET")
  case "$B" in README.md|CHANGELOG.md|CONTRIBUTING.md|CLAUDE.md|README_FR.md|SKILL.md) continue ;; esac
  if [[ "$TARGET" == */* ]]; then
    FOUND=$([[ -e "$PLUGIN/$TARGET" ]] && echo 1 || true)   # path relative to the skill root
  else
    FOUND=$(find "$PLUGIN" -name "$B" | head -1)
  fi
  if [[ -z "$FOUND" ]]; then
    fail "backticked reference not found: $TARGET"
    MISSING=$((MISSING + 1))
  fi
done < <(grep -rhoE '`((references/)?[a-zA-Z0-9_.-]+\.md|examples/[a-zA-Z0-9_.-]+\.(src|trt))`' "$PLUGIN" | sort -u)
while IFS= read -r LINK; do
  [[ -e "$LINK" ]] || { fail "index/README link not found: $LINK"; MISSING=$((MISSING + 1)); }
done < <(grep -hoE '\]\([^)#:]+\)' index.md README.md README_FR.md | sed -E 's/^\]\(//; s/\)$//' | sort -u)
[[ $MISSING -eq 0 ]] && ok "all referenced files resolve"

echo
echo "→ Checking examples"
COUNT=$( (find "$EXDIR" -maxdepth 1 \( -name "*.src" -o -name "*.trt" \) 2>/dev/null || true) | wc -l | tr -d ' ')
[[ "$COUNT" -ge 1 ]] && ok "$COUNT example file(s) in $EXDIR" || fail "$EXDIR has no .src or .trt files"
for F in "$EXDIR"/*.src "$EXDIR"/*.trt; do
  [[ -e "$F" ]] || continue
  B=$(basename "$F")
  grep -q "examples/$B" "$SKILL" || fail "$B: not listed in SKILL.md"
  grep -q "$B" "$EXDIR/README.md" || fail "$B: not listed in examples/README.md"
done

echo
echo "→ Checking L4G code (deny-list of non-existent keywords / APIs, indentation)"
# Emit "file:line:code" for every line of ```l4g blocks in SKILL.md and references and every line of examples,
# with comments stripped, then grep for tokens that do not exist in X3 4GL.
extract_code() {
  awk '
    FNR==1 { inblk = (FILENAME ~ /\.(src|trt)$/) }
    FILENAME ~ /\.md$/ && /^```l4g/ { inblk=1; next }
    FILENAME ~ /\.md$/ && /^```/    { inblk=0; next }
    inblk {
      line=$0
      if (line ~ /^[ \t]*#/) next
      sub(/:[ \t]*#.*$/, "", line)
      print FILENAME ":" FNR ":" line
    }' "$SKILL" "$REFDIR"/*.md "$EXDIR"/*.src "$EXDIR"/*.trt 2>/dev/null
}
CODE=$(extract_code || true)
DENY=(
  '\bReadseq\b' '\bWriteseq\b' '\bExitfor\b' '\bContinue\b' '\bIncr\b' '\bEndclass\b'
  ':[[:space:]]*(Public|Private)[[:space:]]' 'ECRAN_TRACE' '\bENVMAIL' 'AFNC\.JSONGET'
  '\breplace\$' '\blen\$' '\bstrip\$' '\bupper\$' '\blower\$'
  '\bIf[[:space:]]+(\[S\])?adxlog[[:space:]]*($|:)' ':[[:space:]]*For\b.*\bOrder[[:space:]]+By\b'
  '\bDecr\b' 'Onerrgo[[:space:]]+0\b' '\bExec[[:space:]]+Sql\b' 'From[[:space:]]+GESNUM\b'
  'AFNC\.(PARAMG|JSONSET|XMLGET)' 'ASYSTEM\.ParseJson' 'ASYRMAILAPI' 'GDEV\.DEVISE' '\bFORMAT_ADDR\b'
  '\b(BPCNUM|ITMREF|SOHNUM)0\b' '\[GACC\]' '/api/x3/'
  '\b(GESAPL|GESAOI|GESAUT|GESAML|GESAPA|GESVAL|GESCUR|GESAWS|GESAWT|GESALOCK)\b'
)
DENY_HITS=0
for PAT in "${DENY[@]}"; do
  # Match against "file:line:code"; anchor patterns written with ':' at the code start.
  HITS=$(printf '%s\n' "$CODE" | sed -E 's/^([^:]+:[0-9]+:)[[:space:]]*/\1/' | grep -iE "$PAT" || true)
  if [[ -n "$HITS" ]]; then
    fail "forbidden pattern /$PAT/:"
    printf '%s\n' "$HITS" | head -5 | sed 's/^/      /'
    DENY_HITS=$((DENY_HITS + 1))
  fi
done
TABS=$(printf '%s\n' "$CODE" | grep -P '\t' || true)
[[ -n "$TABS" ]] && { fail "tab characters in L4G code:"; printf '%s\n' "$TABS" | head -5 | sed 's/^/      /'; DENY_HITS=$((DENY_HITS + 1)); }
[[ $DENY_HITS -eq 0 ]] && ok "no forbidden keywords / APIs in L4G code"

# House style: the first indentation level in each code block / example must be 2 spaces.
BAD_INDENT=$(awk '
  function flush() { if (blk != "" && minind > 0 && minind != 2) print blk " (first indent = " minind " spaces)"; blk=""; minind=0 }
  FNR==1 { flush(); if (FILENAME ~ /\.(src|trt)$/) { blk=FILENAME; inblk=1 } else inblk=0 }
  FILENAME ~ /\.md$/ && /^```l4g/ { flush(); blk=FILENAME ":" FNR; inblk=1; next }
  FILENAME ~ /\.md$/ && /^```/    { if (inblk) flush(); inblk=0; next }
  inblk && /^ +[^ &]/ { match($0, /^ +/); if (minind == 0 || RLENGTH < minind) minind = RLENGTH }
  END { flush() }' "$SKILL" "$REFDIR"/*.md "$EXDIR"/*.src "$EXDIR"/*.trt 2>/dev/null || true)
# L4G hidden in an untagged fence escapes every check above: require ```l4g.
UNTAGGED=$(awk '
  FNR==1 { inblk=0 }
  /^```/ {
    if (!inblk) { inblk=1; untag=($0 ~ /^```[[:space:]]*$/); start=FNR; next }
    inblk=0; next
  }
  inblk && untag && /(Trbegin|fstat|\[F:|\[L\]|Subprog |Funprog )/ { print FILENAME ":" start; untag=0 }
' "$SKILL" "$REFDIR"/*.md)
if [[ -n "$UNTAGGED" ]]; then
  fail "L4G code in a fence without the l4g tag:"
  printf '%s\n' "$UNTAGGED" | head -10 | sed 's/^/      /'
fi
if [[ -n "$BAD_INDENT" ]]; then
  fail "L4G blocks not using 2-space indentation:"
  printf '%s\n' "$BAD_INDENT" | head -10 | sed 's/^/      /'
else
  ok "L4G blocks use 2-space indentation"
fi

echo
if [[ $ERRORS -eq 0 ]]; then
  echo "✅ All checks passed."
  exit 0
else
  echo "❌ $ERRORS check(s) failed."
  exit 1
fi
