-- Run this in Supabase Dashboard → SQL Editor
-- Creates moods table for sync

CREATE TABLE IF NOT EXISTS moods (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id),
  date_key TEXT NOT NULL,
  data TEXT NOT NULL DEFAULT '[]',
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS moods_user_id_idx ON moods(user_id);
CREATE INDEX IF NOT EXISTS moods_date_key_idx ON moods(date_key);

ALTER TABLE moods ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can manage own moods" ON moods
  FOR ALL USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);
