---
name: github-fetch
description: 获取GitHub用户公开数据（REST+GraphQL混合），保存到output/<user>.json，24h内幂等缓存
allowed-tools:
  - Bash
  - Read
triggers:
  - 获取 github 数据
  - github fetch
  - 抓取 github 用户数据
  - fetch github data
  - 拉取 github
---

# GitHub 数据获取器 (GitHub Fetch)

**职责单一：只获取数据，不做任何分析。** 产物是 `output/<username>.json`，供 scorer/distill/optimize 三个分析 Skill 共用。

## 工作流

### Step 1: 验证环境

```bash
# 检查 GITHUB_TOKEN
if [ -z "$GITHUB_TOKEN" ]; then
  echo "GITHUB_TOKEN 未设置，将使用无认证模式（覆盖度 ~75%）"
  echo "设置 Token 获得完整数据: export GITHUB_TOKEN=\"ghp_xxxx\""
fi
command -v curl && command -v jq && echo "环境就绪"
```

### Step 2: 获取数据

```bash
# 指定用户
bash scripts/fetch-github-data.sh <username>

# 自动检测 Token 所属用户
bash scripts/fetch-github-data.sh

# 强制刷新
bash scripts/fetch-github-data.sh <username> --force
```

脚本特性：
- REST + GraphQL 混合策略（7 阶段，版本 2.2.0）
- 24h 幂等缓存（`--force` 强制刷新）
- 自动速率限制监控与等待
- 网络重试（3 次，指数退避）
- 无 Token 自动降级为页面抓取 + Events API

### Step 3: 报告结果

```bash
# 查看数据摘要
jq '{meta, profile: {login, name, bio, followers, public_repos}, repos: (.repositories | length), deep_dive: (.deep_dive | length)}' output/<username>.json
```

## 输出结构

```json
{
  "meta": { "username": "...", "fetched_at": "...", "version": "2.2.0" },
  "profile": { /* login, name, bio, company, followers, following, public_repos */ },
  "repositories": [ /* 精简9字段 */ ],
  "deep_dive": [ /* Top 10 自有仓库：README全文 + commit message + issue */ ],
  "organizations": [ /* 所属组织 */ ],
  "gists": [ /* 公开 Gists */ ],
  "contributions": { /* 贡献统计 + 日历 + 仓库贡献分布 */ },
  "activity": { /* 最近30 PR + 最近30 Issue */ }
}
```

## 后续步骤

获取数据后，可运行：
- `/github-scorer <username>` — 四维度评分
- `/github-distill <username>` — 人物画像 + RPG 角色卡
- `/github-optimize <username>` — 个性化成长方案
- `/github-report <mode>` — 可视化 HTML 报告

## 环境变量

| 变量 | 必需 | 说明 |
|------|------|------|
| `GITHUB_TOKEN` | 建议 | 有 Token 可获得完整数据（5000 req/hr） |
| `CAICAI_KEY` | 否 | 用户自定义 Token 名，需手动 `export GITHUB_TOKEN="$CAICAI_KEY"` |
