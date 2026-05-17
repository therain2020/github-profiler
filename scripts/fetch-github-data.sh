#!/usr/bin/env bash
# ============================================================================
# fetch-github-data.sh — 生产可用版 GitHub 用户数据抓取器
#
# 用法:
#   export GITHUB_TOKEN="ghp_xxxx"
#   ./fetch-github-data.sh <username>              # 输出到 output/<username>.json
#   ./fetch-github-data.sh <username> --force       # 强制刷新（忽略缓存）
#   ./fetch-github-data.sh <username> --stdout      # 输出到 stdout
#
# 特性:
#   - REST + GraphQL 混合策略，最大化利用 API 配额
#   - 自动速率限制监控与等待
#   - 网络重试（最多 3 次，指数退避）
#   - 幂等性：默认跳过已有结果，--force 强制刷新
#   - 完整错误处理与友好提示
#
# 环境变量:
#   GITHUB_TOKEN — GitHub Personal Access Token（必填）
# ============================================================================

set -euo pipefail

# ============================================================================
# 全局配置
# ============================================================================
readonly GITHUB_API_BASE="https://api.github.com"
readonly GITHUB_GRAPHQL_URL="${GITHUB_API_BASE}/graphql"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
readonly OUTPUT_DIR="${PROJECT_DIR}/output"
readonly MAX_RETRIES=3
readonly RETRY_DELAY_SEC=5
readonly RATE_LIMIT_BUFFER=50       # 剩余点数低于此值则等待
readonly GRAPHQL_MAX_REPOS=30       # GraphQL 单次拉取仓库数（避免过重）
readonly REST_REPOS_PER_PAGE=100    # REST 每页仓库数
readonly REPO_TARGET_COUNT=100      # 目标仓库总数

# 颜色输出（仅在终端中启用）
if [ -t 2 ]; then
  readonly RED='\033[0;31m'
  readonly YELLOW='\033[1;33m'
  readonly GREEN='\033[0;32m'
  readonly CYAN='\033[0;36m'
  readonly NC='\033[0m'  # No Color
else
  readonly RED='' YELLOW='' GREEN='' CYAN='' NC=''
fi

# ============================================================================
# 工具函数
# ============================================================================

# 带时间戳的日志输出（写入 stderr，不污染 stdout）
log()  { echo -e "[$(date '+%H:%M:%S')] $*" >&2; }
info() { log "${CYAN}[INFO]${NC} $*"; }
warn() { log "${YELLOW}[WARN]${NC} $*"; }
err()  { log "${RED}[ERROR]${NC} $*"; }
ok()   { log "${GREEN}[OK]${NC} $*"; }

# 向 GitHub API 发送请求，内置重试和速率处理
api_call() {
  local method="$1" url="$2" body="${3:-}" tmpfile curl_exit http_code
  tmpfile=$(mktemp)
  local curl_args=(-s -w "%{http_code}" -o "$tmpfile"
    -H "Authorization: Bearer ${GITHUB_TOKEN}"
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28"
  )

  [ "$method" != "GET" ] && curl_args+=(-X "$method")
  [ -n "$body" ] && curl_args+=(-d "$body")
  curl_args+=("$url")

  for attempt in $(seq 1 $MAX_RETRIES); do
    http_code=$(curl "${curl_args[@]}" 2>/dev/null)
    curl_exit=$?

    if [ $curl_exit -eq 0 ]; then
      # 网络成功，检查 HTTP 状态码
      if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        cat "$tmpfile"
        rm -f "$tmpfile"
        return 0
      elif [ "$http_code" -eq 429 ] || [ "$http_code" -eq 403 ]; then
        # 速率限制或临时封禁
        retry_after=$(grep -i 'retry-after:' "$tmpfile" 2>/dev/null | awk '{print $2}' | tr -d '\r' || echo "60")
        retry_after=${retry_after:-60}
        warn "速率限制触发，等待 ${retry_after} 秒后重试..."
        sleep "$retry_after"
      elif [ "$http_code" -ge 500 ]; then
        # 服务端错误，可重试
        warn "服务端错误 HTTP $http_code，第 $attempt/$MAX_RETRIES 次尝试"
        [ $attempt -lt $MAX_RETRIES ] && sleep $((RETRY_DELAY_SEC * attempt))
      elif [ "$http_code" -eq 404 ]; then
        err "资源不存在 (HTTP 404): $url"
        rm -f "$tmpfile"
        return 1
      else
        err "API 返回 HTTP $http_code: $url"
        cat "$tmpfile" >&2
        rm -f "$tmpfile"
        return 1
      fi
    else
      # 网络错误
      warn "网络错误 (curl exit=$curl_exit)，第 $attempt/$MAX_RETRIES 次尝试"
      [ $attempt -lt $MAX_RETRIES ] && sleep $((RETRY_DELAY_SEC * attempt))
    fi
  done

  err "请求失败，已重试 $MAX_RETRIES 次: $url"
  rm -f "$tmpfile"
  return 1
}

graphql_call() {
  local query_text="$1"
  # 将查询转为单行 JSON 字符串
  local gql_body
  gql_body=$(jq -n --arg q "$query_text" '{query: $q}')
  api_call "POST" "$GITHUB_GRAPHQL_URL" "$gql_body"
}

# 单次查询所有速率限制信息（/rate_limit 一次性返回所有资源配额）
check_rate_limits() {
  local resp
  resp=$(api_call "GET" "${GITHUB_API_BASE}/rate_limit") || {
    warn "无法检查速率限制，继续尝试..."
    echo "9999 0 9999 0"
    return 0
  }
  local core_rem core_reset gql_rem gql_reset
  core_rem=$(echo "$resp" | jq -r '.resources.core.remaining // 9999')
  core_reset=$(echo "$resp" | jq -r '.resources.core.reset // 0')
  gql_rem=$(echo "$resp" | jq -r '.resources.graphql.remaining // 9999')
  gql_reset=$(echo "$resp" | jq -r '.resources.graphql.reset // 0')
  echo "$core_rem $core_reset $gql_rem $gql_reset"
}

# 等待速率限制重置
wait_for_rate_reset() {
  local reset_ts="$1" label="${2:-速率限制}"
  local now wait_sec
  now=$(date +%s)
  wait_sec=$((reset_ts - now + 5))

  if [ "$wait_sec" -le 0 ]; then
    info "${label} 已重置，继续执行"
    return 0
  fi

  if [ "$wait_sec" -gt 300 ]; then
    err "${label} 需等待 ${wait_sec} 秒 (>5分钟)，终止执行以免挂死"
    err "请稍后重试，或更换 Token"
    return 1
  fi

  warn "${label} 不足，等待 ${wait_sec} 秒直至重置..."
  sleep "$wait_sec"
  info "等待结束，继续执行"
  return 0
}

# 通用速率配额保障（core=1使用REST配额, graphql=1使用GraphQL配额）
ensure_rate_quota() {
  local needed="${1:-10}" type="${2:-core}" label="${3:-API}"
  local rate_info
  rate_info=$(check_rate_limits) || return 1

  local remained reset
  if [ "$type" = "graphql" ]; then
    read -r _ _ remained reset <<< "$rate_info"
  else
    read -r remained reset _ _ <<< "$rate_info"
  fi

  info "${label} 剩余 ${remained}"

  if [ "$remained" -lt "$RATE_LIMIT_BUFFER" ]; then
    if ! wait_for_rate_reset "$reset" "$label"; then
      return 1
    fi
  elif [ "$remained" -lt "$needed" ]; then
    warn "${label} 剩余 ${remained} < 所需 ${needed}，等待重置"
    if ! wait_for_rate_reset "$reset" "$label"; then
      return 1
    fi
  fi
  return 0
}

# ============================================================================
# 数据获取函数（各阶段独立，便于错误隔离）
# ============================================================================

fetch_user_profile() {
  local username="$1"
  info "获取用户基本资料: $username"

  local resp
  resp=$(api_call "GET" "${GITHUB_API_BASE}/users/${username}") || return 1

  echo "$resp" | jq '{
    login,
    name,
    bio,
    company,
    location,
    blog,
    avatar_url,
    email,
    twitter_username,
    created_at,
    updated_at,
    hireable: .hireable,
    public_repos,
    public_gists,
    followers,
    following
  }'
}

fetch_repos_rest() {
  local username="$1"
  local max_repos="${2:-$REPO_TARGET_COUNT}"
  info "获取仓库列表（目标: 前 ${max_repos} 个，按星标排序）"

  local all_repos='[]' page=1
  # 开始前检查配额（最多 2 页，预留 3 次调用）
  ensure_rate_quota 3 core "REST" || return 1

  while true; do
    local remaining=$((max_repos - $(echo "$all_repos" | jq 'length')))
    [ "$remaining" -le 0 ] && break

    local per_page=$([ "$remaining" -gt $REST_REPOS_PER_PAGE ] && echo $REST_REPOS_PER_PAGE || echo $remaining)
    info "  获取仓库: 第 ${page} 页 (per_page=${per_page})"

    local page_data
    page_data=$(api_call "GET" \
      "${GITHUB_API_BASE}/users/${username}/repos?per_page=${per_page}&sort=stars&direction=desc&page=${page}") || return 1

    local count
    count=$(echo "$page_data" | jq 'length')
    [ "$count" -eq 0 ] && break  # 无更多数据

    # 提取关键字段，精简输出
    local slim_page
    slim_page=$(echo "$page_data" | jq '[.[] | {
      id,
      name,
      full_name,
      description,
      html_url,
      homepage,
      language,
      stargazers_count,
      forks_count,
      open_issues_count,
      license: (.license.spdx_id // null),
      fork,
      archived,
      topics: (.topics // []),
      created_at,
      updated_at,
      pushed_at
    }]')

    all_repos=$(echo "$all_repos" "$slim_page" | jq -s '.[0] + .[1]')
    page=$((page + 1))

    # 如果返回的少于请求的，说明已经到末尾
    [ "$count" -lt "$per_page" ] && break
    # 安全上限：最多 3 页（300 个仓库）
    [ "$page" -gt 3 ] && break
  done

  local final_count
  final_count=$(echo "$all_repos" | jq 'length')
  ok "共获取 ${final_count} 个仓库"

  echo "$all_repos"
}

fetch_orgs() {
  local username="$1"
  info "获取组织列表: $username"

  local resp
  resp=$(api_call "GET" "${GITHUB_API_BASE}/users/${username}/orgs") || return 1

  echo "$resp" | jq '[.[] | { login, id, avatar_url, description }]'
}

# ============================================================================
# GraphQL 查询 — 拆分为两个轻量查询，控制单查询成本
# ============================================================================

fetch_contributions_graphql() {
  local username="$1"
  info "获取贡献统计（GraphQL）"

  ensure_rate_quota 20 graphql "GraphQL" || return 1

  # 用 heredoc 定义查询（不含变量展开）
  local query
  read -r -d '' query << 'ENDGQL' || true
query($login: String!) {
  user(login: $login) {
    contributionsCollection {
      totalCommitContributions
      totalIssueContributions
      totalPullRequestContributions
      totalPullRequestReviewContributions
      restrictedContributionsCount
      hasActivityInThePast

      contributionCalendar {
        totalContributions
        weeks {
          contributionDays {
            contributionCount
            date
            color
          }
        }
      }

      commitContributionsByRepository(maxRepositories: 50) {
        repository {
          nameWithOwner
        }
        contributions(first: 1) {
          totalCount
        }
      }

      pullRequestContributionsByRepository(maxRepositories: 50) {
        repository {
          nameWithOwner
        }
        contributions(first: 1) {
          totalCount
        }
      }
    }
  }
}
ENDGQL

  local resp
  resp=$(graphql_call "$query") || return 1

  # 检查 GraphQL 层面的错误
  if echo "$resp" | jq -e '.errors' > /dev/null 2>&1; then
    local gql_err
    gql_err=$(echo "$resp" | jq -r '.errors[0].message // "Unknown GraphQL error"')
    err "GraphQL 贡献查询错误: $gql_err"
    return 1
  fi

  if echo "$resp" | jq -e '.data.user == null' > /dev/null 2>&1; then
    err "用户 $username 不存在（GraphQL 返回 null）"
    return 1
  fi

  echo "$resp" | jq '{
    total_commit_contributions: .data.user.contributionsCollection.totalCommitContributions,
    total_issue_contributions: .data.user.contributionsCollection.totalIssueContributions,
    total_pr_contributions: .data.user.contributionsCollection.totalPullRequestContributions,
    total_review_contributions: .data.user.contributionsCollection.totalPullRequestReviewContributions,
    restricted_contributions: .data.user.contributionsCollection.restrictedContributionsCount,
    calendar: {
      total: .data.user.contributionsCollection.contributionCalendar.totalContributions,
      weeks: [.data.user.contributionsCollection.contributionCalendar.weeks[] | {
        days: [.contributionDays[] | {
          count: .contributionCount,
          date,
          color
        }]
      }]
    },
    top_commit_repos: [.data.user.contributionsCollection.commitContributionsByRepository[] | {
      repo: .repository.nameWithOwner,
      commits: .contributions[0].totalCount
    }],
    top_pr_repos: [.data.user.contributionsCollection.pullRequestContributionsByRepository[] | {
      repo: .repository.nameWithOwner,
      prs: .contributions[0].totalCount
    }]
  }'
}

fetch_activity_graphql() {
  local username="$1"
  info "获取最近 PR 和 Issue 活动（GraphQL）"

  ensure_graphql_quota 20 || return 1

  local query
  read -r -d '' query << 'ENDGQL' || true
query($login: String!) {
  user(login: $login) {
    pullRequests(first: 30, orderBy: {field: CREATED_AT, direction: DESC}) {
      totalCount
      nodes {
        title
        state
        merged
        createdAt
        mergedAt
        closedAt
        repository { nameWithOwner }
      }
    }
    issues(first: 30, orderBy: {field: CREATED_AT, direction: DESC}) {
      totalCount
      nodes {
        title
        state
        createdAt
        closedAt
        repository { nameWithOwner }
      }
    }
  }
}
ENDGQL

  local resp
  resp=$(graphql_call "$query") || return 1

  if echo "$resp" | jq -e '.errors' > /dev/null 2>&1; then
    local gql_err
    gql_err=$(echo "$resp" | jq -r '.errors[0].message // "Unknown GraphQL error"')
    err "GraphQL 活动查询错误: $gql_err"
    return 1
  fi

  echo "$resp" | jq '{
    pull_requests: {
      total_count: .data.user.pullRequests.totalCount,
      items: [.data.user.pullRequests.nodes[] | {
        title,
        state,
        merged,
        repo: .repository.nameWithOwner,
        created_at: .createdAt,
        merged_at: .mergedAt,
        closed_at: .closedAt
      }]
    },
    issues: {
      total_count: .data.user.issues.totalCount,
      items: [.data.user.issues.nodes[] | {
        title,
        state,
        repo: .repository.nameWithOwner,
        created_at: .createdAt,
        closed_at: .closedAt
      }]
    }
  }'
}

# ============================================================================
# 汇总与输出
# ============================================================================

# 将所有阶段的数据合并为最终 JSON
merge_output() {
  local profile_json="$1"
  local repos_json="$2"
  local orgs_json="$3"
  local contrib_json="$4"
  local activity_json="$5"
  local username="$6"

  jq -n \
    --argjson profile "$profile_json" \
    --argjson repos "$repos_json" \
    --argjson orgs "$orgs_json" \
    --argjson contrib "$contrib_json" \
    --argjson activity "$activity_json" \
    --arg username "$username" \
    --arg fetched_at "$(date -Iseconds)" \
    '{
      meta: {
        username: $username,
        fetched_at: $fetched_at,
        version: "2.0.0"
      },
      profile: $profile,
      repositories: $repos,
      organizations: $orgs,
      contributions: $contrib,
      activity: $activity
    }'
}

# ============================================================================
# 主流程
# ============================================================================

main() {
  local username="" force=false to_stdout=false

  # 解析命令行参数
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f) force=true; shift ;;
      --stdout|-s) to_stdout=true; shift ;;
      --help|-h)
        echo "用法: $0 <username> [--force] [--stdout]"
        echo ""
        echo "环境变量:"
        echo "  GITHUB_TOKEN — GitHub Personal Access Token（必填）"
        echo ""
        echo "选项:"
        echo "  --force, -f   强制刷新（忽略已有缓存文件）"
        echo "  --stdout, -s  输出 JSON 到 stdout（同时保存到文件）"
        echo "  --help, -h    显示此帮助"
        exit 0
        ;;
      *) username="$1"; shift ;;
    esac
  done

  # 参数校验
  if [ -z "$username" ]; then
    err "缺少用户名参数。用法: $0 <username>"
    exit 1
  fi

  # Token 校验
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    err "环境变量 GITHUB_TOKEN 未设置。"
    err "请前往 https://github.com/settings/tokens 创建 Token（无需任何权限 scope）"
    err "然后执行: export GITHUB_TOKEN=\"ghp_xxxx\""
    exit 1
  fi

  # 验证 Token 格式（ghp_ 或 github_pat_ 开头）
  if ! [[ "$GITHUB_TOKEN" =~ ^(ghp_|github_pat_) ]]; then
    warn "GITHUB_TOKEN 格式可能不正确。GitHub 令牌通常以 'ghp_' 或 'github_pat_' 开头"
    warn "如果后续请求全部失败，请检查 Token"
  fi

  # 检查依赖
  for cmd in curl jq; do
    if ! command -v "$cmd" &>/dev/null; then
      err "缺少依赖: $cmd。请先安装。"
      exit 1
    fi
  done

  # 创建输出目录
  mkdir -p "$OUTPUT_DIR"
  local output_file="${OUTPUT_DIR}/${username}.json"

  # 幂等性检查 — 除非 --force，否则跳过已有结果
  if [ -f "$output_file" ] && [ "$force" != true ]; then
    local file_age
    file_age=$(($(date +%s) - $(stat -c %Y "$output_file" 2>/dev/null || stat -f %m "$output_file" 2>/dev/null || echo 0)))
    if [ "$file_age" -lt 86400 ]; then  # 24 小时内
      info "输出文件已存在且是 24 小时内的新鲜数据: $output_file"
      info "跳过数据获取。如需强制刷新，使用 --force 选项"
      if [ "$to_stdout" = true ]; then
        cat "$output_file"
      fi
      exit 0
    else
      info "输出文件已存在但已超过 24 小时，自动刷新"
    fi
  fi

  if [ "$force" = true ]; then
    info "强制刷新模式，忽略已有缓存"
  fi

  # ========================================================================
  # 顺序执行各阶段
  # ========================================================================

  # --- 阶段1: 用户资料 (REST, 1 call) ---
  local profile_json
  profile_json=$(fetch_user_profile "$username") || {
    err "无法获取用户 $username 的资料。请确认用户名正确或 Token 是否有效。"
    exit 4
  }
  ok "阶段1/5: 用户资料获取完成"

  # --- 阶段2: 仓库列表 (REST 分页, 最多 3 calls) ---
  local repos_json
  repos_json=$(fetch_repos_rest "$username" "$REPO_TARGET_COUNT") || {
    err "无法获取仓库列表"
    exit 4
  }
  ok "阶段2/5: 仓库列表获取完成"

  # --- 阶段3: 组织 (REST, 1 call) ---
  local orgs_json
  orgs_json=$(fetch_orgs "$username") || {
    warn "无法获取组织列表，使用空数组"
    orgs_json='[]'
  }
  ok "阶段3/5: 组织列表获取完成"

  # --- 阶段4: 贡献统计 (GraphQL) ---
  local contrib_json
  contrib_json=$(fetch_contributions_graphql "$username") || {
    warn "GraphQL 贡献查询失败，使用降级方案..."
    contrib_json=$(jq -n '{
      total_commit_contributions: null,
      total_issue_contributions: null,
      total_pr_contributions: null,
      total_review_contributions: null,
      restricted_contributions: null,
      calendar: { total: null, weeks: [] },
      top_commit_repos: [],
      top_pr_repos: []
    }')
  }
  ok "阶段4/5: 贡献统计获取完成"

  # --- 阶段5: PR + Issue (GraphQL) ---
  local activity_json
  activity_json=$(fetch_activity_graphql "$username") || {
    warn "GraphQL 活动查询失败，使用降级方案..."
    activity_json=$(jq -n '{
      pull_requests: { total_count: null, items: [] },
      issues: { total_count: null, items: [] }
    }')
  }
  ok "阶段5/5: 活动数据获取完成"

  # ========================================================================
  # 汇总输出
  # ========================================================================
  info "汇总所有数据..."

  local final_json
  final_json=$(merge_output "$profile_json" "$repos_json" "$orgs_json" "$contrib_json" "$activity_json" "$username")

  echo "$final_json" | jq '.' > "$output_file"
  ok "数据已保存至: $output_file"

  local file_size
  file_size=$(wc -c < "$output_file" | tr -d ' ')
  if [ "$file_size" -gt 50000 ]; then
    warn "输出文件较大 (${file_size} bytes)，可能需要精简后再喂给 AI 分析"
  fi

  if [ "$to_stdout" = true ]; then
    echo "$final_json" | jq '.'
  fi

  # 最终速率统计（单次查询覆盖所有资源）
  local rate_info
  rate_info=$(check_rate_limits 2>/dev/null || echo "? 0 ? 0")
  local core_rem core_reset gql_rem gql_reset
  read -r core_rem core_reset gql_rem gql_reset <<< "$rate_info"

  echo ""
  info "======== 执行完成 ========"
  info "输出文件: ${output_file}"
  info "REST 剩余: ${core_rem:-?} 次   GraphQL 剩余: ${gql_rem:-?} 分"
  info "=========================="
}

# ============================================================================
# 入口
# ============================================================================
main "$@"
