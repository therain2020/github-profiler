# GitHub Profiler

[中文](README.zh-CN.md)

Analyzes a GitHub user's public data and produces a 6-dimension score (0-100), a distilled developer persona, a personalized growth plan, and an interactive HTML report. Everything runs as Claude Code slash commands.

## What it does

You point it at a GitHub username. It fetches their public profile, repos, contributions, organizations, gists, PRs, and issues, then runs the data through a chain of LLM analysis steps.

The output is a 6-dimension score (productivity, influence, quality, collaboration, knowledge sharing, growth potential), a distilled developer persona with an alter-ego RPG card, a growth plan with recommendations across five areas, and an interactive HTML report with ECharts charts, QR code sharing, and screenshot export.

You can upload results to a shared Supabase leaderboard if you want.

## Quick start

```bash
git clone https://github.com/therain2020/github-profiler.git
cd github-profiler

# Set up GITHUB_TOKEN (auto-detects gh CLI or guides you through creation)
bash scripts/setup.sh

# Start Claude Code
claude

# Run the full pipeline (each step asks before executing)
/github-pipeline
```

Or run steps individually:

```
/github-fetch              # Phase 1: fetch raw data
/github-extract <username> # Phase 2: compress data (~155KB → ~50KB)
/github-scorer <username>  # Phase 3: 6-dimension score
/github-distill <username> # Phase 4: developer persona + alter ego
/github-optimize <username># Phase 5: growth plan
/github-report scorer      # Phase 6: HTML report
```

## Score dimensions

Each dimension scored 0-100 based on the user's public GitHub data.

| Dimension | What it measures |
|-----------|-----------------|
| Productivity | Commit count, active days, repo count (non-fork) |
| Influence | Followers, stars, forks, org membership |
| Quality | README completeness, commit message quality, project organization |
| Collaboration | PR merge rate, code review activity, cross-project contributions |
| Knowledge sharing | Blog presence, gist activity, README depth, issue discussions |
| Growth potential | Language diversity, account age, activity type distribution |

Composite score is a weighted average across all six dimensions.

## Requirements

- `curl` and `jq` (the fetch script checks this)
- `GITHUB_TOKEN` env var. Create at [github.com/settings/tokens](https://github.com/settings/tokens), no scopes needed for public data. Use `--private` flag with a `repo`-scoped token to include private repos.
- [Claude Code](https://claude.ai/code)
- Optional: Python 3 (for the extract step; if missing, the extract step is skipped)
- Optional: Supabase project (for the leaderboard; set `SUPABASE_URL` and `SUPABASE_ANON_KEY`)

## Project structure

```
github-profiler/
├── scripts/
│   ├── fetch-github-data.sh   # REST + GraphQL hybrid, 7-phase data fetcher
│   ├── extract-github-data.sh # Compress fetch output via _extract.py
│   ├── _extract.py            # Python compression (dedup, trim timestamps, smart README truncation)
│   ├── render-report.py       # Generate HTML report from score data
│   ├── save-score.sh          # Upload score to Supabase leaderboard
│   ├── leaderboard.sh         # Query the shared leaderboard
│   └── setup.sh               # One command GITHUB_TOKEN config
├── templates/
│   ├── analysis-prompt.md     # LLM prompt for 6-dimension scoring
│   ├── distill-prompt.md      # LLM prompt for persona distillation
│   ├── optimize-prompt.md     # LLM prompt for growth planning
│   └── share-card.html        # Standalone score card (no framework)
├── supabase/
│   └── schema.sql             # Scores table + leaderboard view + RLS policies
├── .claude/skills/            # 7 Claude Code skill definitions
│   ├── github-fetch/SKILL.md
│   ├── github-extract/SKILL.md
│   ├── github-scorer/SKILL.md
│   ├── github-distill/SKILL.md
│   ├── github-optimize/SKILL.md
│   ├── github-report/SKILL.md
│   └── github-pipeline/SKILL.md
├── output/                    # Cached fetch results (gitignored)
├── reports/                   # Generated analysis reports (gitignored)
└── temp/                      # Temporary working files (gitignored)
```

## How the fetch works

The fetch script (`scripts/fetch-github-data.sh`) runs in 7 sequential phases:

1. **Profile**: REST API, 1 call. Bio, company, location, followers, etc.
2. **Repos**: REST API, paginated. Up to 100 repos sorted by stars.
3. **Organizations**: REST API, 1 call. Org memberships.
4. **Contributions**: GraphQL, falls back to page scraping without a token. Commit calendar, top repos.
5. **Activity**: GraphQL, falls back to Events API without a token. Recent PRs and issues.
6. **Deep dive**: Top 10 repos. README text, commit messages, issues. Token required.
7. **Gists**: REST API. Public gists with file metadata.

Results are cached in `output/<username>.json` and reused for 24 hours. Use `--force` to refresh.

Without a token, the script runs in degraded mode (~75% data coverage): contributions are scraped from the profile page, PR/issue data comes from the public Events API (90-day window), and deep dive + gists are skipped.

### Script flags

```
bash scripts/fetch-github-data.sh <username>           # Normal fetch with caching
bash scripts/fetch-github-data.sh <username> --force   # Skip cache, refetch
bash scripts/fetch-github-data.sh <username> --stdout  # Also print to stdout
bash scripts/fetch-github-data.sh <username> --private # Include private repos (needs repo scope)
bash scripts/fetch-github-data.sh --private            # Auto-detect user from token
```

## Leaderboard

Optional shared leaderboard backed by Supabase. Each user can upload one score at a time (latest per user is shown).

```bash
# Upload the current score
bash scripts/save-score.sh temp/score.json

# View top 20
bash scripts/leaderboard.sh

# View top 50
bash scripts/leaderboard.sh 50

# Look up a specific user
bash scripts/leaderboard.sh --user torvalds

# Show global stats
bash scripts/leaderboard.sh --stats
```

The database schema is in `supabase/schema.sql`. Run it in the Supabase SQL Editor to set up your own instance. Requires `SUPABASE_URL` and `SUPABASE_ANON_KEY` env vars.

## Development

There's no build step. The scripts are POSIX-compatible bash. Python scripts target Python 3.8+ with no external dependencies (stdlib only).

```bash
# Fetch data for testing
bash scripts/fetch-github-data.sh torvalds --force

# Run the pipeline
/github-pipeline
```

To add a new analysis dimension or modify scoring, edit `templates/analysis-prompt.md`. To change the report design, edit `scripts/render-report.py` and `templates/share-card.html`.

## License

MIT, see [LICENSE](LICENSE) for details.
