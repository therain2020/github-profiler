#!/usr/bin/env bash
# ============================================================================
# fetch-github-data.sh v2.3.0 — GitHub 用户数据抓取器（深度内容版）
#
# 用法:
#   export GITHUB_TOKEN="ghp_xxxx"
#   ./fetch-github-data.sh <username>              # 输出到 output/<username>.json
#   ./fetch-github-data.sh <username> --force       # 强制刷新（忽略缓存）
#   ./fetch-github-data.sh <username> --stdout      # 输出到 stdout
#   ./fetch-github-data.sh <username> --private     # 读取私有仓库（需repo scope）
#   ./fetch-github-data.sh --private                # 自动检测+读取私有仓库
#
# 特性:
#   - REST + GraphQL 混合策略，最大化利用 API 配额
#   - 自动速率限制监控与等待
#   - 网络重试（最多 3 次，指数退避）
#   - 幂等性：默认跳过已有结果，--force 强制刷新
#   - 完整错误处理与友好提示
#   - --private 模式：读取 Token 所属用户的私有仓库
#
# 环境变量:
#   GITHUB_TOKEN — GitHub Personal Access Token（必填；--private 需 repo 权限）
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
# 有 Token 时缓冲较高（配额 5000/hr），无 Token 时降低（配额 60/hr）
RATE_LIMIT_BUFFER=50
[ -z "${GITHUB_TOKEN:-}" ] && RATE_LIMIT_BUFFER=5
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
    -H "Accept: application/vnd.github+json"
    -H "X-GitHub-Api-Version: 2022-11-28"
  )
  # 有 Token 时才添加认证头（无 Token 使用无认证访问，配额 60 次/小时）
  [ -n "${GITHUB_TOKEN:-}" ] && curl_args+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")

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
  local query_text="$1" username="${2:-}"
  local gql_body
  gql_body=$(jq -n --arg q "$query_text" --arg u "$username" '{query: $q, variables: {login: $u}}')
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
  local private_mode="${3:-false}"
  info "获取仓库列表（目标: 前 ${max_repos} 个，按星标排序${private_mode:+，含私有仓库}）"

  local all_repos='[]' page=1
  # 开始前检查配额（最多 2 页，预留 3 次调用）
  ensure_rate_quota 3 core "REST" || return 1

  while true; do
    local remaining=$((max_repos - $(echo "$all_repos" | jq 'length')))
    [ "$remaining" -le 0 ] && break

    local per_page=$([ "$remaining" -gt $REST_REPOS_PER_PAGE ] && echo $REST_REPOS_PER_PAGE || echo $remaining)
    info "  获取仓库: 第 ${page} 页 (per_page=${per_page})"

    local page_data repo_url
    if [ "$private_mode" = true ]; then
      repo_url="${GITHUB_API_BASE}/user/repos?type=all&sort=updated&direction=desc&per_page=${per_page}&page=${page}"
    else
      repo_url="${GITHUB_API_BASE}/users/${username}/repos?per_page=${per_page}&sort=stars&direction=desc&page=${page}"
    fi
    page_data=$(api_call "GET" "$repo_url") || return 1

    local count
    count=$(echo "$page_data" | jq 'length')
    [ "$count" -eq 0 ] && break  # 无更多数据

    # 提取关键字段，精简输出
    local slim_page
    slim_page=$(echo "$page_data" | jq '[.[] | {
      name, full_name, description, html_url,
      language, stargazers_count, forks_count,
      fork, private: (.private // false), topics: (.topics // []), pushed_at
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

# 仓库深度内容抓取（替代旧的质量快照）
# 对 Top N 自有仓库抓取：README 全文 + 用户 commit message（仅文本，不含代码 diff）+ 用户 issue
# 并行执行，30 次 API 调用，占配额 0.6%
fetch_repo_deep_dive() {
  local repos_json="$1" username="$2"
  local top_n="${3:-10}"

  # 过滤自有仓库（非 Fork），取前 top_n 个
  local repo_array
  repo_array=$(echo "$repos_json" | jq -r "[.[] | select(.fork == false)] | .[0:$top_n] | [.[].full_name] | .[]" | sed 's/\r$//')

  if [ -z "$repo_array" ]; then
    echo '[]'
    return 0
  fi

  local -a repos=()
  while IFS= read -r line; do
    [ -n "$line" ] && repos+=("$line")
  done <<< "$repo_array"

  local total=${#repos[@]}
  info "深度抓取 ${total} 个自有仓库（README + commit message + issue）..."

  local q_tmp_dir
  q_tmp_dir=$(mktemp -d)

  local launched=0
  for full_name in "${repos[@]}"; do
    (
      local owner="${full_name%%/*}" repo="${full_name##*/}"

      # 1. README（base64 解码，截取前 16KB 防止超大文档）
      local readme_text="" readme_size=0
      local readme_resp
      readme_resp=$(api_call "GET" "${GITHUB_API_BASE}/repos/${full_name}/readme" 2>/dev/null || echo '{}')
      if echo "$readme_resp" | jq -e '.content' > /dev/null 2>&1; then
        readme_text=$(echo "$readme_resp" | python -c "import sys,json,base64; d=json.load(sys.stdin); c=d.get('content',''); print(base64.b64decode(c).decode('utf-8','replace')[:16384]) if c else ''" 2>/dev/null)
        readme_size=$(echo "$readme_resp" | jq -r '.size // 0')
      fi

      # 2. 用户 commit message（仅 message + date，不含代码 diff/files）
      local commits_json='[]' commit_count=0
      local commits_resp
      commits_resp=$(api_call "GET" "${GITHUB_API_BASE}/repos/${full_name}/commits?author=${username}&per_page=30" 2>/dev/null || echo '[]')
      commit_count=$(echo "$commits_resp" | jq 'length')
      if [ "$commit_count" -gt 0 ]; then
        # 只提取 message headline + author date，不抓取代码 diff/文件变更
        commits_json=$(echo "$commits_resp" | jq '[.[] | {message: .commit.message, date: .commit.author.date}]')
      fi

      # 3. 用户 issues（search API 按作者过滤）
      local issues_json='[]' issue_count=0
      local issues_resp
      issues_resp=$(api_call "GET" "${GITHUB_API_BASE}/search/issues?q=repo:${full_name}+author:${username}+type:issue&per_page=10" 2>/dev/null || echo '{}')
      issue_count=$(echo "$issues_resp" | jq -r '.total_count // 0')
      if [ "$issue_count" -gt 0 ]; then
        issues_json=$(echo "$issues_resp" | jq '[.items[] | {title, state, created_at, updated_at}]')
      fi

      # 计算质量指标（供渲染报告使用）
      local has_readme=0
      [ -n "$readme_text" ] && has_readme=100
      local avg_msg_len=0
      if [ "$commit_count" -gt 0 ]; then
        avg_msg_len=$(echo "$commits_json" | jq '[.[].message | length] | add / length | floor')
      fi
      local issue_score=0
      [ "$issue_count" -gt 0 ] && issue_score=100

      jq -n \
        --arg repo "$full_name" \
        --arg readme "$readme_text" \
        --argjson readme_size "$readme_size" \
        --argjson commits "$commits_json" \
        --argjson commit_count "$commit_count" \
        --argjson issues "$issues_json" \
        --argjson issue_count "$issue_count" \
        --argjson has_readme "$has_readme" \
        --argjson avg_msg_len "$avg_msg_len" \
        --argjson issue_score "$issue_score" \
        '{
          repo: $repo,
          readme: $readme,
          readme_size: $readme_size,
          commits: $commits,
          commit_count: $commit_count,
          issues: $issues,
          issue_count: $issue_count,
          quality: {
            has_readme: $has_readme,
            readme_bytes: $readme_size,
            commit_count: $commit_count,
            avg_commit_msg_len: $avg_msg_len,
            issue_count: $issue_count
          }
        }' > "${q_tmp_dir}/${owner}___${repo}.json"
    ) &

    if [ $(( (launched + 1) % 3 )) -eq 0 ]; then
      sleep 0.5
    fi
    ((launched++))
  done

  # 等待完成
  local progress=0
  while [ $progress -lt $total ]; do
    sleep 2
    progress=$(find "$q_tmp_dir" -name '*.json' 2>/dev/null | wc -l | tr -d ' ')
    printf "\r  [进度] %d/%d 个仓库深度抓取完成..." "$progress" "$total" >&2
  done
  echo "" >&2
  ok "所有仓库深度抓取完成"

  # 按顺序收集
  local results="["
  local first=true
  for full_name in "${repos[@]}"; do
    [ "$first" = true ] && first=false || results+=","
    local f="${q_tmp_dir}/${full_name//\//___}.json"
    if [ -f "$f" ]; then
      results+=$(<"$f")
    else
      results+="{\"repo\":\"$full_name\",\"error\":\"deep dive failed\"}"
    fi
  done
  results+="]"

  rm -rf "$q_tmp_dir"
  echo "$results"
}

# 用户公开 Gists（利用 gist 权限 — 补充技术兴趣信号）
fetch_user_gists() {
  local username="$1"
  info "获取用户公开 Gists: $username"

  local resp
  resp=$(api_call "GET" "${GITHUB_API_BASE}/users/${username}/gists?per_page=30") || {
    echo '[]'
    return 0
  }

  echo "$resp" | jq '[.[] | {
    id, description,
    files: ([.files | to_entries[].value | {filename, language, size}]),
    public,
    created_at,
    updated_at,
    comments
  }]'
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
  resp=$(graphql_call "$query" "$username") || return 1

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
      commits: .contributions.totalCount
    }],
    top_pr_repos: [.data.user.contributionsCollection.pullRequestContributionsByRepository[] | {
      repo: .repository.nameWithOwner,
      prs: .contributions.totalCount
    }]
  }'
}

fetch_activity_graphql() {
  local username="$1"
  info "获取最近 PR 和 Issue 活动（GraphQL）"

  ensure_rate_quota 20 graphql "GraphQL" || return 1

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
  resp=$(graphql_call "$query" "$username") || return 1

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

# 将所有阶段的数据合并为最终 JSON（通过临时文件避免参数过长）
# 各阶段文件统一存放在 $tmp_dir 下，按固定命名约定读取
merge_output() {
  local tmp_dir="$1" username="$2"

  jq -n \
    --slurpfile profile   "${tmp_dir}/profile.json" \
    --slurpfile repos     "${tmp_dir}/repos.json" \
    --slurpfile orgs      "${tmp_dir}/orgs.json" \
    --slurpfile contrib   "${tmp_dir}/contrib.json" \
    --slurpfile activity  "${tmp_dir}/activity.json" \
    --slurpfile deep_dive "${tmp_dir}/deep_dive.json" \
    --slurpfile gists     "${tmp_dir}/gists.json" \
    --arg username "$username" \
    --arg fetched_at "$(date -Iseconds)" \
    '{
      meta: { username: $username, fetched_at: $fetched_at, version: "2.2.0" },
      profile: $profile[0],
      repositories: $repos[0],
      deep_dive: $deep_dive[0],
      organizations: $orgs[0],
      gists: $gists[0],
      contributions: $contrib[0],
      activity: $activity[0]
    }'
}

# ============================================================================
# 无 Token 降级函数 — 用公开网页 + Events API 填补数据缺口
# ============================================================================

# 抓取 GitHub 个人主页获取贡献总数（替代 GraphQL contributionCalendar）
# 贡献日历由 JS 渲染，curl 拿不到每日分布，只能提取页面中的年度总计数
fetch_contributions_scrape() {
  local username="$1"
  info "抓取贡献总数: /users/${username}/contributions (无认证)"

  local html total
  html=$(curl -sL -H "User-Agent: Mozilla/5.0" "https://github.com/users/${username}/contributions" 2>/dev/null || echo "")

  if [ -z "$html" ]; then
    echo '{"calendar":{"total":null,"weeks":[],"_note":"scrape_failed"},"top_commit_repos":[],"top_pr_repos":[],"_source":"scraped_profile_page"}'
    return 0
  fi

  # 提取 <h2 ...> N contributions in the last year </h2> 中的数字
  # h2 内部格式: 第一行是标签(含tabindex数字)，数字在后续行独立出现
  total=$(echo "$html" | awk '/js-contribution-activity-description/,/\/h2/' | tail -n +2 | grep -oP '\d+' | head -1 || echo "")
  [ -z "$total" ] && total="null"

  jq -n --arg total "$total" '{
    total_commit_contributions: null,
    total_issue_contributions: null,
    total_pr_contributions: null,
    total_review_contributions: null,
    restricted_contributions: null,
    calendar: {
      total: (if $total == "null" then null else ($total | tonumber) end),
      weeks: [],
      _note: "no_token: daily_detail_requires_graphql"
    },
    top_commit_repos: [],
    top_pr_repos: [],
    _source: "scraped_profile_page"
  }'
}

# 从 Events API 获取最近活动（替代 GraphQL PR/Issue 查询）
# 无认证可用，60次/小时，返回最近 90 天最多 300 条事件
fetch_activity_events() {
  local username="$1"
  info "获取公开事件流 (Events API): $username"

  local events
  events=$(api_call "GET" "${GITHUB_API_BASE}/users/${username}/events/public?per_page=100" 2>/dev/null || echo '[]')

  echo "$events" | jq '{
    pull_requests: {
      total_count: ([.[] | select(.type == "PullRequestEvent")] | length),
      items: [.[] | select(.type == "PullRequestEvent") | {
        title: .payload.pull_request.title,
        state: .payload.pull_request.state,
        merged: .payload.pull_request.merged,
        repo: .repo.name,
        created_at: .created_at,
        merged_at: .payload.pull_request.merged_at,
        closed_at: .payload.pull_request.closed_at
      }]
    },
    issues: {
      total_count: ([.[] | select(.type == "IssuesEvent")] | length),
      items: [.[] | select(.type == "IssuesEvent") | {
        title: .payload.issue.title,
        state: .payload.issue.state,
        repo: .repo.name,
        created_at: .created_at,
        closed_at: .payload.issue.closed_at
      }]
    },
    _source: "events_api_90d"
  }'
}

# ============================================================================
# 主流程
# ============================================================================

main() {
  local username="" force=false to_stdout=false private_mode=false

  # 解析命令行参数
  while [ $# -gt 0 ]; do
    case "$1" in
      --force|-f) force=true; shift ;;
      --stdout|-s) to_stdout=true; shift ;;
      --private|-p) private_mode=true; shift ;;
      --help|-h)
        echo "用法: $0 <username> [--force] [--stdout] [--private]"
        echo ""
        echo "环境变量:"
        echo "  GITHUB_TOKEN — GitHub Personal Access Token（必填，--private模式需repo权限）"
        echo ""
        echo "选项:"
        echo "  --force, -f    强制刷新（忽略已有缓存文件）"
        echo "  --stdout, -s   输出 JSON 到 stdout（同时保存到文件）"
        echo "  --private, -p  读取 Token 所属用户的私有仓库（需 repo scope）"
        echo "  --help, -h     显示此帮助"
        exit 0
        ;;
      *) username="$1"; shift ;;
    esac
  done

  # Token 检测与降级标记（放在用户名校验之前，因为无用户名时可用 Token 自动推断）
  local HAS_TOKEN=true
  if [ -z "${GITHUB_TOKEN:-}" ]; then
    HAS_TOKEN=false
  elif ! [[ "$GITHUB_TOKEN" =~ ^(ghp_|github_pat_|gho_) ]]; then
    warn "GITHUB_TOKEN 格式不常见，将以无认证模式运行"
    HAS_TOKEN=false
  fi

  # 无用户名时，尝试通过 Token 自动推断
  if [ -z "$username" ]; then
    if [ "$HAS_TOKEN" = true ]; then
      info "未指定用户名，通过 Token 自动检测..."
      local whoami
      whoami=$(api_call "GET" "${GITHUB_API_BASE}/user" 2>/dev/null || echo "")
      username=$(echo "$whoami" | jq -r '.login // ""' 2>/dev/null)
      if [ -n "$username" ] && [ "$username" != "null" ]; then
        info "自动检测到 Token 所属用户: $username"
      else
        err "无法通过 Token 推断用户名，请手动指定: $0 <username>"
        exit 1
      fi
    else
      err "缺少用户名参数，且未设置 Token。用法: $0 <username>"
      err "或设置 Token 后自动检测: export GITHUB_TOKEN=\"ghp_xxxx\" && $0"
      exit 1
    fi
  fi

  # 补全降级提示（放在用户名确定之后）
  if [ "$HAS_TOKEN" = false ]; then
    warn "GITHUB_TOKEN 未设置，将以无认证模式运行（数据覆盖度 ~75%）"
    warn "  缺失：贡献总数/日历（改为页面抓取估算）、仓库质量快照、PR/Issue 详情"
    warn "  设置 Token 可获得完整数据: export GITHUB_TOKEN=\"ghp_xxxx\""
  fi

  # 无 Token 时 api_call 自动跳过认证头（配额 60次/小时）

  # --private 模式：强制使用 Token 所属用户，因为 /user/repos 只能查自己
  if [ "$private_mode" = true ]; then
    if [ "$HAS_TOKEN" = false ]; then
      err "--private 模式需要有效的 GITHUB_TOKEN（且需 repo 权限）"
      exit 1
    fi
    local token_owner
    token_owner=$(api_call "GET" "${GITHUB_API_BASE}/user" 2>/dev/null | jq -r '.login // ""' 2>/dev/null)
    if [ -z "$token_owner" ] || [ "$token_owner" = "null" ]; then
      err "--private 模式无法获取 Token 所属用户，请检查 Token 是否有效"
      exit 1
    fi
    if [ -n "$username" ] && [ "$username" != "$token_owner" ]; then
      warn "--private 模式只能读取 Token 所属用户 ($token_owner) 的私有仓库，已自动切换"
    fi
    username="$token_owner"
    info "私有仓库模式: 将读取 $username 的全部仓库（含私有）"
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

  # 临时目录（存放各阶段输出，合并后清理）
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap "rm -rf $tmp_dir" EXIT

  # ========================================================================
  # 顺序执行各阶段（每阶段结果写入临时文件）
  # ========================================================================

  # --- 阶段1: 用户资料 (REST, 1 call) ---
  local p1_file="${tmp_dir}/profile.json"
  fetch_user_profile "$username" > "$p1_file" || {
    err "无法获取用户 $username 的资料。请确认用户名正确或 Token 是否有效。"
    exit 4
  }
  ok "阶段1/7: 用户资料获取完成"

  # --- 阶段2: 仓库列表 (REST 分页, 最多 3 calls) ---
  local p2_file="${tmp_dir}/repos.json"
  fetch_repos_rest "$username" "$REPO_TARGET_COUNT" "$private_mode" > "$p2_file" || {
    err "无法获取仓库列表"
    exit 4
  }
  ok "阶段2/7: 仓库列表获取完成"

  # --- 阶段3: 组织 (REST, 1 call) ---
  local p3_file="${tmp_dir}/orgs.json"
  fetch_orgs "$username" > "$p3_file" || {
    warn "无法获取组织列表，使用空数组"
    echo '[]' > "$p3_file"
  }
  ok "阶段3/7: 组织列表获取完成"

  # --- 阶段4: 贡献统计 (GraphQL 优先，无 Token 时抓取网页) ---
  local p4_file="${tmp_dir}/contrib.json"
  if [ "$HAS_TOKEN" = true ]; then
    fetch_contributions_graphql "$username" > "$p4_file" || {
      warn "GraphQL 贡献查询失败，尝试页面抓取..."
      fetch_contributions_scrape "$username" > "$p4_file"
    }
  else
    fetch_contributions_scrape "$username" > "$p4_file"
  fi
  ok "阶段4/7: 贡献统计获取完成"

  # --- 阶段5: PR + Issue (GraphQL 优先，无 Token 时 Events API) ---
  local p5_file="${tmp_dir}/activity.json"
  if [ "$HAS_TOKEN" = true ]; then
    fetch_activity_graphql "$username" > "$p5_file" || {
      warn "GraphQL 活动查询失败，使用 Events API 降级方案..."
      fetch_activity_events "$username" > "$p5_file"
    }
  else
    fetch_activity_events "$username" > "$p5_file"
  fi
  ok "阶段5/7: 活动数据获取完成"

  # --- 阶段6: 仓库深度内容抓取 (需 Token: README + commit message + issue) ---
  local p6_file="${tmp_dir}/deep_dive.json"
  if [ "$HAS_TOKEN" = true ]; then
    ensure_rate_quota 30 core "REST" || true
    fetch_repo_deep_dive "$(cat "$p2_file")" "$username" 10 > "$p6_file" || {
      warn "仓库深度抓取失败，使用空数据"
      echo '[]' > "$p6_file"
    }
  else
    info "阶段6/7: 仓库深度抓取（需 Token，跳过）"
    echo '[]' > "$p6_file"
  fi
  ok "阶段6/7: 仓库深度抓取完成"

  # --- 阶段7: 公开 Gists (需 Token: gist 权限) ---
  local p7_file="${tmp_dir}/gists.json"
  if [ "$HAS_TOKEN" = true ]; then
    fetch_user_gists "$username" > "$p7_file" || {
      warn "无法获取 Gists，使用空数组"
      echo '[]' > "$p7_file"
    }
  else
    echo '[]' > "$p7_file"
  fi
  ok "阶段7/7: 公开 Gists 获取完成"

  # ========================================================================
  # 汇总输出
  # ========================================================================
  info "汇总所有数据..."

  merge_output "$tmp_dir" "$username" > "$output_file"
  ok "数据已保存至: $output_file"

  local file_size
  file_size=$(wc -c < "$output_file" | tr -d ' ')
  if [ "$file_size" -gt 50000 ]; then
    warn "输出文件较大 (${file_size} bytes)，可能需要精简后再喂给 AI 分析"
  fi

  if [ "$to_stdout" = true ]; then
    cat "$output_file"
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
