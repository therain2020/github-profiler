# GitHub Profiler

[English](README.md)

分析 GitHub 用户公开数据，产出六维度评分（0-100）、开发者人格蒸馏、个性化成长方案和交互式 HTML 报告。所有功能以 Claude Code 斜杠命令的方式运行。

## 能做什么

输入一个 GitHub 用户名，程序会抓取该用户的公开资料、仓库、贡献记录、组织、Gist、PR 和 Issue，然后通过 LLM 链条依次分析。

最终输出：六维度评分（生产力、影响力、工程质量、协作贡献、知识分享、成长潜力），一份开发者人格画像加镜像角色卡，涵盖五个方向的成长建议。以及带 ECharts 图表、二维码分享和截图导出的交互式 HTML 报告。

分析结果要不要上传到共享的 Supabase 排行榜，由你决定。

## 快速开始

```bash
git clone https://github.com/therain2020/github-profiler.git
cd github-profiler

# 一键配置 GITHUB_TOKEN（自动复用 gh CLI 或引导创建）
bash scripts/setup.sh

# 启动 Claude Code
claude

# 运行完整流水线（每步执行前会先问你）
/github-pipeline
```

也可以逐步执行：

```
/github-fetch              # 第1步：获取原始数据
/github-extract <username> # 第2步：压缩数据（~155KB → ~50KB）
/github-scorer <username>  # 第3步：六维度评分
/github-distill <username> # 第4步：人格蒸馏 + 镜像角色
/github-optimize <username># 第5步：成长方案
/github-report scorer      # 第6步：HTML 报告
```

## 评分维度

每个维度 0-100 分，完全基于用户的公开 GitHub 数据。

| 维度 | 衡量内容 |
|------|----------|
| 代码生产力 | commit 数量、活跃天数、非 fork 仓库数量 |
| 社区影响力 | followers 数量、star/fork 数、组织参与 |
| 工程质量 | README 完整度、commit message 质量、项目结构 |
| 协作贡献 | PR 合并率、code review 活跃度、跨项目贡献 |
| 知识分享 | 博客、gist 活跃度、README 深度、issue 讨论参与 |
| 成长潜力 | 语言多样性、账号年龄、活动类型分布 |

综合分是六个维度的加权平均。

## 环境要求

- `curl` 和 `jq`（fetch 脚本会自动检查）
- `GITHUB_TOKEN` 环境变量。在 [github.com/settings/tokens](https://github.com/settings/tokens) 创建，公开数据无需任何权限。如需读取私有仓库，加 `--private` 参数并使用 `repo` 权限的 token。
- [Claude Code](https://claude.ai/code)
- 可选：Python 3（用于 extract 步骤；没有的话该步骤自动跳过）
- 可选：Supabase 项目（用于排行榜；需配置 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY`）

## 项目结构

```
github-profiler/
├── scripts/
│   ├── fetch-github-data.sh   # REST + GraphQL 混合，7 阶段数据抓取
│   ├── extract-github-data.sh # 调用 _extract.py 压缩抓取产物
│   ├── _extract.py            # Python 压缩（去重、裁剪时间戳、智能截断 README）
│   ├── render-report.py       # 从评分数据生成 HTML 报告
│   ├── save-score.sh          # 上传评分到 Supabase 排行榜
│   ├── leaderboard.sh         # 查询共享排行榜
│   └── setup.sh               # 一键配置 GITHUB_TOKEN
├── templates/
│   ├── analysis-prompt.md     # 六维度评分的 LLM 提示词
│   ├── distill-prompt.md      # 人格蒸馏的 LLM 提示词
│   ├── optimize-prompt.md     # 成长规划的 LLM 提示词
│   └── share-card.html        # 独立评分卡片（无框架依赖）
├── supabase/
│   └── schema.sql             # 评分表 + 排行榜视图 + RLS 策略
├── .claude/skills/            # 7 个 Claude Code skill 定义
│   ├── github-fetch/SKILL.md
│   ├── github-extract/SKILL.md
│   ├── github-scorer/SKILL.md
│   ├── github-distill/SKILL.md
│   ├── github-optimize/SKILL.md
│   ├── github-report/SKILL.md
│   └── github-pipeline/SKILL.md
├── output/                    # 抓取缓存（已 gitignore）
├── reports/                   # 分析报告（已 gitignore）
└── temp/                      # 临时文件（已 gitignore）
```

## 数据抓取原理

fetch 脚本（`scripts/fetch-github-data.sh`）分 7 个阶段顺序执行：

1. **Profile**：REST API，1 次调用。bio、company、location、followers 等。
2. **Repos**：REST API，分页。按 stars 排序取前 100 个仓库。
3. **Organizations**：REST API，1 次调用。组织归属。
4. **Contributions**：GraphQL，无 token 时退化为页面抓取。commit 日历、贡献仓库排行。
5. **Activity**：GraphQL，无 token 时退化为 Events API。近期 PR 和 Issue。
6. **Deep dive**：Top 10 仓库。README 文本、commit message、Issue。需要 token。
7. **Gists**：REST API。公开 gist 及文件元数据。

结果缓存在 `output/<username>.json`，24 小时内复用。用 `--force` 强制刷新。

没有 token 时脚本以降级模式运行（约 75% 数据覆盖）：贡献数从个人主页抓取，PR/Issue 来自公开的 Events API（90 天窗口），deep dive 和 gist 跳过。

### 脚本参数

```
bash scripts/fetch-github-data.sh <username>           # 常规抓取（利用缓存）
bash scripts/fetch-github-data.sh <username> --force   # 跳过缓存，强制刷新
bash scripts/fetch-github-data.sh <username> --stdout  # 同时输出到 stdout
bash scripts/fetch-github-data.sh <username> --private # 含私有仓库（需 repo 权限 token）
bash scripts/fetch-github-data.sh --private            # 用 token 自动识别用户
```

## 排行榜

基于 Supabase 的共享排行榜，可选使用。每个用户只显示最新一条评分。

```bash
# 上传评分
bash scripts/save-score.sh temp/score.json

# 查看前 20 名
bash scripts/leaderboard.sh

# 查看前 50 名
bash scripts/leaderboard.sh 50

# 查特定用户
bash scripts/leaderboard.sh --user torvalds

# 全局统计
bash scripts/leaderboard.sh --stats
```

数据库结构见 `supabase/schema.sql`。在自己的 Supabase SQL Editor 中执行即可建表。需要配置 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 环境变量。

## 开发

无需构建。脚本是 POSIX 兼容的 bash。Python 脚本目标 Python 3.8+，零外部依赖（仅标准库）。

```bash
# 抓取测试数据
bash scripts/fetch-github-data.sh torvalds --force

# 运行流水线
/github-pipeline
```

新增评分维度或修改评分逻辑，编辑 `templates/analysis-prompt.md`。改报告样式，编辑 `scripts/render-report.py` 和 `templates/share-card.html`。

## 许可证

MIT，详见 [LICENSE](LICENSE)
