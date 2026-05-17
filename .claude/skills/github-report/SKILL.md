---
name: github-report
description: 将GitHub分析结果（评分/蒸馏/优化）渲染为可视化HTML报告，含ECharts图表、社交分享和Star提示
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

# GitHub 可视化报告生成器

**共享渲染层**——scorer/distill/optimize 三个分析 Skill 的产物，统一由本 Skill 渲染成带 ECharts 图表 + 社交分享 + Star 提示的 HTML 页面。

## 流水线位置

```
/github-fetch → /github-scorer  ──→ temp/score.json ──┐
              → /github-distill ──→ temp/distill.json ─┤
              → /github-optimize → temp/optimize.json ─┤
                                                        ↓
                                            /github-report → HTML
```

## 三种模式

### scorer — 评分报告

输入：`temp/score.json` + `output/<username>.json`
命令：`python scripts/render-report.py temp/scorer-input.json scorer`
图表：四维度雷达、贡献日历热力图、语言分布 Treemap、仓库深度分析雷达

### distill — 蒸馏报告

输入：`temp/distill.json` + `output/<username>.json`
命令：`python scripts/render-report.py temp/distill-input.json distill`
图表：思维范式雷达、贡献日历、语言分布、社交温度、RPG 角色卡

### optimize — 优化报告

输入：`temp/optimize.json` + `output/<username>.json`
模板：`templates/optimize-report.html`

## 工作流

### Step 1: 合并数据

```bash
# scorer 模式
jq -s '.[0] * {profile:.[1].profile,repositories:.[1].repositories,deep_dive:.[1].deep_dive,contributions:.[1].contributions,activity:.[1].activity,organizations:.[1].organizations,gists:.[1].gists}' \
  temp/score.json output/<username>.json > temp/scorer-input.json

# distill 模式
jq -s '.[0] * {profile:.[1].profile,repositories:.[1].repositories,deep_dive:.[1].deep_dive,contributions:.[1].contributions,activity:.[1].activity,organizations:.[1].organizations,gists:.[1].gists}' \
  temp/distill.json output/<username>.json > temp/distill-input.json
```

### Step 2: 渲染

```bash
python scripts/render-report.py temp/<mode>-input.json <mode>
```

输出：`reports/<username>-<mode>-<timestamp>.html`

### Step 3: 报告结果

告知用户文件路径和文件大小。

## HTML 报告特性

每个生成的 HTML 报告包含：

1. **ECharts 交互图表**（雷达图、热力图、Treemap）
2. **社交分享栏**（微信/QQ/X 按钮，点击复制对应平台优化的文本）
3. **Star 提示条**：

```html
<div class="star-banner">
  ⭐ 喜欢这个分析？
  <a href="https://github.com/therain2020/github-profiler" target="_blank">
    github.com/therain2020/github-profiler
  </a>
  — 给项目点个 Star 支持开源 ✨
</div>
```

## 分享机制

| 按钮 | 功能 |
|------|------|
| 微信 | 复制适合微信群粘贴的文本卡片 |
| QQ | 复制适合 QQ 群粘贴的精简文本 |
| X | 打开 X/Twitter 发布页 |
| 复制 | 复制完整 Markdown 格式卡片 |

## 相关 Skill

| Skill | 职责 |
|-------|------|
| `/github-fetch` | 获取原始数据 |
| `/github-scorer` | 生成评分 JSON |
| `/github-distill` | 生成蒸馏 JSON |
| `/github-optimize` | 生成优化方案 |
