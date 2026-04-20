-- Jesus Loop D1 schema. Append-only; UPDATE and DELETE blocked by triggers.

CREATE TABLE IF NOT EXISTS jesus_loop_pairs (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  session_id     TEXT NOT NULL,
  project_dir    TEXT NOT NULL,
  task           TEXT NOT NULL,
  iteration      INTEGER NOT NULL,
  step           INTEGER,
  genesis_day    TEXT,
  harness_ws     TEXT,
  verdict        TEXT,
  verse_ref      TEXT NOT NULL,
  pattern_label  TEXT NOT NULL,
  applied_lesson TEXT NOT NULL,
  outcome        TEXT,
  client_ip      TEXT,
  user_agent     TEXT,
  created_at     TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_jesus_pairs_session ON jesus_loop_pairs(session_id);
CREATE INDEX IF NOT EXISTS idx_jesus_pairs_verse   ON jesus_loop_pairs(verse_ref);
CREATE INDEX IF NOT EXISTS idx_jesus_pairs_step    ON jesus_loop_pairs(step);
CREATE INDEX IF NOT EXISTS idx_jesus_pairs_day     ON jesus_loop_pairs(genesis_day);
CREATE INDEX IF NOT EXISTS idx_jesus_pairs_created ON jesus_loop_pairs(created_at);

CREATE TRIGGER IF NOT EXISTS jesus_loop_pairs_no_update
  BEFORE UPDATE ON jesus_loop_pairs
BEGIN
  SELECT RAISE(FAIL, 'jesus_loop_pairs is immutable: UPDATE blocked');
END;

CREATE TRIGGER IF NOT EXISTS jesus_loop_pairs_no_delete
  BEFORE DELETE ON jesus_loop_pairs
BEGIN
  SELECT RAISE(FAIL, 'jesus_loop_pairs is immutable: DELETE blocked');
END;

-- Migration for older installs (ignore "duplicate column" errors).
-- ALTER TABLE jesus_loop_pairs ADD COLUMN step        INTEGER;
-- ALTER TABLE jesus_loop_pairs ADD COLUMN genesis_day TEXT;
-- ALTER TABLE jesus_loop_pairs ADD COLUMN harness_ws  TEXT;
-- ALTER TABLE jesus_loop_pairs ADD COLUMN verdict     TEXT;
