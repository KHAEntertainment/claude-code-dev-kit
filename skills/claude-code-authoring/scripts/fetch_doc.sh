#!/usr/bin/env bash
# Fetch raw Claude Code doc pages (markdown) into a local cache so they can be
# grepped exactly. Summarizing fetchers can paraphrase enum values and field
# names; the raw page cannot.
#
# Usage: fetch_doc.sh <page> [<page> ...]    e.g. fetch_doc.sh hooks skills
#        fetch_doc.sh --index                 list every page in llms.txt
# Prints the cached file path for each page. Cache refreshes after 12 hours.
set -euo pipefail
BASE="https://code.claude.com/docs/en"
CACHE="${CLAUDE_DOCS_CACHE:-${TMPDIR:-/tmp}/claude-code-docs}"
mkdir -p "$CACHE"

if [[ "${1:-}" == "--index" ]]; then
  curl -fsSL "https://code.claude.com/docs/llms.txt" -o "$CACHE/llms.txt"
  grep -oE 'https://code\.claude\.com/docs/en/[^ )]+\.md' "$CACHE/llms.txt" \
    | sed -E 's#https://code.claude.com/docs/en/##; s#\.md$##' | sort -u
  exit 0
fi

[[ $# -gt 0 ]] || { echo "usage: $0 <page>... | --index" >&2; exit 2; }
for page in "$@"; do
  page="${page%.md}"
  out="$CACHE/${page//\//__}.md"
  if [[ ! -s "$out" || -n "$(find "$out" -mmin +720 2>/dev/null)" ]]; then
    curl -fsSL "$BASE/$page.md" -o "$out.tmp" && mv "$out.tmp" "$out" \
      || { rm -f "$out.tmp"; echo "failed: $page (check name with --index)" >&2; continue; }
  fi
  echo "$out"
done
