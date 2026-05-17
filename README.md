# GitHub Profiler

基于 GitHub 公开数据对用户进行多维度分析与量化评分，支持排行榜和分享。

## 两种使用方式

### 方式一：Claude Code Skill（推荐）

```bash
# 1. 克隆仓库
git clone https://github.com/<your-org>/github-profiler.git
cd github-profiler

# 2. 设置 Token
export GITHUB_TOKEN="ghp_xxxx"

# 3. 安装 Skill 到 Claude Code
cp SKILL.md ~/.claude/skills/github-scorer/SKILL.md

# 4. 开始使用
/github-scorer torvalds
```

### 方式二：在线评分（规划中）

后续将提供 Web 界面，直接输入用户名即可评分。

## 评分维度

| 维度 | 权重 | 说明 |
|------|------|------|
| 技术广度与深度 | 30% | 技术栈跨度及对特定领域的钻研程度 |
| 工程规范 | 25% | 文档、Commit Message 规范性及项目完整度 |
| 开源协作能力 | 25% | PR、Issue 的参与深度及跨团队协作表现 |
| 社区影响力 | 20% | 产出对外部开发者的吸引力与贡献度 |

## 前置条件

- `curl` + `jq`（通常系统自带 / 一键安装）
- `GITHUB_TOKEN` 环境变量（前往 github.com/settings/tokens 创建，无需任何权限 scope）
- Claude Code（用于 AI 分析）
- 可选：Supabase 账号（用于上传结果到排行榜）

## 快速开始

详见 [INSTALL.md](docs/INSTALL.md)

## 排行榜

上传到共享数据库后，可查看[公开排行榜](docs/LEADERBOARD.md)。

## 许可

MIT License — 详见 [LICENSE](LICENSE)
