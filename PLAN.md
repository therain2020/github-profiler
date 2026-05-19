# GitHub Profiler — Development Roadmap

一个分析 GitHub 用户公开数据、生成多维度评分与开发者人格画像的在线工具。

## 当前状态

本地 CLI 模式已可用，包含 7 个 Claude Code skill：

- `/github-fetch` — REST + GraphQL 混合抓取（7 阶段，含降级模式）
- `/github-extract` — 数据压缩（~155KB → ~50KB，-67%）
- `/github-scorer` — 六维评分（0-100：生产力/影响力/质量/协作/知识分享/成长潜力）
- `/github-distill` — 开发者人格蒸馏 + "世界上的另一个我"镜像角色
- `/github-optimize` — 个性化成长方案（5 大板块，含时间线）
- `/github-report` — 交互式 HTML 报告（ECharts + 二维码分享 + 截图导出）
- `/github-pipeline` — 一键调度全部步骤

可选上传到 Supabase 共享排行榜。

## 目标

将 GitHub Profiler 从本地 CLI 工具升级为在线 Web 应用。

## 路线图

### Phase 1: 轻量 Web 版 - Online MVP

**后端** Python FastAPI，**前端** Vue 3 + Vite，**部署** 腾讯云轻量服务器。

核心思路：用户自带 GitHub token + 大模型 API key，平台只做代理和渲染。

- 网页输入框 → 后端代理 GitHub API 抓数据 → 调用户选的 LLM 生成分析 → 结果页展示
- SSE 实时推送分析进度
- 支持 DeepSeek / 通义千问 / OpenAI / Claude 四种 LLM
- 六维雷达图 + 人格卡片 + 成长建议 + 一键下载报告图片

**为什么不用我们的 token 和 API key？**

平台不承担 GitHub API 限流和 LLM 调用费用。用户用自己的 key，数据更透明，用完随时吊销。

### Phase 2: 社交与留存

- OAuth 登录（GitHub 一键登录）
- 分析历史记录
- 排行榜改版（本月最活跃 / 进步最快 / 语言分榜）
- 用户主页（展示成绩单）

### Phase 3: 对比与组织

- 双人对比模式
- GitHub 组织批量分析
- 技术栈迁徙轨迹（从 commit 历史推断技术方向变化）
- REST API 开放

### Phase 4: 国际化

- i18n 多语言
- 海外部署（Vercel / Railway）
- 适配 GitHub 国际市场

---

## 技术栈（Web 版）

| 层 | 选型 |
|---|------|
| 前端 | Vue 3 + TypeScript + Vite |
| 图表 | ECharts |
| 截图 | html2canvas |
| 后端 | Python FastAPI |
| HTTP 客户端 | httpx + aiohttp |
| LLM 适配 | 统一适配层（OpenAI 兼容 + Anthropic 原生） |
| 持久化 | Supabase (Postgres + REST) |
| 部署 | 腾讯云轻量服务器 + Nginx |

## 反馈与贡献

Issues 和 PR 欢迎。详见 [LICENSE](LICENSE)。
