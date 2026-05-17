# DESIGN.md — GitHub Profiler

## Design Decisions

### 1. GraphQL over REST
GitHub GraphQL API fetches all profile data in a single request, reducing API calls from ~15 to 1-2 per analysis. This avoids rate limiting issues and speeds up the analysis workflow.

### 2. Claude Code Skill over Standalone CLI
By building as a Claude Code skill, the tool leverages Claude's LLM for the analysis portion — no need to self-host or pay for an LLM API. Users only need `gh` CLI (free) and Claude Code. The skill format also makes installation trivial (copy one file).

The downside is that users must have Claude Code installed. A future web version will remove this dependency.

### 3. Supabase over Self-Hosted DB
Supabase free tier provides:
- Managed Postgres (500MB storage, unlimited API requests)
- Built-in REST API with Row Level Security
- Real-time subscriptions (for future live leaderboard)

This eliminates the need to host and maintain a server. The trade-off is vendor lock-in, but the schema is simple enough to migrate if needed.

### 4. Four-Weight Scoring Model
Scores use weighted average:
- Tech breadth/depth: 30%
- Engineering standards: 25%
- Open source collaboration: 25%
- Community influence: 20%

Weights favor real contribution quality over vanity metrics (stars/followers), while still acknowledging that community impact matters.

### 5. Opt-in Data Sharing
Users must explicitly choose to upload scores. No data leaves the local machine without consent. This respects privacy and makes the tool suitable for analyzing both public figures and personal acquaintances.

### 6. Bash Scripts over Node.js (for data fetching)
`gh` CLI + `jq` + `curl` cover all needs without requiring a Node.js runtime. Bash scripts are POSIX-compatible and work on macOS/Linux/WSL. Windows users can use Git Bash or WSL.

### 7. HTML Share Card (no framework)
The share card is a single self-contained HTML file with inline CSS. No build step, no dependencies, no framework. Can be opened in any browser and screenshotted for sharing.

## Visual Design

### Share Card
- Dark header gradient (#1a1a2e → #0f3460) for a professional, technical feel
- White card body with subtle gray dimension bars
- Color-coded dimension bars: indigo (tech), cyan (engineering), emerald (collab), orange (influence)
- Clean system font stack, no external font dependencies

## Future Considerations

- **Web frontend**: Vue 3 (matching user's existing stack) or Next.js
- **OAuth flow**: GitHub OAuth for user verification before submitting scores
- **Multi-language**: i18n support for analysis prompts and share cards
- **Score weighting customization**: Let users adjust dimension weights
- **Comparison mode**: Side-by-side comparison of two users
- **Organization analysis**: Batch analyze all members of a GitHub org
