#!/usr/bin/env bash
# save-score.sh — Upload a score to the shared Supabase leaderboard
# Usage: ./save-score.sh <score.json>
#         or pipe: cat score.json | ./save-score.sh
#
# Requires environment variables:
#   SUPABASE_URL       — e.g. https://xxxxx.supabase.co
#   SUPABASE_ANON_KEY  — Supabase anon/public key

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY environment variables must be set." >&2
  echo "Get them from https://supabase.com/dashboard → your project → Settings → API" >&2
  exit 1
fi

# Read score JSON from file or stdin
SCORE_FILE="${1:-/dev/stdin}"
SCORE_JSON=$(cat "$SCORE_FILE" 2>/dev/null) || {
  echo "Error: cannot read score data from $SCORE_FILE" >&2
  exit 1
}

# Validate required fields
validate_field() {
  local val
  val=$(echo "$SCORE_JSON" | jq -r ".$1 // empty")
  if [ -z "$val" ]; then
    echo "Error: required field '$1' missing from score JSON" >&2
    exit 2
  fi
}

validate_field "username"
validate_field "tech_score"
validate_field "engineering_score"
validate_field "collab_score"
validate_field "influence_score"
validate_field "composite_score"
validate_field "summary"

# Build the POST payload for Supabase
# Map from our score.json format to the scores table columns
PAYLOAD=$(echo "$SCORE_JSON" | jq '{
  username: .username,
  github_id: (.github_id // null),
  avatar_url: (.avatar_url // null),
  tech_score: .tech_score,
  engineering_score: .engineering_score,
  collab_score: .collab_score,
  influence_score: .influence_score,
  composite_score: .composite_score,
  profile_tags: (.profile_tags // []),
  summary: .summary,
  full_report: (.full_report // null),
  github_snapshot: (.github_snapshot // null),
  submitter_id: (.submitter_id // null)
}')

# POST to Supabase (tempfile approach avoids stderr corrupting body)
SUPABASE_TMP=$(mktemp)
HTTP_CODE=$(curl -s -w "%{http_code}" -o "$SUPABASE_TMP" \
  -X POST "${SUPABASE_URL}/rest/v1/scores" \
  -H "apikey: ${SUPABASE_ANON_KEY}" \
  -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" \
  -H "Content-Type: application/json" \
  -H "Prefer: return=representation" \
  -d "$PAYLOAD" 2>/dev/null)
BODY=$(cat "$SUPABASE_TMP")
rm -f "$SUPABASE_TMP"

if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
  echo "Upload successful!"
  echo ""

  # Show the user's position on the leaderboard
  USERNAME=$(echo "$SCORE_JSON" | jq -r '.username')
  echo "Checking leaderboard position for $USERNAME..."

  LB_RESPONSE=$(curl -s \
    "${SUPABASE_URL}/rest/v1/leaderboard?select=username,composite_score&order=composite_score.desc" \
    -H "apikey: ${SUPABASE_ANON_KEY}" \
    -H "Authorization: Bearer ${SUPABASE_ANON_KEY}" 2>/dev/null)

  if echo "$LB_RESPONSE" | jq -e 'type == "array"' > /dev/null 2>&1; then
    TOTAL=$(echo "$LB_RESPONSE" | jq 'length')
    RANK=$(echo "$LB_RESPONSE" | jq "[.[].username] | index(\"$USERNAME\") + 1")
    if [ "$RANK" != "null" ] && [ "$RANK" -gt 0 ] 2>/dev/null; then
      echo "Leaderboard: #$RANK of $TOTAL scored users"
    fi
  fi
else
  echo "Upload failed (HTTP $HTTP_CODE):" >&2
  echo "$BODY" >&2
  exit 3
fi
