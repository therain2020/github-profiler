---
name: github-extract
description: 从fetch产物中提取有效信息并压缩（精简时间戳/贡献日历/README），输出取代fetch成为下游输入
allowed-tools:
  - Bash
  - Read
triggers:
  - 提取 github 信息
  - github extract
  - 精简 github 数据
  - 压缩 github 数据
---

# GitHub 数据提取器

**定位：** fetch 和 analysis 之间的数据处理层。从 155KB 原始数据中提取有效信息，压缩到 ~110KB，且信号密度更高。

## 流水线位置

```
/github-fetch   → output/<username>.json  (~155KB)
/github-extract → output/<username>.json  (~110KB, 覆盖)
/github-scorer  → 读取精简后的数据
```

## 工作流

### Step 1: 检查输入

```bash
if [ ! -f "output/<username>.json" ]; then
  echo "请先获取数据: /github-fetch <username>"
  exit 1
fi
```

### Step 2: 提取压缩

```bash
bash scripts/extract-github-data.sh <username>
```

## 压缩规则

| 目标 | 做法 | 节省 |
|------|------|------|
| activity 时间戳 | `2026-03-11T15:14:54Z` → `2026-03-11`；移除冗余 merged 字段 | ~3KB |
| contributions calendar | 删除 color（可从 count 推导）、删除零值日、展平为 `[[date, count],...]` | ~16KB |
| deep_dive README | >3KB 的 README 只保留标题骨架+首尾段落 | ~12KB |

## 相关 Skill

| Skill | 职责 |
|-------|------|
| `/github-fetch` | 获取原始数据（前提） |
| `/github-scorer` | 四维度评分 |
| `/github-distill` | 蒸馏人物画像 |
| `/github-optimize` | 自我优化方案 |
| `/github-report` | 可视化 HTML 报告 |
