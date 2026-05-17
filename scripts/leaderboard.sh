#!/usr/bin/env bash
# leaderboard.sh 鈥?Query the shared Supabase leaderboard
# Usage:
#   ./leaderboard.sh                  # Top 20
#   ./leaderboard.sh 50               # Top 50
#   ./leaderboard.sh --user torvalds  # Look up a specific user
#   ./leaderboard.sh --stats          # Global statistics
#
# Requires: SUPABASE_URL and SUPABASE_ANON_KEY env vars

set -euo pipefail

SUPABASE_URL="${SUPABASE_URL:-}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"

if [ -z "$SUPABASE_URL" ] || [ -z "$SUPABASE_ANON_KEY" ]; then
  echo "Error: SUPABASE_URL and SUPABASE_ANON_KEY environment variables must be set." >&2
  exit 1
fi

# Parse arguments
MODE="top"
ARG="20"

case "${1:-}" in
  --user|-u)
    MODE="user"
    ARG="${2:-}"
    if [ -z "$ARG" ]; then
      echo "Usage: leaderboard.sh --user <username>" >&2
      exit 1
    fi
    ;;
  --stats|-s)
    MODE="stats"
    ;;
  "")
    ;;
  *)
    ARG="${1}"
    ;;
esac

# Common curl headers
CURL_OPTS=(-s -H "apikey: ${SUPABASE_ANON_KEY}" -H "Authorization: Bearer ${SUPABASE_ANON_KEY}")

if [ "$MODE" = "stats" ]; then
  echo "=== GitHub Profiler 鈥?Global Stats ==="
  echo ""

  RESPONSE=$(curl "${CURL_OPTS[@]}" \
    "${SUPABASE_URL}/rest/v1/rpc/get_stats" 2>/dev/null)

  if echo "$RESPONSE" | jq -e '.total_users_scored' > /dev/null 2>&1; then
    echo "Total users scored  : $(echo "$RESPONSE" | jq -r '.total_users_scored')"
    echo "Total submissions   : $(echo "$RESPONSE" | jq -r '.total_submissions')"
    echo "Average score       : $(echo "$RESPONSE" | jq -r '.average_score')/5.0"
    echo ""
    echo "--- Top Scored User ---"
    echo "  $(echo "$RESPONSE" | jq -r '.top_user.username') 鈥?$(echo "$RESPONSE" | jq -r '.top_user.score')"
    echo ""
    echo "--- Recent Scores ---"
    echo "$RESPONSE" | jq -r '.recent_scores[] | "  \(.username) 鈥?\(.composite_score) [\(.profile_tags | join(", "))]"'
  else
    echo "No data yet. Be the first to submit a score!"
  fi

elif [ "$MODE" = "user" ]; then
  echo "=== Score History for $ARG ==="
  echo ""

  RESPONSE=$(curl "${CURL_OPTS[@]}" \
    "${SUPABASE_URL}/rest/v1/scores?username=eq.${ARG}&order=created_at.desc&limit=10" 2>/dev/null)

  if echo "$RESPONSE" | jq -e 'length > 0' > /dev/null 2>&1; then
    echo "$RESPONSE" | jq -r '.[] |
      "--- Scored at \(.created_at) ---",
      "  Composite : \(.composite_score)/5.0",
      "  Tech      : \(.tech_score) | Engineering: \(.engineering_score)",
      "  Collab    : \(.collab_score) | Influence  : \(.influence_score)",
      "  Tags      : \([.profile_tags[]?] | join(", "))",
      "  \(.summary)\n"
    '

    # Check leaderboard rank
    LB=$(curl "${CURL_OPTS[@]}" \
      "${SUPABASE_URL}/rest/v1/leaderboard?select=username,composite_score&order=composite_score.desc" 2>/dev/null)
    if echo "$LB" | jq -e 'type == "array"' > /dev/null 2>&1; then
      TOTAL=$(echo "$LB" | jq 'length')
      RANK=$(echo "$LB" | jq "[.[].username] | index(\"$ARG\") + 1")
      echo "Current Rank: #$RANK of $TOTAL"
    fi
  else
    echo "No scores found for user: $ARG"
  fi

else
  echo "=== GitHub Profiler 鈥?Leaderboard (Top $ARG) ==="
  echo ""

  RESPONSE=$(curl "${CURL_OPTS[@]}" \
    "${SUPABASE_URL}/rest/v1/leaderboard?select=username,avatar_url,composite_score,tech_score,engineering_score,collab_score,influence_score,profile_tags,summary&order=composite_score.desc&limit=${ARG}" 2>/dev/null)

  if echo "$RESPONSE" | jq -e 'length > 0' > /dev/null 2>&1; then
    printf "%-5s %-25s %6s %6s %6s %6s %6s %s\n" "Rank" "Username" "Score" "Tech" "Eng" "Collab" "Influ" "Tags"
    printf "%.0s-" {1..100}
    echo ""

    echo "$RESPONSE" | jq -r 'to_entries[] |
      "\(.key+1 | tostring | .[0:5])     \(.value.username | .[0:24])     \(.value.composite_score)   \(.value.tech_score)   \(.value.engineering_score)   \(.value.collab_score)   \(.value.influence_score)   \([.value.profile_tags[]?] | join(", "))"'
  else
    echo "No scores yet. Use /github-scorer to analyze a user and submit!"
  fi
fi
