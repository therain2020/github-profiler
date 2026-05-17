-- GitHub Profiler — Supabase Database Schema
-- Run this in the Supabase SQL Editor to set up the database.

-- ============================================================
-- 1. Scores table
-- ============================================================
CREATE TABLE IF NOT EXISTS scores (
  id          BIGSERIAL PRIMARY KEY,
  username    TEXT NOT NULL,
  github_id   INTEGER,
  avatar_url  TEXT,

  -- Four dimension scores (1.0 - 5.0)
  tech_score        NUMERIC(2,1) NOT NULL CHECK (tech_score >= 1.0 AND tech_score <= 5.0),
  engineering_score NUMERIC(2,1) NOT NULL CHECK (engineering_score >= 1.0 AND engineering_score <= 5.0),
  collab_score      NUMERIC(2,1) NOT NULL CHECK (collab_score >= 1.0 AND collab_score <= 5.0),
  influence_score   NUMERIC(2,1) NOT NULL CHECK (influence_score >= 1.0 AND influence_score <= 5.0),
  composite_score   NUMERIC(2,1) NOT NULL CHECK (composite_score >= 1.0 AND composite_score <= 5.0),

  -- Analysis metadata
  profile_tags    TEXT[],
  summary         TEXT NOT NULL,
  full_report     TEXT,
  github_snapshot JSONB,

  -- Submission metadata
  submitter_id    TEXT,  -- optional: hashed identifier of who submitted

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 2. Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_scores_username    ON scores(username);
CREATE INDEX IF NOT EXISTS idx_scores_composite   ON scores(composite_score DESC);
CREATE INDEX IF NOT EXISTS idx_scores_created     ON scores(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scores_tech        ON scores(tech_score DESC);
CREATE INDEX IF NOT EXISTS idx_scores_influence   ON scores(influence_score DESC);

-- ============================================================
-- 3. Leaderboard view (latest score per user)
-- ============================================================
CREATE OR REPLACE VIEW leaderboard AS
SELECT DISTINCT ON (username)
  username,
  avatar_url,
  composite_score,
  tech_score,
  engineering_score,
  collab_score,
  influence_score,
  profile_tags,
  summary,
  created_at AS scored_at
FROM scores
ORDER BY username, created_at DESC;

-- ============================================================
-- 4. Score history view
-- ============================================================
CREATE OR REPLACE VIEW score_history AS
SELECT
  id,
  username,
  composite_score,
  tech_score,
  engineering_score,
  collab_score,
  influence_score,
  created_at
FROM scores
ORDER BY username, created_at DESC;

-- ============================================================
-- 5. Stats function
-- ============================================================
CREATE OR REPLACE FUNCTION get_stats()
RETURNS JSON AS $$
DECLARE
  total_users BIGINT;
  total_scores BIGINT;
  avg_composite NUMERIC;
  top_user RECORD;
  recent_scores JSON;
BEGIN
  SELECT COUNT(DISTINCT username) INTO total_users FROM scores;
  SELECT COUNT(*) INTO total_scores FROM scores;
  SELECT ROUND(AVG(composite_score)::numeric, 2) INTO avg_composite FROM leaderboard;

  SELECT username, composite_score INTO top_user
  FROM leaderboard ORDER BY composite_score DESC LIMIT 1;

  SELECT json_agg(row_to_json(t)) INTO recent_scores
  FROM (
    SELECT username, composite_score, profile_tags, created_at
    FROM scores
    ORDER BY created_at DESC
    LIMIT 10
  ) t;

  RETURN json_build_object(
    'total_users_scored', total_users,
    'total_submissions', total_scores,
    'average_score', avg_composite,
    'top_user', json_build_object(
      'username', top_user.username,
      'score', top_user.composite_score
    ),
    'recent_scores', COALESCE(recent_scores, '[]'::json)
  );
END;
$$ LANGUAGE plpgsql STABLE;

-- ============================================================
-- 6. Row Level Security
-- ============================================================
ALTER TABLE scores ENABLE ROW LEVEL SECURITY;

-- Anyone can read scores
CREATE POLICY "public_read_scores"
  ON scores FOR SELECT
  USING (true);

-- Anyone can read leaderboard (it's a view, but underlying table needs SELECT)
-- already covered by the policy above

-- Insert: anyone with the anon key can insert (relies on Supabase API key protection)
-- For production, add a shared secret check here
CREATE POLICY "anon_insert_scores"
  ON scores FOR INSERT
  WITH CHECK (true);
