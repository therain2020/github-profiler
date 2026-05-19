-- GitHub Profiler v2 — Supabase Database Schema (6-dimension)
-- Run this in the Supabase SQL Editor to set up the database.

-- ============================================================
-- 1. Drop old schema (no data migration needed)
-- ============================================================
DROP VIEW IF EXISTS score_history;
DROP VIEW IF EXISTS leaderboard;
DROP TABLE IF EXISTS scores;

-- ============================================================
-- 2. Scores table (6 dimensions, 0-100)
-- ============================================================
CREATE TABLE scores (
  id            BIGSERIAL PRIMARY KEY,
  username      TEXT NOT NULL,
  github_id     INTEGER,
  avatar_url    TEXT,

  -- Six dimension scores (0-100)
  productivity       SMALLINT NOT NULL CHECK (productivity >= 0 AND productivity <= 100),
  influence          SMALLINT NOT NULL CHECK (influence >= 0 AND influence <= 100),
  quality            SMALLINT NOT NULL CHECK (quality >= 0 AND quality <= 100),
  collaboration      SMALLINT NOT NULL CHECK (collaboration >= 0 AND collaboration <= 100),
  knowledge_sharing  SMALLINT NOT NULL CHECK (knowledge_sharing >= 0 AND knowledge_sharing <= 100),
  growth_potential   SMALLINT NOT NULL CHECK (growth_potential >= 0 AND growth_potential <= 100),
  composite_score    NUMERIC(4,1) NOT NULL CHECK (composite_score >= 0 AND composite_score <= 100),

  -- Analysis metadata
  profile_tags    TEXT[],
  summary         TEXT NOT NULL,
  full_report     JSONB,          -- complete analysis result (scoring + distill + optimize)
  github_snapshot JSONB,

  -- Submission metadata
  submitter_id    TEXT,           -- optional: hashed identifier of who submitted

  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ============================================================
-- 3. Indexes
-- ============================================================
CREATE INDEX IF NOT EXISTS idx_scores_username    ON scores(username);
CREATE INDEX IF NOT EXISTS idx_scores_composite   ON scores(composite_score DESC);
CREATE INDEX IF NOT EXISTS idx_scores_created     ON scores(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_scores_productivity ON scores(productivity DESC);
CREATE INDEX IF NOT EXISTS idx_scores_influence   ON scores(influence DESC);

-- ============================================================
-- 4. Leaderboard view (latest score per user)
-- ============================================================
CREATE OR REPLACE VIEW leaderboard AS
SELECT DISTINCT ON (username)
  username,
  avatar_url,
  composite_score,
  productivity,
  influence,
  quality,
  collaboration,
  knowledge_sharing,
  growth_potential,
  profile_tags,
  summary,
  created_at AS scored_at
FROM scores
ORDER BY username, created_at DESC;

-- ============================================================
-- 5. Score history view
-- ============================================================
CREATE OR REPLACE VIEW score_history AS
SELECT
  id,
  username,
  composite_score,
  productivity,
  influence,
  quality,
  collaboration,
  knowledge_sharing,
  growth_potential,
  created_at
FROM scores
ORDER BY username, created_at DESC;

-- ============================================================
-- 6. Stats function
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
-- 7. Row Level Security
-- ============================================================
ALTER TABLE scores ENABLE ROW LEVEL SECURITY;

-- Anyone can read scores
CREATE POLICY "public_read_scores"
  ON scores FOR SELECT
  USING (true);

-- Anyone with the anon key can insert
CREATE POLICY "anon_insert_scores"
  ON scores FOR INSERT
  WITH CHECK (true);
