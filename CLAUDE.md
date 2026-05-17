# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

GitHub Profiler — an open-source tool that analyzes GitHub users' public data and produces multi-dimensional scores (1-5 scale). Scores can optionally be uploaded to a shared Supabase leaderboard.

## Tech Stack

- **CLI Data Fetching**: `curl` + `jq` + GitHub REST/GraphQL API (via `GITHUB_TOKEN`)
- **AI Analysis**: Claude Code LLM (using structured prompt templates)
- **Shared Backend**: Supabase (Postgres + REST API + RLS)
- **Share Card**: Plain HTML/CSS (no framework)
- **Utility Scripts**: Bash (POSIX-compatible)

## Key Files

| File | Purpose |
|------|---------|
| `SKILL.md` | Claude Code skill definition — the core workflow |
| `scripts/fetch-github-data.sh` | Fetch user data via REST + GraphQL hybrid (5 phases) |
| `scripts/save-score.sh` | Upload score to Supabase |
| `scripts/leaderboard.sh` | Query the shared leaderboard |
| `templates/analysis-prompt.md` | AI analysis prompt template |
| `templates/share-card.html` | Shareable score card HTML |
| `supabase/schema.sql` | Database schema |

## Architecture

```
User invokes /github-scorer <username>
  → fetch-github-data.sh (5 phases: profile→repos→orgs→contrib→activity)
  → Output saved to output/<username>.json (auto-cached 24h)
  → AI analyzes using analysis-prompt.md template
  → Report saved locally to reports/<username>-<timestamp>.md
  → User optionally uploads to Supabase leaderboard
  → Share card generated
```

## Behavioral Rules

- The data-fetching script uses `GITHUB_TOKEN` env var for authentication. Check it's set before running.
- REST API is used for profile/repos/orgs (1 point each). GraphQL only for contributions + PRs/Issues.
- Script is idempotent — cached data reused within 24h. Use `--force` to refresh.
- Rate limit monitoring is built into the script — do NOT implement additional rate limit logic.
- The `reports/` and `output/` directories store local results — never commit these to git.
- Supabase URL and anon key are configurable via environment variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
