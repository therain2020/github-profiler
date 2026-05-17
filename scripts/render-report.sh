#!/usr/bin/env bash
# render-report.sh — 将评分/蒸馏 JSON 渲染为可视化 HTML 报告
# 用法:
#   bash scripts/render-report.sh <data.json> <mode:scorer|distill> [output.html]

set -uo pipefail

DATA_FILE="$1"
MODE="${2:-scorer}"
OUTPUT="${3:-}"

if [ ! -f "$DATA_FILE" ]; then
  echo "Error: data file not found: $DATA_FILE" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATE="${PROJECT_DIR}/templates/${MODE}-report.html"

if [ ! -f "$TEMPLATE" ]; then
  echo "Error: template not found: $TEMPLATE" >&2
  exit 1
fi

USERNAME=$(jq -r '.meta.username // .profile.login // "unknown"' "$DATA_FILE")
AVATAR=$(jq -r '.profile.avatar_url // ""' "$DATA_FILE")
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
OUTPUT="${OUTPUT:-${PROJECT_DIR}/reports/${USERNAME}-${MODE}-${TIMESTAMP}.html}"

echo "渲染 ${MODE} 报告 → ${OUTPUT}"

# ── 通用数据 ──
CAL_DATA=$(jq '[.contributions.calendar.weeks[].days[]? | select(.count > 0) | [.date, .count]]' "$DATA_FILE" 2>/dev/null || echo '[]')
CAL_MAX=$(echo "$CAL_DATA" | jq 'map(.[1]) | max // 1' 2>/dev/null || echo "1")
CAL_MIN=$(echo "$CAL_DATA" | jq 'map(.[0]) | min // "2025-01-01"' 2>/dev/null || echo '"2025-01-01"')
CAL_MAX_DATE=$(echo "$CAL_DATA" | jq 'map(.[0]) | max // "2026-01-01"' 2>/dev/null || echo '"2026-01-01"')
CAL_RANGE="${CAL_MIN}-${CAL_MAX_DATE}"
CAL_RANGE=$(echo "$CAL_RANGE" | tr -d '"')

LANG_DATA=$(jq '[.repositories | group_by(.language) | .[] | {name: (.[0].language // "Unknown"), value: length}]' "$DATA_FILE" 2>/dev/null || echo '[]')

if [ "$MODE" = "scorer" ]; then
  # ── 评分数据 ──
  TECH=$(jq -r '.tech_score // 0' "$DATA_FILE")
  ENG=$(jq -r '.engineering_score // 0' "$DATA_FILE")
  COLLAB=$(jq -r '.collab_score // 0' "$DATA_FILE")
  INFLU=$(jq -r '.influence_score // 0' "$DATA_FILE")
  COMP=$(jq -r '.composite_score // 0' "$DATA_FILE")
  TAGS=$(jq -r '[.profile_tags[]? | "<span class=\"tag\">\(.)</span>"] | join(" ")' "$DATA_FILE" 2>/dev/null || echo "")
  SUMMARY=$(jq -r '.summary // ""' "$DATA_FILE")

  # 等级和颜色
  if awk "BEGIN {exit !($COMP >= 4.5)}"; then GRADE="大师级"; COLOR="#6366f1"; DESC="社区领袖级别"
  elif awk "BEGIN {exit !($COMP >= 4.0)}"; then GRADE="优秀"; COLOR="#10b981"; DESC="深度参与开源，项目质量高"
  elif awk "BEGIN {exit !($COMP >= 3.0)}"; then GRADE="合格"; COLOR="#f59e0b"; DESC="常规使用，有项目维护经验"
  elif awk "BEGIN {exit !($COMP >= 2.0)}"; then GRADE="初级"; COLOR="#f97316"; DESC="偶尔提交，个人小项目为主"
  else GRADE="入门"; COLOR="#ef4444"; DESC="极少公开活动"; fi

  QUALITY_DATA=$(jq '[.quality[]? | {name: (.repo | split("/")[1]), value: [.community.health_percentage, (if .community.has_readme then 100 else 0 end), (if .ci.has_status_checks then 100 else 0 end), (if .workflows.count > 0 then 100 else 0 end), (if .deployments.count > 0 then 100 else 0 end)]}]' "$DATA_FILE" 2>/dev/null || echo '[]')

  # ── 填充模板 ──
  sed \
    -e "s|{{AVATAR_URL}}|${AVATAR}|g" \
    -e "s|{{USERNAME}}|${USERNAME}|g" \
    -e "s|{{COMPOSITE_SCORE}}|${COMP}|g" \
    -e "s|{{SCORE_COLOR}}|${COLOR}|g" \
    -e "s|{{GRADE_LABEL}}|${GRADE}|g" \
    -e "s|{{GRADE_DESC}}|${DESC}|g" \
    -e "s|{{TAGS}}|${TAGS}|g" \
    -e "s|{{TECH_SCORE}}|${TECH}|g" \
    -e "s|{{ENGINEERING_SCORE}}|${ENG}|g" \
    -e "s|{{COLLAB_SCORE}}|${COLLAB}|g" \
    -e "s|{{INFLUENCE_SCORE}}|${INFLU}|g" \
    -e "s|{{TECH_PCT}}|$(awk "BEGIN {printf \"%.0f\", $TECH * 20}")|g" \
    -e "s|{{ENG_PCT}}|$(awk "BEGIN {printf \"%.0f\", $ENG * 20}")|g" \
    -e "s|{{COLLAB_PCT}}|$(awk "BEGIN {printf \"%.0f\", $COLLAB * 20}")|g" \
    -e "s|{{INFLU_PCT}}|$(awk "BEGIN {printf \"%.0f\", $INFLU * 20}")|g" \
    -e "s|{{SUMMARY}}|${SUMMARY}|g" \
    -e "s|{{CALENDAR_DATA}}|${CAL_DATA}|g" \
    -e "s|{{CALENDAR_MAX}}|${CAL_MAX}|g" \
    -e "s|{{CALENDAR_RANGE}}|${CAL_RANGE}|g" \
    -e "s|{{LANGUAGE_DATA}}|${LANG_DATA}|g" \
    -e "s|{{QUALITY_DATA}}|${QUALITY_DATA}|g" \
    "$TEMPLATE" > "$OUTPUT"

elif [ "$MODE" = "distill" ]; then
  # ── 蒸馏数据 ──
  DISTILLATE=$(jq -r '.distillate // ""' "$DATA_FILE")
  PERSONA=$(jq -r '.persona // ""' "$DATA_FILE")
  NATIVE_LANG=$(jq -r '.dna.native_language // ""' "$DATA_FILE")
  DOM_PARADIGM=$(jq -r '.dna.paradigm | to_entries | sort_by(-.value) | .[0].key // ""' "$DATA_FILE")
  SOCIAL_TEMP=$(jq -r '.dna.social_temperature // ""' "$DATA_FILE")
  PARADIGM_VALS=$(jq -r '[.dna.paradigm.Builder, .dna.paradigm.Learner, .dna.paradigm.Collector, .dna.paradigm.Hacker, .dna.paradigm.Explainer] | join(",")' "$DATA_FILE")

  # 社交温度分数
  FOLLOWERS=$(jq -r '.profile.followers // 0' "$DATA_FILE")
  SOCIAL_SCORE=$(awk "BEGIN {s=$FOLLOWERS; if(s>200) print 80; else if(s>50) print 50; else if(s>10) print 25; else print 5}")
  SOCIAL_LABEL=$(awk "BEGIN {s=$FOLLOWERS; if(s>200) print \"温带·有来有往\"; else if(s>50) print \"微暖·开始连接\"; else print \"冰点·尚未插上温度计\"}")

  # 隐藏自我卡片
  HIDDEN_CARDS=""
  HIDDEN_COUNT=$(jq '.hidden_self | length' "$DATA_FILE" 2>/dev/null || echo 0)
  for i in $(seq 0 $((HIDDEN_COUNT - 1))); do
    ITEM=$(jq -r ".hidden_self[$i]" "$DATA_FILE" 2>/dev/null || echo "")
    SIGNAL=$(echo "$ITEM" | cut -d'—' -f1 | xargs)
    INSIGHT=$(echo "$ITEM" | cut -d'—' -f2- | xargs)
    HIDDEN_CARDS+="<div class=\"hidden-card\"><div class=\"signal\">${SIGNAL}</div><div class=\"insight\">${INSIGHT}</div></div>"
  done

  # RPG
  RPG_CLASS=$(jq -r '.rpg.class // ""' "$DATA_FILE")
  RPG_LEVEL=$(jq -r '.rpg.level // ""' "$DATA_FILE")
  SKILL_MAJOR=$(jq -r '.rpg.skill_tree.major // ""' "$DATA_FILE")
  SKILL_MINOR=$(jq -r '.rpg.skill_tree.minor // ""' "$DATA_FILE")
  SKILL_HIDDEN=$(jq -r '.rpg.skill_tree.hidden // ""' "$DATA_FILE")
  TREASURE=$(jq -r '.rpg.inventory.treasure // ""' "$DATA_FILE")
  HIDDEN_GEM=$(jq -r '.rpg.inventory.hidden_gem // ""' "$DATA_FILE")
  PARTY_STATUS=$(jq -r '.rpg.party_status // ""' "$DATA_FILE")
  MAIN_QUEST=$(jq -r '.rpg.main_quest // ""' "$DATA_FILE")

  RPG_ICON="🛠️"
  case "$RPG_CLASS" in
    *机械*|*枪匠*) RPG_ICON="🔧" ;;
    *炼金*) RPG_ICON="⚗️" ;;
    *游侠*) RPG_ICON="🏹" ;;
    *法师*) RPG_ICON="🔮" ;;
    *骑士*) RPG_ICON="⚔️" ;;
  esac

  sed \
    -e "s|{{AVATAR_URL}}|${AVATAR}|g" \
    -e "s|{{USERNAME}}|${USERNAME}|g" \
    -e "s|{{DISTILLATE}}|${DISTILLATE}|g" \
    -e "s|{{NATIVE_LANGUAGE}}|${NATIVE_LANG}|g" \
    -e "s|{{DOMINANT_PARADIGM}}|${DOM_PARADIGM}|g" \
    -e "s|{{SOCIAL_TEMPERATURE}}|${SOCIAL_TEMP}|g" \
    -e "s|{{PERSONA}}|${PERSONA}|g" \
    -e "s|{{PARADIGM_VALUES}}|${PARADIGM_VALS}|g" \
    -e "s|{{CALENDAR_DATA}}|${CAL_DATA}|g" \
    -e "s|{{CALENDAR_MAX}}|${CAL_MAX}|g" \
    -e "s|{{CALENDAR_RANGE}}|${CAL_RANGE}|g" \
    -e "s|{{LANGUAGE_DATA}}|${LANG_DATA}|g" \
    -e "s|{{SOCIAL_SCORE}}|${SOCIAL_SCORE}|g" \
    -e "s|{{SOCIAL_LABEL}}|${SOCIAL_LABEL}|g" \
    -e "s|{{HIDDEN_SELF_CARDS}}|${HIDDEN_CARDS}|g" \
    -e "s|{{RPG_ICON}}|${RPG_ICON}|g" \
    -e "s|{{RPG_CLASS}}|${RPG_CLASS}|g" \
    -e "s|{{RPG_LEVEL}}|${RPG_LEVEL}|g" \
    -e "s|{{SKILL_MAJOR}}|${SKILL_MAJOR}|g" \
    -e "s|{{SKILL_MINOR}}|${SKILL_MINOR}|g" \
    -e "s|{{SKILL_HIDDEN}}|${SKILL_HIDDEN}|g" \
    -e "s|{{TREASURE}}|${TREASURE}|g" \
    -e "s|{{HIDDEN_GEM}}|${HIDDEN_GEM}|g" \
    -e "s|{{PARTY_STATUS}}|${PARTY_STATUS}|g" \
    -e "s|{{MAIN_QUEST}}|${MAIN_QUEST}|g" \
    "$TEMPLATE" > "$OUTPUT"
fi

echo "报告已生成: $OUTPUT"
echo "在浏览器中打开: file://$(echo "$OUTPUT" | sed 's|^/d|D:|' | sed 's|/|\\\\|g')"
