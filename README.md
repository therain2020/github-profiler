# GitHub Profiler · 开源用户画像分析工具

[English](#english) | [中文](#chinese)

---

<a id="english"></a>
## English

An open-source tool that analyzes GitHub users' public data, producing a 6-dimension score (0-100), a distilled developer persona, personalized growth plans, and interactive HTML reports — all shareable with one-click screenshot + QR code.

### Architecture · 7 Skills

```
/github-fetch      → Fetch raw data (155KB)
/github-extract    → Compress to 50KB (-67%)
/github-scorer     → 6-dim score (0-100)
/github-distill    → Developer persona + alter ego
/github-optimize   → Personalized growth plan
/github-report     → HTML report + social share + ⭐Star prompt
/github-pipeline   → Orchestrate all steps with user prompts
```

### Quick Start

```bash
git clone https://github.com/therain2020/github-profiler.git
cd github-profiler

# One-click token setup (reuses gh CLI or guides creation)
bash scripts/setup.sh

# Open Claude Code in this directory
claude

# Run the pipeline
/github-pipeline
```

Or run individual steps:
```
/github-fetch           # Fetch data
/github-extract CAICAIIs  # Compress
/github-scorer CAICAIIs   # Score
/github-report scorer     # Render HTML
```

### Score Dimensions (0-100)

| Dimension | Based on |
|-----------|----------|
| Productivity | Commits, active days, repo count |
| Influence | Followers, stars, org membership |
| Quality | README completeness, commit message quality |
| Collaboration | PR merge rate, reviews, cross-project contributions |
| Knowledge Sharing | Blog, gists, README content, issue discussions |
| Growth Potential | Language diversity, account age, activity breadth |

### Tech Stack

- **Data Fetching**: bash + curl + jq + GitHub REST/GraphQL API
- **AI Analysis**: Claude Code LLM with structured prompts
- **Backend**: Supabase (Postgres + REST API)
- **Reports**: HTML/CSS + ECharts + html2canvas
- **One-click share**: Screenshot with embedded QR code → repo README

### Requirements

- `curl` + `jq`
- `GITHUB_TOKEN` (create at github.com/settings/tokens, no scopes needed)
- Claude Code
- Optional: Supabase account (for leaderboard)

---

<a id="chinese"></a>
## 中文

基于 GitHub 公开数据的开源用户分析工具，支持六维度评分 (0-100)、开发者人格蒸馏、个性化成长方案，输出交互式 HTML 报告，一键截图带二维码分享。

### 架构 · 7 个 Skill

```
/github-fetch      → 获取原始数据 (155KB)
/github-extract    → 压缩到 50KB (-67%)
/github-scorer     → 六维评分 (0-100)
/github-distill    → 人格蒸馏 + 镜像角色
/github-optimize   → 个性化成长方案
/github-report     → HTML 报告 + 社交分享 + ⭐Star 提示
/github-pipeline   → 一键调度，每步询问用户
```

### 快速开始

```bash
git clone https://github.com/therain2020/github-profiler.git
cd github-profiler

# 一键配置 Token（自动复用 gh CLI 或引导创建）
bash scripts/setup.sh

# 在此目录启动 Claude Code
claude

# 运行完整流水线
/github-pipeline
```

或逐步执行：
```
/github-fetch           # 获取数据
/github-extract CAICAIIs  # 压缩提取
/github-scorer CAICAIIs   # 评分
/github-report scorer     # 生成 HTML
```

### 评分维度 (0-100 分制)

| 维度 | 依据 |
|------|------|
| 代码生产力 | commits 总数、活跃天数、仓库数量 |
| 社区影响力 | Followers、Star/Fork、组织参与 |
| 工程质量 | README 完整性、commit message 规范性 |
| 协作贡献 | PR 合并率、Review 参与、跨项目贡献 |
| 知识分享 | Blog、Gist、README 内容、Issue 交流 |
| 成长潜力 | 语言多样性、账号年龄、活动广度 |

### 技术栈

- **数据获取**: bash + curl + jq + GitHub REST/GraphQL API
- **AI 分析**: Claude Code LLM + 结构化提示词
- **后端**: Supabase (Postgres + REST API)
- **报告**: HTML/CSS + ECharts + html2canvas
- **一键分享**: 截图内嵌二维码 → 扫码跳转仓库

### 环境要求

- `curl` + `jq`
- `GITHUB_TOKEN`（前往 github.com/settings/tokens 创建，无需任何权限）
- Claude Code
- 可选：Supabase 账号（用于排行榜）

---

## License

MIT — see [LICENSE](LICENSE)

⭐ If you find this useful, [star this repo](https://github.com/therain2020/github-profiler)!
