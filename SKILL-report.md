---
name: github-report
description: 将GitHub分析结果（评分/蒸馏/优化）渲染为可视化HTML报告，含ECharts图表和微信/QQ分享
allowed-tools:
  - Bash
  - Read
  - Write
triggers:
  - 生成 github 报告
  - github 可视化报告
  - github report
  - 渲染 github 结果
---

# GitHub 可视化报告生成器 (GitHub Report)

将评分/蒸馏/优化的 JSON 结果渲染为带 ECharts 图表的可视化 HTML 报告，含微信/QQ/X 分享功能。

**本 Skill 是共享渲染层**——`/github-scorer` 和 `/github-distill` 在分析完成后都调用本 Skill 生成 HTML 报告。

## 两种报告模式

### A. 蒸馏报告（distill）

输入：蒸馏 JSON（含 `distillate` / `persona` / `dna` / `hidden_self` / `rpg` 字段）
模板：`templates/distill-report.html`
输出：`reports/<username>-distill-<timestamp>.html`

图表：
- 思维范式雷达图（Builder/Learner/Collector/Hacker/Explainer）
- 贡献日历热力图（年度）
- 语言分布 Treemap
- 社交温度仪表盘
- RPG 角色卡（纯 CSS 渲染）

### B. 评分报告（scorer）

输入：评分 JSON（含 `tech_score` / `engineering_score` / `collab_score` / `influence_score` / `composite_score` / `profile_tags` / `summary`）
模板：`templates/scorer-report.html`
输出：`reports/<username>-scorer-<timestamp>.html`

图表：
- 综合评分大数字 + 环形进度条
- 四维度柱状图（含权重标注）
- 技术标签云
- 与排行榜均值对比（如有）
- 仓库质量指标雷达

## 工作流

### Step 1: 确定报告类型

检查输入 JSON 的结构：
- 含 `distillate` 字段 → 蒸馏报告
- 含 `composite_score` 字段 → 评分报告
- 其他 → 报错

### Step 2: 准备图表数据

从原始数据 JSON（`output/<username>.json`）中提取图表所需数据：

**贡献日历数据：**
```bash
jq '[.contributions.calendar.weeks[].days[] | select(.count > 0) | [.date, .count]]' output/<username>.json
```

**语言分布数据：**
```bash
jq '[.repositories | group_by(.language) | .[] | {name: (.[0].language // "Unknown"), value: length}]' output/<username>.json
```

**日历范围：**
取最早和最晚日期。

**社交温度分数：**
基于 followers/following/orgs 计算（0-100）：
- followers > 0 → +30
- following > 0 → +10
- orgs > 0 → +20
- PRs > 0 → +40
归一化到 0-100。

### Step 3: 填充模板

读取对应模板，替换所有 `{{PLACEHOLDER}}` 变量。

### Step 4: 写入文件

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
# 保存到 reports/<username>-<mode>-<timestamp>.html
```

### Step 5: 告知用户

> 可视化报告已生成：`reports/<username>-distill-20260517.html`
> 
> 在浏览器中打开即可查看。页面底部有微信/QQ/X 分享按钮。

## 分享机制（"自来水"传播）

每个 HTML 报告底部自带分享栏：

| 按钮 | 功能 |
|------|------|
| 复制到微信 | 生成适合微信群粘贴的文本卡片（含排名/标签/一句总结） |
| 复制到 QQ | 生成适合 QQ 群粘贴的精简文本（含 Emoji 和链接） |
| X / Twitter | 生成推文并打开 X 发布页（含项目链接） |
| 复制卡片 | 复制完整的 Markdown 格式卡片 |

分享文本设计原则：
- 有记忆点的蒸馏语或评分数字（"4.2/5.0" 比"优秀"更能传播）
- 带项目名和链接（每次分享都是一次曝光）
- Emoji 适度使用（在群聊中有视觉辨识度）

## 示例

```
/github-scorer torvalds
→ 分析完成，评分 JSON 已生成
→ 调用 /github-report 生成 HTML
→ reports/torvalds-scorer-20260517.html
```

## SKILL 间调用关系

```
/github-scorer   ──→  分析 → 评分 JSON ──┐
                                         ├──→ /github-report → HTML 报告
/github-distill  ──→  分析 → 蒸馏 JSON ──┘
```
