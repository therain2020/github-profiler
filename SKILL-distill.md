---
name: github-distill
description: 蒸馏GitHub用户：从公开数据中提取开发者本质，生成人物画像+RPG角色卡+隐藏自我，帮你认识"世界上另一个自己"
allowed-tools:
  - Bash
  - Read
  - Write
triggers:
  - 蒸馏 github 用户
  - 蒸馏自己
  - github distill
  - 提取另一个我
  - 世界上另一个
  - distill github user
---

# GitHub 用户蒸馏器 (GitHub Distill)

**"蒸馏"是什么？** 不是评价，不是打分——是从一个人散落在 GitHub 上的所有碎片（仓库、Issue、语言、提交节奏、Fork 选择）中，提取出那个最纯粹的"技术自我"。就像蒸馏酒：去掉水分和杂质，留下烈酒。

## 和 `/github-scorer` 的区别

| | 评分模式 (scorer) | 蒸馏模式 (distill) |
|---|---|---|
| 做的 | 评判"你有多好" | 提取"你是谁" |
| 输出 | 分数 + 标签 | 人物画像 + 技术 DNA + RPG 角色卡 + 隐藏自我 |
| 语气 | 面试官 | 技术人类学家 |
| 最终物 | 一个数字 | 另一个你 |

**两者共享同一套数据获取脚本，只是分析提示词不同。**

## 工作流

### Step 1: 获取数据

```bash
# 检查是否已有数据（优先复用 scorer 的缓存）
# 如无，运行：
bash scripts/fetch-github-data.sh <username>
```

无 Token 时自动降级为无认证模式。

### Step 2: 蒸馏分析

1. 读取 `output/<username>.json`
2. 读取 `templates/distill-prompt.md` 蒸馏提示词
3. 将 `{{USERNAME}}` → 实际用户名，`{{GITHUB_DATA}}` → JSON 数据
4. 按四层结构输出：人物画像 → 技术 DNA → 隐藏自我 → RPG 角色卡 → 最终蒸馏物
5. **必须输出 JSON 蒸馏块（嵌入报告末尾）**

### Step 3: 生成可视化 HTML 报告（必须）

**蒸馏 JSON 生成后，必须用 `render-report.py` 生成可视化 HTML。不能只在对话中输出文字。**

```bash
# 1. 将蒸馏 JSON 与原始数据合并
jq -s '.[0] * {profile:.[1].profile,repositories:.[1].repositories,quality:.[1].quality,contributions:.[1].contributions,activity:.[1].activity,organizations:.[1].organizations,gists:.[1].gists}' \
  temp/distill.json output/<username>.json > temp/distill-input.json

# 2. 渲染 HTML
python scripts/render-report.py temp/distill-input.json distill
```

输出文件：`reports/<username>-distill-<timestamp>.html`（含 ECharts 图表 + RPG 角色卡 + 分享按钮）

### Step 4 (可选): 基于蒸馏结果的自我优化

蒸馏完成后，可以询问用户：

> 已经提取出"另一个你"。要不要基于这个画像，生成一份个性化的成长建议？包括 Profile 优化、技能路线和下一步行动。

如果用户同意，基于蒸馏结果追加：
- GitHub Profile 优化清单（按优先级排序）
- 本周/本月/本季度行动路线
- 一句话行动建议

### Step 5: 分享

生成文本摘要（适合群组分享）：
```markdown
🔮 @{username} 的蒸馏结果

{distillate}

🧬 技术 DNA: {native_language} / {paradigm_summary}
🎭 RPG 角色: {rpg_class} (Lv.{rpg_level})
🎒 珍贵物品: {treasure}
⚔️ 主线任务: {main_quest}

蒸馏工具：github-profiler
```

## 报告生成

蒸馏完成后，调用 `/github-report` 生成可视化 HTML 报告（含 ECharts 图表 + RPG 角色卡 + 微信/QQ/X 分享按钮）。

## 示例

```
用户: /github-distill therain2020
→ 从已有数据中蒸馏
→ 四层分析：画像/DNA/隐藏自我/RPG
→ 调用 /github-report 生成可视化 HTML
→ 询问是否追加优化建议
```

## 相关 Skill

- `/github-scorer` — GitHub 用户评分（外部面试官视角）
- `/github-report` — 可视化 HTML 报告生成（评分/蒸馏共享）

## 蒸馏 vs 评分的输出对比

| 同一个用户 | scorer 输出 | distill 输出 |
|-----------|-----------|-------------|
| 语言使用 | "技术广度 3.0/5" | "他用 Java 思考世界，Shell 是他顺手捡起的工具" |
| Issue 行为 | "39 个 Issue，全是自己仓库" | "他把 GitHub Issues 当成私人日记本——每个 Issue 都是一块知识化石" |
| 社交 | "社区影响力 1.0/5" | "一个还没被发现的独行建造者，作品是自用的不是展出的" |
