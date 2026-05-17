#!/usr/bin/env bash
# extract-github-data.sh — 提取有效信息，精简 fetch 产物
# 用法: bash scripts/extract-github-data.sh <username>
set -euo pipefail

username="${1:?Usage: $0 <username>}"
input="output/${username}.json"

if [ ! -f "$input" ]; then
  echo "[ERROR] $input 不存在，请先运行 /github-fetch $username"
  exit 1
fi

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
before=$(wc -c < "$input" | tr -d ' ')

python "${project_dir}/scripts/_extract.py" "$input" "${input}.tmp"
mv "${input}.tmp" "$input"

after=$(wc -c < "$input" | tr -d ' ')
echo "[OK] $input: ${before} → ${after} bytes (-$(( (before - after) * 100 / before ))%)"
