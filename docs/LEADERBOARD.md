# 排行榜

## 查看排行榜

### 命令行

```bash
# Top 20
bash scripts/leaderboard.sh

# Top 50
bash scripts/leaderboard.sh 50

# 查看特定用户
bash scripts/leaderboard.sh --user torvalds

# 全局统计
bash scripts/leaderboard.sh --stats
```

### Web（规划中）

后续将提供在线排行榜页面。

## 评分维度说明

每次评分包含四个维度，各维度满分 5.0 分：

| 维度 | 权重 | 评估内容 |
|------|------|----------|
| **技术广度与深度** | 30% | 技术栈跨度、特定领域钻研深度、编程语言多样性 |
| **工程规范** | 25% | README 质量、目录结构、CI/CD、Commit Message 规范、License |
| **开源协作能力** | 25% | PR 参与度、Issue 沟通质量、跨团队/跨组织贡献 |
| **社区影响力** | 20% | Star/Fork 数量、Follower 数、项目被依赖程度 |

## 评分基准

- **1.0-1.9** — 入门：极少公开活动，主要用于浏览或学习
- **2.0-2.9** — 初级：偶尔提交，个人小项目为主
- **3.0-3.9** — 合格：常规使用，有一定项目维护经验
- **4.0-4.5** — 优秀：深度参与开源，项目质量高，有社区影响力
- **4.6-5.0** — 专家：社区领袖级别，行业公认的技术影响力

## 数据来源

所有评分严格基于 GitHub 公开数据：
- 用户 Profile
- 公开仓库（描述、Star、Fork、语言、License）
- Contribution Graph（提交、PR、Issue、Review）
- 组织归属
- PR 和 Issue 活动

评分不访问：私有仓库、工作/GitLab 代码、非 GitHub 平台活动。

## 数据更新

排行榜显示每位用户的最新评分。如果你想更新某用户的评分，重新运行 `/github-scorer` 并上传即可。旧记录保留作为历史追溯。
