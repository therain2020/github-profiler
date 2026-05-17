---
name: github-optimize
description: GitHub自我优化：基于蒸馏结果+原始数据生成个性化成长方案，含Profile优化/技能路线/项目打磨/社交破冰/职业定位
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

# GitHub 自我优化器 (GitHub Optimize)

**"蒸馏告诉你你是谁，优化告诉你怎么变得更好。"**

基于蒸馏结果 + 原始 GitHub 数据，生成一份**只针对你、可立即执行**的个性化优化方案。不是泛泛的"多参与开源"——每一条建议都绑定具体数据、具体操作、具体预期效果。

## 和另外两个 Skill 的关系

```
/github-scorer   → 面试官评价你
/github-distill  → 人类学家认识你
/github-optimize → 教练提升你（本 Skill）
/github-report   → 把一切渲染成好看的 HTML
```

## 前置条件

必须先运行一次 `/github-distill`（或 `/github-scorer`），已有分析结果。优化 Skill 读取已有的蒸馏 JSON 和原始数据 JSON。

## 工作流

### Step 1: 检查前置数据

```bash
# 需要两个文件：
# output/<username>.json          — 原始 GitHub 数据
# reports/<username>-distill-*.md — 蒸馏结果（含 JSON 块）
```

如果不存在，提示先运行 `/github-distill <username>`。

### Step 2: 优化分析

1. 读取原始数据 JSON（`output/<username>.json`）
2. 读取蒸馏结果中的 JSON 块（含 `dna` / `hidden_self` / `rpg` 等）
3. 读取 `templates/optimize-prompt.md` 优化提示词
4. 输入数据给 AI 进行分析

### Step 3: 生成优化报告

输出到 `reports/<username>-optimize-<timestamp>.md`

### Step 4: 调用报告 Skill 生成 HTML

```bash
/github-report
```

### Step 5: 分享

同 scorer/distill，HTML 报告底部自带微信/QQ/X 分享按钮。

## 优化报告的五大板块

| 板块 | 内容 | 数据来源 |
|------|------|---------|
| **Profile 急救** | 头像/bio/所在地/个人网站/README 等立即能改的 | profile 字段缺失分析 |
| **项目打磨** | README/License/CI/CD/文档 缺失清单 | repositories 字段 + quality 快照 |
| **技能路线** | 基于技术 DNA 的下一步学习建议 | 语言分布 + 范式分布 + 贡献日历 |
| **社交破冰** | 第一个 Follower、第一个 PR、第一个组织 | social_temperature + followers/organizations |
| **职业定位** | GitHub 叙事线 + "一句话介绍自己" | persona + distillate + rpg |

每一条优化建议必须包含：
- **[数据锚点]** 当前状态是什么
- **[具体操作]** 精确到点击哪个按钮、写什么文字
- **[预期效果]** 完成后能看到什么变化
- **[优先级]** P0(本周)/P1(本月)/P2(本季度)

## 示例

```
用户: /github-optimize therain2020
→ 检测到已有蒸馏结果
→ 读取数据和蒸馏 JSON
→ 生成五大板块优化方案
→ 调用 /github-report 生成 HTML
→ reports/therain2020-optimize-20260517.html
```

## 相关 Skill

- `/github-distill` — 提取"另一个我"（优化 Skill 的前置步骤）
- `/github-scorer` — 评分（外部评价视角）
- `/github-report` — 可视化 HTML 报告
