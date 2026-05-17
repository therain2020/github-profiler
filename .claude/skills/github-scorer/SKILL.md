---
name: github-scorer
description: 基于GitHub公开数据对用户进行六维度量化评分（0-100分制），输出评分JSON+可视化数据
allowed-tools:
  - Bash
  - Read
  - Write
triggers:
  - github 用户评分
  - 分析 github 用户
  - github profile score
  - 给github用户打分
  - github 用户分析
---

# GitHub 用户评分器

以资深开源社区专家 + 技术面试官 + 数据分析师视角，对用户进行四维度量化评分。

**前提：** 需要 `output/<username>.json` 已存在（由 `/github-fetch` + `/github-extract` 生成）。如果没有，提示用户先运行 `/github-fetch <username>` 然后 `/github-extract <username>`。

## 工作流

### Step 1: 检查数据

```bash
if [ ! -f "output/<username>.json" ]; then
  echo "请先获取数据: /github-fetch <username>"
  exit 1
fi
```

### Step 2: AI 分析

1. 读取 `output/<username>.json`
2. 读取 `templates/analysis-prompt.md` 模板
3. 替换 `{{USERNAME}}` 和 `{{GITHUB_DATA}}`
4. 输出 Markdown 格式分析报告，末尾嵌入 JSON 评分块：

```json
{
  "username": "<username>",
  "overall_score": 66,
  "dimension_scores": {
    "productivity": 0,
    "influence": 0,
    "quality": 0,
    "collaboration": 0,
    "knowledge_sharing": 0,
    "growth_potential": 0
  },
  "summary": {
    "strengths": ["优点1", "优点2"],
    "weaknesses": ["短板1", "短板2"],
    "tagline": "一句话评语"
  },
  "visualization_data": {
    "radar": {"labels": [...], "values": [...]},
    "contribution_calendar": [...],
    "language_distribution": [...],
    "activity_breakdown": {...},
    "top_repos": [...],
    "commit_frequency_last_year": [...]
  }
}
```

5. 将 JSON 保存到 `temp/score.json`

分析原则：
- 严格基于数据（profile + repositories + deep_dive + contributions + activity）
- 6 个维度，0-100 分制
- deep_dive 配合 commit message + README，工程规范评分更有依据

### Step 3: 询问排行榜

评分完成后主动询问是否上传到 Supabase 排行榜。如同意：

```bash
bash scripts/save-score.sh temp/score.json
```

### Step 4: 提示下一步

分析完成后提示：
- `/github-report scorer` — 生成可视化 HTML（含 ECharts + 分享）
- `/github-distill <username>` — 蒸馏人物画像
- `/github-optimize <username>` — 生成自我优化方案

## 评分维度（6维 · 0-100分制）

| 维度 | 依据 |
|------|------|
| 代码生产力 | commits 总数、日历活跃密度、仓库数量 |
| 社区影响力 | Followers、Star/Fork、组织参与 |
| 工程质量 | commit message 规范、README 完整性、项目描述 |
| 协作贡献 | PR 合并率、Review 参与、Issue 质量 |
| 知识分享 | Blog、Gist、README 内容、Issue 交流 |
| 成长潜力 | 语言多样性、账号年龄、活动广度 |

## 相关 Skill

| Skill | 职责 |
|-------|------|
| `/github-fetch` | 获取数据（前提） |
| `/github-distill` | 蒸馏人物画像 |
| `/github-optimize` | 自我优化方案 |
| `/github-report` | 可视化 HTML 报告 |
