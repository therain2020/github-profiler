---
name: github-optimize
description: GitHub自我优化：基于蒸馏+评分结果生成个性化成长方案，含Profile/技能/项目/社交/职业五大板块
allowed-tools:
  - Bash
  - Read
  - Write
triggers:
  - github 自我优化
  - github 优化建议
  - github optimize
  - 优化 github profile
  - 怎么提升 github
---

# GitHub 自我优化器

**"蒸馏告诉你你是谁，优化告诉你怎么变得更好。"**

基于蒸馏/评分结果 + 原始数据，生成一份**只针对你、可立即执行**的个性化优化方案。

**前提：** 需要 `output/<username>.json` + 至少一项分析结果（score JSON 或 distill JSON）已存在。

## 流水线位置

```
/github-fetch  → 获取数据
/github-scorer → 评分     ↘
/github-distill → 蒸馏    → /github-optimize → /github-report
```

## 工作流

### Step 1: 检查前置数据

```bash
# 需要：
# output/<username>.json              — 原始数据
# temp/score.json 或 temp/distill.json — 分析结果
```

如果不存在，提示先运行 `/github-scorer` 或 `/github-distill`。

### Step 2: 优化分析

1. 读取原始数据 `output/<username>.json`
2. 读取分析结果（distill JSON 优先，含 dna/rpg/hidden_self）
3. 读取 `templates/optimize-prompt.md` 模板
4. AI 生成五大板块优化方案

### Step 3: 输出

保存到 `reports/<username>-optimize-<timestamp>.md`；提示 `/github-report optimize` 生成 HTML。

## 五大板块

| 板块 | 内容 | 数据来源 |
|------|------|---------|
| Profile 急救 | 头像/bio/README 等立即能改的 | profile 字段 |
| 项目打磨 | README/文档 缺失清单 | repositories + deep_dive |
| 技能路线 | 基于技术 DNA 的下一步建议 | 语言分布 + 范式分布 |
| 社交破冰 | 第一个 Follower/PR/组织 | followers/organizations |
| 职业定位 | GitHub 叙事线 + 一句话介绍 | persona + rpg |

每条建议含：[数据锚点] → [具体操作] → [预期效果] → [优先级 P0/P1/P2]

## 相关 Skill

| Skill | 职责 |
|-------|------|
| `/github-fetch` | 获取数据（前提） |
| `/github-scorer` | 四维度评分 |
| `/github-distill` | 蒸馏人物画像 |
| `/github-report` | 可视化 HTML 报告 |
