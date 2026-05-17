---
name: github-distill
description: 蒸馏GitHub用户：从公开数据中提取开发者本质，生成人物画像+RPG角色卡+隐藏自我
allowed-tools:
  - Bash
  - Read
  - Write
triggers:
  - 蒸馏 github 用户
  - 蒸馏自己
  - github distill
  - 提取另一个我
  - distill github user
---

# GitHub 用户蒸馏器

**"蒸馏"是什么？** 从散落在 GitHub 上的碎片（仓库、Issue、语言、提交节奏、Fork 选择）中，提取最纯粹的"技术自我"。像蒸馏酒：去掉水分和杂质，留下烈酒。

**前提：** 需要 `output/<username>.json` 已存在（由 `/github-fetch` + `/github-extract` 生成）。如果没有，提示用户先运行 `/github-fetch <username>` 然后 `/github-extract <username>`。

## 和 `/github-scorer` 的区别

| | scorer | distill |
|---|--------|---------|
| 视角 | 面试官（评判你多好） | 技术人类学家（提取你是谁） |
| 输出 | 分数 + 标签 | 人物画像 + 技术DNA + RPG角色卡 + 隐藏自我 |
| 最终物 | 一个数字 | 另一个你 |

## 工作流

### Step 1: 检查数据

```bash
if [ ! -f "output/<username>.json" ]; then
  echo "请先获取数据: /github-fetch <username>"
  exit 1
fi
```

### Step 2: 蒸馏分析

1. 读取 `output/<username>.json`
2. 读取 `templates/distill-prompt.md` 蒸馏提示词
3. 替换 `{{USERNAME}}` 和 `{{GITHUB_DATA}}`
4. 按四层结构输出：人物画像 → 技术DNA → 隐藏自我 → RPG角色卡 → 最终蒸馏物
5. **必须输出 JSON 蒸馏块（嵌入报告末尾）**，保存到 `temp/distill.json`

### Step 3: 提示下一步

蒸馏完成后提示：
- `/github-report distill` — 生成可视化 HTML（含 RPG 角色卡 + 分享）
- `/github-optimize <username>` — 基于蒸馏结果生成优化方案

## 相关 Skill

| Skill | 职责 |
|-------|------|
| `/github-fetch` | 获取数据（前提） |
| `/github-scorer` | 四维度评分 |
| `/github-optimize` | 自我优化方案 |
| `/github-report` | 可视化 HTML 报告 |
