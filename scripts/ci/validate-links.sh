#!/usr/bin/env bash
# validate-links.sh — Verify internal Markdown links resolve to existing files.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT"

ERRORS=0
CHECKED=0

resolve_link() {
  local source_file="$1"
  local link_path="$2"

  # Strip anchor fragment
  local path_no_anchor="${link_path%%#*}"

  # Skip empty, external, and mailto links
  [[ -z "$path_no_anchor" ]] && return 0
  [[ "$path_no_anchor" =~ ^https?:// ]] && return 0
  [[ "$path_no_anchor" =~ ^mailto: ]] && return 0

  # Skip Docusaurus site-root paths (validated by `npm run build`)
  [[ "$path_no_anchor" =~ ^/ ]] && return 0

  local target
  if [[ "$path_no_anchor" = /* ]]; then
    target="${ROOT}${path_no_anchor}"
  else
    target="$(python3 -c "import os; src='$source_file'; print(os.path.normpath(os.path.join(os.path.dirname(src), '$path_no_anchor')))")"
  fi

  if [[ ! -f "$target" ]]; then
    echo "BROKEN: ${source_file#"$ROOT"/} → ${link_path} (missing: ${target#"$ROOT"/})"
    ERRORS=$((ERRORS + 1))
  fi
}

strip_code_blocks() {
  awk '
    /^```/ { in_code = !in_code; next }
    !in_code { print }
  ' "$1"
}

while IFS= read -r -d '' file; do
  if [[ "$file" != /* ]]; then
    file="${ROOT}/${file}"
  fi

  while IFS= read -r link; do
    [[ -z "$link" ]] && continue
    CHECKED=$((CHECKED + 1))
    resolve_link "$file" "$link"
  done < <(strip_code_blocks "$file" | grep -oE '\[[^]]*\]\([^)]+\)' | sed -E 's/^\[[^]]*\]\(([^)]+)\)$/\1/' || true)
done < <(find "$ROOT" \
  \( -path "$ROOT/docs" -o \
     -path "$ROOT/labs" -o \
     -path "$ROOT/scripts" -o \
     -name 'README.md' -o \
     -name 'SUMMARY.md' -o \
     -name 'STYLE_GUIDE.md' -o \
     -name 'CONTRIBUTING.md' \) \
  -name '*.md' -not -path '*/.git/*' -not -path '*/node_modules/*' -print0)

echo "Checked ${CHECKED} internal links."

if [[ $ERRORS -gt 0 ]]; then
  echo "Found ${ERRORS} broken link(s)."
  exit 1
fi

echo "All internal links valid."
