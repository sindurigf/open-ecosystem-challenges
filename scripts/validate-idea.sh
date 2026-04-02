#!/usr/bin/env bash
# validate-idea.sh — Checks that an adventure idea file follows the required template format.
#
# Usage:
#   ./scripts/validate-idea.sh ideas/my-idea.md
#
# Exit codes:
#   0 — all checks passed
#   1 — one or more checks failed

# ---------------------------------------------------------------------------
# Strict mode
# ---------------------------------------------------------------------------
# -e is intentionally NOT set — we want all checks to run and collect every
# failure before exiting, so the contributor sees everything at once.
set -uo pipefail

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

ERRORS=()

# fail   — collects a failure; execution continues so all checks run
# hard_fail — for fatal pre-conditions where continuing makes no sense
fail() {
  ERRORS+=("❌ $1")
}

pass() {
  echo "✅ $1"
}

hard_fail() {
  echo "❌ $1" >&2
  exit 1
}

# ---------------------------------------------------------------------------
# Argument handling
# ---------------------------------------------------------------------------
[[ $# -ne 1 ]] && hard_fail "Usage: $0 <path-to-idea-file>"

FILE="$1"
[[ -f "$FILE" ]] || hard_fail "File not found: $FILE"

echo ""
echo "Validating: $FILE"
echo "-------------------------------------------"

# ---------------------------------------------------------------------------
# Check 1 — File guard
# ---------------------------------------------------------------------------
# Block .implemented/ files — they predate the current format and would fail.
[[ "$FILE" =~ ideas/\.implemented/ ]] \
  && hard_fail "Skipping already-implemented idea: $FILE"

pass "File guard passed"

# ---------------------------------------------------------------------------
# Check 2 — Required top-level sections
# ---------------------------------------------------------------------------
ERRORS_BEFORE=${#ERRORS[@]}

grep -q "^## Overview" "$FILE" \
  || fail "Missing required section: '## Overview' — use ATX heading style (## Overview), not bold text (**Overview**) or underline-style headings"

grep -q "^## Levels" "$FILE" \
  || fail "Missing required section: '## Levels' — use ATX heading style (## Levels), not bold text or underline-style headings"

[[ ${#ERRORS[@]} -eq $ERRORS_BEFORE ]] && pass "Required top-level sections present"

# ---------------------------------------------------------------------------
# Check 3 — Required Overview fields
# ---------------------------------------------------------------------------
ERRORS_BEFORE=${#ERRORS[@]}

grep -q "^\*\*Theme:\*\*" "$FILE" \
  || fail "Missing required Overview field: '**Theme:**'"

grep -q "^\*\*Skills:\*\*" "$FILE" \
  || fail "Missing required Overview field: '**Skills:**'"

grep -q "^\*\*Technologies:\*\*" "$FILE" \
  || fail "Missing required Overview field: '**Technologies:**'"

[[ ${#ERRORS[@]} -eq $ERRORS_BEFORE ]] && pass "Required Overview fields present"

# ---------------------------------------------------------------------------
# Check 4 — Required H4 subsections (global presence check)
# ---------------------------------------------------------------------------
# Confirms all six required subsection types appear somewhere in the file.
# Global check only — won't catch a level missing a section if another has it.

ERRORS_BEFORE=${#ERRORS[@]}

HINT="— use ATX heading style (#### Section Name), not bold text or underline-style headings"

grep -q "^#### Description" "$FILE" \
  || fail "Missing required subsection: '#### Description' $HINT"

grep -q "^#### Story" "$FILE" \
  || fail "Missing required subsection: '#### Story' $HINT"

grep -q "^#### The Problem" "$FILE" \
  || fail "Missing required subsection: '#### The Problem' $HINT"

grep -q "^#### Objective" "$FILE" \
  || fail "Missing required subsection: '#### Objective' $HINT"

grep -q "^#### What You'll Learn" "$FILE" \
  || fail "Missing required subsection: '#### What You'll Learn' $HINT"

grep -q "^#### Tools & Infrastructure" "$FILE" \
  || fail "Missing required subsection: '#### Tools & Infrastructure' $HINT"

[[ ${#ERRORS[@]} -eq $ERRORS_BEFORE ]] && pass "All required level sections present"

# ---------------------------------------------------------------------------
# Check 5 — No unfilled template placeholders (Python one-liner)
# ---------------------------------------------------------------------------
# Shell regex can't cleanly distinguish [placeholder] from [link text](url).
# Python's negative lookahead (?!\() handles this: matches [text] not followed
# by '(', which filters out Markdown links. [x] and [ ] (checkboxes) are excluded.
# Skipped for the template file itself, which intentionally contains placeholders.

if [[ "$FILE" != *"adventure-idea-template.md" ]]; then

  ERRORS_BEFORE=${#ERRORS[@]}

  PLACEHOLDER_OUTPUT=$(python3 -c "
import re, sys
content = open(sys.argv[1]).read()
hits = [m for m in re.findall(r'\[([^\]\n]+)\](?!\()', content) if m not in ('x', ' ')]
if hits:
    print(' '.join(hits))
    sys.exit(1)
" "$FILE") || fail "Unfilled template placeholders — replace: $PLACEHOLDER_OUTPUT"

  [[ ${#ERRORS[@]} -eq $ERRORS_BEFORE ]] && pass "No unfilled template placeholders"

fi

# ---------------------------------------------------------------------------
# Final summary
# ---------------------------------------------------------------------------
echo ""
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "Found ${#ERRORS[@]} problem(s) in: $FILE"
  echo ""
  for msg in "${ERRORS[@]}"; do
    echo "  $msg"
  done
  echo ""
  exit 1
else
  echo "✅ All checks passed for: $FILE"
  echo ""
fi
