---
name: github-pipeline
description: 按工作流顺序调度执行全部GitHub分析步骤（fetch→extract→scorer→distill→optimize→report），每个步骤前询问用户
allowed-tools:
  - Bash
  - Read
  - Write
  - AskUserQuestion
triggers:
  - github 调度
  - github pipeline
  - 完整分析流程
  - 执行完整工作流
  - github 一键分析
  - run all github
  - 全流程分析
---

# GitHub 分析流水线调度器

按顺序逐个执行 6 个 Skill，**每个步骤执行前必须询问用户：执行 / 跳过 / 结束**。

## 流水线

```
Step 1: /github-fetch      → 获取原始数据 (~155KB)
Step 2: /github-extract    → 压缩提取 (~50KB)
Step 3: /github-scorer     → 6维评分 (0-100)
Step 4: /github-distill    → 人格蒸馏 + 镜像
Step 5: /github-optimize   → 优化方案
Step 6: /github-report     → 可视化 HTML
```

## 执行规则

1. **Step 1 之前**：检测用户名。如果用户未指定，先用 `export GITHUB_TOKEN="$CAICAI_KEY"` 和 `jq -r '.login'` 自动检测。
2. **每步之前**：用 `AskUserQuestion` 询问用户，三个选项：
   - **执行** — 运行当前步骤
   - **跳过** — 跳过当前步骤，进入下一步
   - **结束** — 终止整个流水线
3. **步骤失败不中止**：如果某步执行失败，报告错误并询问是否继续下一步。
4. **全部完成后**：汇总生成的文件列表。

## 每步询问格式

```
当前步骤: X/6 — <步骤名称>
上一产物: <文件路径> (<大小>)

选项:
  ▶ 执行  — 运行当前步骤，继续流程
  ⏭ 跳过  — 不运行此步骤，继续下一步
  ⏹ 结束  — 终止流水线
```

## 完成汇总

流水线结束后，列出所有生成的产物文件及其大小。

## 注意事项

- 如果用户之前已执行过某些步骤（如 output/<user>.json 已存在），fetch 会自动跳过（24h 幂等），但仍询问用户。
- extract 会覆盖 output/<user>.json，后续步骤读取的是压缩版。
- scorer/distill/optimize 可独立跳过，不影响彼此。
- report 步骤需要对应的分析产物已存在，如果跳过前面的 scorer/distill/optimize 全部跳过，report 也无数据可渲染。
