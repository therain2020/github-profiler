# CLAUDE.md

This file provides guidance to Claude Code when working with this repository.

## Project Overview

GitHub Profiler — an open-source tool that analyzes GitHub users' public data and produces multi-dimensional scores (0-100 scale). Scores can optionally be uploaded to a shared Supabase leaderboard. The workflow runs as Claude Code slash commands (/github-pipeline orchestrating 6 steps).

## Tech Stack

- **CLI Data Fetching**: `curl` + `jq` + GitHub REST/GraphQL API (via `GITHUB_TOKEN`)
- **AI Analysis**: Claude Code LLM (using structured prompt templates)
- **Shared Backend**: Supabase (Postgres + REST API + RLS)
- **Share Card**: Plain HTML/CSS (no framework)
- **Utility Scripts**: Bash (POSIX-compatible)

## Key Files

| File | Purpose |
|------|---------|
| `.claude/skills/github-pipeline/SKILL.md` | Main orchestrator — 6-step workflow definition |
| `.claude/skills/github-scorer/SKILL.md` | 6-dimension scoring skill (0-100) |
| `scripts/fetch-github-data.sh` | Fetch user data via REST + GraphQL hybrid (7 phases) |
| `scripts/extract-github-data.sh` | Compress fetch output via `_extract.py` |
| `scripts/_extract.py` | Python compression (dedup, trim timestamps, smart README truncation) |
| `scripts/render-report.py` | Generate HTML report from score JSON |
| `scripts/save-score.sh` | Upload score to Supabase |
| `scripts/leaderboard.sh` | Query the shared leaderboard |
| `scripts/setup.sh` | One-command GITHUB_TOKEN config |
| `templates/analysis-prompt.md` | LLM prompt for 6-dimension scoring |
| `templates/distill-prompt.md` | LLM prompt for persona distillation |
| `templates/optimize-prompt.md` | LLM prompt for growth planning |
| `templates/share-card.html` | Shareable score card HTML |
| `supabase/schema.sql` | Database schema (scores table, leaderboard view, RLS) |

## Architecture

```
User invokes /github-pipeline (orchestrates 6 steps)
  Step 1: /github-fetch → fetch-github-data.sh (7 phases)
    profile→repos→orgs→contributions→activity→deep_dive→gists
    Output saved to output/<username>.json (auto-cached 24h)
  Step 2: /github-extract → extract-github-data.sh / _extract.py
    Compress ~155KB → ~50KB (-67%)
  Step 3: /github-scorer → AI analyzes using analysis-prompt.md template
    6-dimension score (0-100) + visualization data
  Step 4: /github-distill → AI generates developer persona + alter ego
  Step 5: /github-optimize → AI generates personalized growth plan
  Step 6: /github-report → render-report.py generates HTML report
    ECharts charts, QR code share, screenshot export

  User optionally uploads to Supabase leaderboard via save-score.sh
```

## Behavioral Rules

- The data-fetching script uses `GITHUB_TOKEN` env var for authentication. Check it's set before running.
- REST API is used for profile/repos/orgs (1 call each). GraphQL for contributions + PRs/Issues. Deep dive (README/commits/issues) and gists round out the 7 phases.
- Script is idempotent — cached data reused within 24h. Use `--force` to refresh.
- Rate limit monitoring is built into the script — do NOT implement additional rate limit logic.
- The `reports/` and `output/` directories store local results — never commit these to git.
- Supabase URL and anon key are configurable via environment variables: `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
