#!/usr/bin/env bash
# ============================================================================
# setup.sh — GitHub Token 一键配置
#
# 自动检测环境并用最佳方式配置 GITHUB_TOKEN：
#   1. gh CLI 已认证 → 复用 gh auth token（推荐，零手动操作）
#   2. 已有环境变量   → 直接使用
#   3. 无 gh         → 引导 gh auth login 或手动创建 Token
#
# 用法:
#   bash scripts/setup.sh              # 当前 shell 生效
#   source scripts/setup.sh            # 持久化到 shell 配置文件
# ============================================================================

set -uo pipefail
# 不用 -e（errexit）：Token 验证和引导流程有多种非致命路径

RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[1;33m' CYAN='\033[0;36m' NC='\033[0m'
info()  { echo -e "${CYAN}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[OK]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERROR]${NC} $*"; }

TOKEN=""
PERSIST=false

# 解析参数
while [ $# -gt 0 ]; do
  case "$1" in
    --persist|-p) PERSIST=true; shift ;;
    --help|-h)
      echo "用法: bash scripts/setup.sh [--persist]"
      echo ""
      echo "  --persist, -p   将 Token 持久化到 shell 配置文件（~/.bashrc 等）"
      echo ""
      echo "自动检测顺序: gh CLI > 环境变量 > 手动输入"
      exit 0
      ;;
    *) shift ;;
  esac
done

echo ""
echo "============================================"
echo "  GitHub Profiler — Token 一键配置"
echo "============================================"
echo ""

# 方案1：复用 gh CLI 的认证（最优，零操作）
if command -v gh &>/dev/null; then
  if gh auth status &>/dev/null; then
    TOKEN=$(gh auth token 2>/dev/null || echo "")
    if [ -n "$TOKEN" ]; then
      ok "检测到 gh CLI 已认证，直接复用 Token"
      info "Token 前缀: ${TOKEN:0:10}..."
    fi
  fi
fi

# 方案2：检查环境变量
if [ -z "$TOKEN" ] && [ -n "${GITHUB_TOKEN:-}" ]; then
  TOKEN="$GITHUB_TOKEN"
  ok "使用已有的 GITHUB_TOKEN 环境变量"
fi

# 方案3：引导用户创建
if [ -z "$TOKEN" ]; then
  echo ""
  warn "未检测到 gh CLI 认证或 GITHUB_TOKEN 环境变量"
  echo ""
  echo "选择配置方式:"
  echo "  [1] gh auth login — 交互式 OAuth 登录（推荐，一条命令完成）"
  echo "  [2] 手动创建 Token — 打开浏览器，复制粘贴"
  echo "  [3] 直接粘贴已有 Token"
  echo ""
  read -r -p "请输入选项 (1/2/3): " choice

  case "$choice" in
    1)
      info "启动 gh auth login..."
      gh auth login --hostname github.com --web --git-protocol https
      if gh auth status &>/dev/null; then
        TOKEN=$(gh auth token 2>/dev/null || echo "")
        ok "gh CLI 认证成功！"
      else
        err "gh auth login 失败，请重试"
        exit 1
      fi
      ;;
    2)
      TOKEN_URL="https://github.com/settings/tokens/new?description=github-profiler&scopes="
      info "正在打开浏览器: $TOKEN_URL"
      info "Token 无需任何权限 scope（仅访问公开数据）"
      # 跨平台打开浏览器
      if command -v xdg-open &>/dev/null; then
        xdg-open "$TOKEN_URL" 2>/dev/null || true
      elif command -v open &>/dev/null; then
        open "$TOKEN_URL" 2>/dev/null || true
      elif command -v start &>/dev/null; then
        start "$TOKEN_URL" 2>/dev/null || true
      fi
      echo ""
      read -r -p "粘贴生成的 Token: " TOKEN
      ;;
    3)
      read -r -p "粘贴 Token: " TOKEN
      ;;
    *)
      err "无效选项"
      exit 1
      ;;
  esac
fi

# 最终验证
if [ -z "$TOKEN" ]; then
  err "Token 为空，配置失败"
  exit 1
fi

export GITHUB_TOKEN="$TOKEN"

# 验证 Token 是否有效
info "验证 Token..."
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -H "Authorization: Bearer $TOKEN" "https://api.github.com/user" 2>/dev/null || echo "000")

if [ "$HTTP_CODE" = "200" ]; then
  AUTH_USER=$(curl -s -H "Authorization: Bearer $TOKEN" "https://api.github.com/user" 2>/dev/null | grep -o '"login":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
  ok "Token 有效！已认证为: ${AUTH_USER:-unknown}"
elif [ "$HTTP_CODE" = "401" ]; then
  warn "Token 验证返回 401（可能 gh CLI token 无法直接用于 API）"
  warn "如果 fetch-github-data.sh 运行失败，请用方案2/3手动创建 Token"
else
  warn "无法验证 Token (HTTP $HTTP_CODE)，将尝试继续使用"
fi

# 持久化
if [ "$PERSIST" = true ]; then
  echo ""
  info "持久化 Token 到 shell 配置文件..."

  # 检测当前 shell 类型
  SHELL_RC=""
  case "$(basename "${SHELL:-}")" in
    zsh)  SHELL_RC="$HOME/.zshrc" ;;
    bash) SHELL_RC="$HOME/.bashrc" ;;
    *)    SHELL_RC="$HOME/.bashrc" ;;
  esac

  # Windows 特殊处理
  if [[ "$(uname -s)" =~ MINGW|MSYS|CYGWIN ]] || [ -n "${WINDIR:-}" ]; then
    # Git Bash / MSYS2 环境
    SHELL_RC="$HOME/.bashrc"
    info "Windows 环境，将写入 $SHELL_RC"
  fi

  # 移除旧的 GITHUB_TOKEN 行（如果存在）
  if [ -f "$SHELL_RC" ]; then
    if grep -q "GITHUB_TOKEN" "$SHELL_RC" 2>/dev/null; then
      # 用 sed 替换旧行
      if [[ "$(uname -s)" == "Darwin" ]]; then
        sed -i '' '/export GITHUB_TOKEN=/d' "$SHELL_RC"
      else
        sed -i '/export GITHUB_TOKEN=/d' "$SHELL_RC"
      fi
    fi
  fi

  echo "export GITHUB_TOKEN=\"$TOKEN\"" >> "$SHELL_RC"
  ok "Token 已写入 $SHELL_RC"
  info "重启终端或执行 'source $SHELL_RC' 即可生效"
else
  echo ""
  info "Token 已在当前 shell 生效（未持久化）"
  info "如需持久化，运行: bash scripts/setup.sh --persist"
fi

echo ""
echo "============================================"
echo "  配置完成！现在可以运行:"
echo "  bash scripts/fetch-github-data.sh <username>"
echo "============================================"
