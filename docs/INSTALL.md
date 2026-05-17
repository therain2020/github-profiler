# 安装指南

## 前置条件

你需要以下工具：

| 工具 | 用途 | 安装方式 |
|------|------|----------|
| **curl** | HTTP 请求 | 通常系统自带 |
| **jq** | JSON 处理 | `winget install jqlang.jq` / `brew install jq` |
| **Claude Code** | AI 分析引擎 | 从 [claude.ai/code](https://claude.ai/code) 安装 |

另外需要一个 **GitHub Personal Access Token**（无需任何权限 scope）：

1. 前往 https://github.com/settings/tokens
2. 点击 **Generate new token (classic)**
3. 不需要勾选任何权限（我们只访问公开数据）
4. 生成后复制 Token（格式：`ghp_xxxxxxxxxxxx`）

## 快速开始

### 1. 克隆仓库

```bash
git clone https://github.com/<your-org>/github-profiler.git
cd github-profiler
```

### 2. 安装 Skill

将 `SKILL.md` 复制到 Claude Code 的 skills 目录：

**Windows (PowerShell):**
```powershell
New-Item -ItemType Directory -Force -Path "$env:USERPROFILE\.claude\skills\github-scorer"
Copy-Item SKILL.md "$env:USERPROFILE\.claude\skills\github-scorer\SKILL.md"
```

**macOS / Linux:**
```bash
mkdir -p ~/.claude/skills/github-scorer
cp SKILL.md ~/.claude/skills/github-scorer/SKILL.md
```

### 3. 设置环境变量

**Windows (PowerShell):**
```powershell
[Environment]::SetEnvironmentVariable('GITHUB_TOKEN', 'ghp_your_token_here', 'User')
```

**macOS / Linux:**
```bash
echo 'export GITHUB_TOKEN="ghp_your_token_here"' >> ~/.bashrc
source ~/.bashrc
```

重启终端（或 Claude Code）后生效。验证：

```bash
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user | jq .login
```

### 4. 测试

在 Claude Code 中运行：

```
/github-scorer torvalds
```

脚本会自动：
- 验证 Token 有效性
- 分 5 个阶段获取数据（REST 3 + GraphQL 2）
- 监控速率限制，不足时自动等待
- 输出到 `output/torvalds.json`
- 24 小时内同一用户再次运行直接复用缓存

如果一切正常，你将在 `reports/` 目录中看到生成的评分报告。

## 可选：配置排行榜上传

如果你希望将评分结果上传到共享排行榜：

### 1. 注册 Supabase

前往 [supabase.com](https://supabase.com) 注册免费账号并创建项目。

### 2. 创建数据库表

在 Supabase Dashboard → SQL Editor 中，粘贴 `supabase/schema.sql` 的内容并执行。

### 3. 获取 API 密钥

Supabase Dashboard → Settings → API，复制：
- **Project URL**（如 `https://xxxxx.supabase.co`）
- **anon public key**

### 4. 设置环境变量

**Windows (PowerShell):**
```powershell
[Environment]::SetEnvironmentVariable('SUPABASE_URL', 'https://xxxxx.supabase.co', 'User')
[Environment]::SetEnvironmentVariable('SUPABASE_ANON_KEY', 'your-anon-key', 'User')
```

**macOS / Linux:**
```bash
echo 'export SUPABASE_URL="https://xxxxx.supabase.co"' >> ~/.bashrc
echo 'export SUPABASE_ANON_KEY="your-anon-key"' >> ~/.bashrc
source ~/.bashrc
```

重启终端（或 Claude Code）后生效。

### 5. 测试上传

先运行一次评分，当询问是否上传时选择"是"，或手动测试：

```bash
bash scripts/save-score.sh temp/test-score.json
```

## 故障排除

### `GITHUB_TOKEN 未设置`

脚本会提示设置 Token。Token 创建地址：https://github.com/settings/tokens（无需勾选任何 scope）。

### `Token 无效`

- 检查 Token 是否正确复制（无多余空格）
- Classic Token 不会过期，但 Fine-grained Token 会
- 尝试 `curl -H "Authorization: Bearer $GITHUB_TOKEN" https://api.github.com/user` 验证

### `用户不存在`

确认 GitHub 用户名拼写正确。注意区分大小写（GitHub 用户名不区分大小写，但建议使用准确的拼写）。

### REST API 限速 (HTTP 429)

脚本内置自动重试机制：检测到 429 后读取 `Retry-After` 头并等待。无需手动干预。

认证用户配额为 5000 次/小时，单次分析约消耗 5-8 次 REST 调用。如果仍频繁限速，检查是否有其他工具共用同一 Token。

### GraphQL 查询失败

GraphQL 部分负责贡献日历和最近 PR/Issue。如果失败，脚本会降级处理 — 基础数据（profile、repos、orgs）仍完整，但贡献统计字段会标记为 `null`。不影响评分报告的主体分析。

### Supabase 上传失败

- 检查 `SUPABASE_URL` 和 `SUPABASE_ANON_KEY` 是否正确设置
- 确认已在 Supabase SQL Editor 中执行了 `schema.sql`
- 检查网络连接

### jq 未安装

脚本的所有 JSON 处理依赖 `jq`。安装方式：
- Windows: `winget install jqlang.jq`
- macOS: `brew install jq`
- Linux: `apt install jq` / `yum install jq`
