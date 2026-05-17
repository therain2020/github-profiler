---
name: github-scorer
description: 基于GitHub公开数据对用户进行多维度分析和评分，支持结果存档与排行榜
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

# GitHub 用户评分器 (GitHub Profiler)

基于 GitHub 公开数据，以资深开源社区专家 + 技术面试官 + 数据分析师的多重视角，对用户进行四维度量化评分（1-5 分制），支持结果上传至共享排行榜。

## 工作流

### Step 1: 验证环境

检查必需环境变量和依赖：

```bash
# 检查 GITHUB_TOKEN
if [ -z "$GITHUB_TOKEN" ]; then
  echo "请先设置 GITHUB_TOKEN 环境变量"
  echo "前往 https://github.com/settings/tokens 创建 Token"
  echo "Token 无需任何权限 scope（仅访问公开数据）"
  exit 1
fi

# 检查依赖
command -v curl && command -v jq && echo "环境就绪"
```

如果用户尚未配置 `GITHUB_TOKEN`，引导他们：
- 前往 https://github.com/settings/tokens → Generate new token (classic)
- 不需要勾选任何 scope（仅访问公开数据）
- 在终端执行 `export GITHUB_TOKEN="ghp_xxxx"`
- 建议写入 `~/.bashrc` 或 `~/.zshrc` 持久化

### Step 2: 获取数据

运行数据获取脚本（输出到 `output/<username>.json`）：

```bash
bash scripts/fetch-github-data.sh <username>
```

脚本特性：
- 自动幂等：24 小时内同一用户不重复请求，用 `--force` 可强制刷新
- 自动速率监控：剩余配额不足时等待或提前终止
- 网络重试：最多 3 次，指数退避
- 降级容错：GraphQL 阶段失败时，REST 数据仍完整保留

脚本输出结构（7 阶段，版本 2.1.0）：
```json
{
  "meta": { "username": "...", "fetched_at": "...", "version": "2.1.0" },
  "profile": { /* 用户基本资料，含 followers/following/public_repos */ },
  "repositories": [ /* 前100个按星标排序的仓库，含 has_issues/wiki/pages/discussions 等 */ ],
  "quality": [ /* Top 5 仓库质量快照：社区健康度 + CI/CD + workflows + deployments */ ],
  "organizations": [ /* 所属组织 */ ],
  "gists": [ /* 公开 Gists（代码片段、笔记） */ ],
  "contributions": { /* 贡献统计 + 日历 + 仓库贡献分布 */ },
  "activity": { /* 最近30 PR + 最近30 Issue */ }
}
```

检查脚本退出码。如果非零，向用户报告对应阶段的具体错误。
```

### Step 3: AI 分析

将数据喂给 AI 进行分析：

1. 读取 `output/<username>.json` 内容（脚本已自动精简关键字段）
2. 读取 `templates/analysis-prompt.md` 提示词模板
3. 将模板中的 `{{USERNAME}}` 替换为实际用户名
4. 将模板中的 `{{GITHUB_DATA}}` 替换为 JSON 数据（如果超过 30KB，优先保留 profile + contributions + activity，repositories 只取前 30 个）
5. 基于提示词和数据进行完整分析，输出 Markdown 格式报告

分析时务必：
- 严格基于数据，不凭空推测
- 评分要有具体数据支撑
- 必须包含"局限性提示"部分
- 输出 JSON 评分块（嵌入报告末尾）

### Step 4: 保存本地报告

将分析报告保存到 `reports/` 目录：

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
mkdir -p reports
# Write the report content to reports/<username>-<timestamp>.md
```

### Step 5: 询问上传（可选）

报告生成后，询问用户是否上传到共享排行榜：

> 分析报告已保存到 `reports/<username>-<timestamp>.md`。是否将此评分上传到共享排行榜？

如果用户同意：

1. 从报告中提取 JSON 评分块
2. 保存评分 JSON 到临时文件 `temp/score.json`
3. 运行上传脚本：

```bash
bash scripts/save-score.sh temp/score.json
```

如果用户尚未配置 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 环境变量，提示他们：
- 前往 https://supabase.com 注册免费账号
- 创建项目后获取 URL 和 anon key
- 在 `~/.bashrc` 或 `~/.zshrc` 中设置环境变量

上传成功后会显示该用户在排行榜上的位置。

### Step 6: 分享卡片

生成可分享的评分卡片：

读取 `templates/share-card.html`，将评分数据填入，保存为 `reports/<username>-share.html`。

告诉用户可以：
- 直接在浏览器打开该 HTML 文件截图分享
- 复制 Markdown 版本的报告到 GitHub Issues / Discussions / 社交媒体

## 错误处理

| 场景 | 处理 |
|------|------|
| `GITHUB_TOKEN` 未设置 | 引导前往 github.com/settings/tokens 创建（无需 scope） |
| Token 无效 | 检查 Token 是否正确，是否已过期 |
| `curl` 或 `jq` 未安装 | 提示安装命令 |
| 用户不存在 | 提示"该 GitHub 用户不存在" |
| REST API 限速 (429) | 脚本自动等待 Retry-After 秒后重试 |
| GraphQL 查询失败 | REST 数据仍完整可用，贡献部分标记为 null |
| 网络超时 | 脚本自动重试 3 次，指数退避 |
| Supabase 上传失败 | 不影响本地报告，提示检查网络和配置 |

## 目录说明

```
temp/       — 临时文件（已 gitignore）
reports/    — 生成的报告和卡片（已 gitignore）
scripts/    — 数据获取和上传脚本
templates/  — 提示词和卡片模板
```

## 示例

```
用户: /github-scorer torvalds
→ 获取 Linus Torvalds 的 GitHub 数据
→ 分析生成四维度评分报告
→ 询问是否上传排行榜
→ 生成分享卡片
```
