-- Run this in Supabase Dashboard → SQL Editor
-- Creates the special_days table for cross-device sync of special days

CREATE TABLE IF NOT EXISTS special_days (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date_key TEXT NOT NULL,
  data JSONB NOT NULL DEFAULT '{}',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_special_days_user ON special_days(user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_special_days_ukey ON special_days(user_id, date_key);

ALTER TABLE special_days ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own special_days" ON special_days;
CREATE POLICY "Users can manage own special_days" ON special_days
  FOR ALL USING (auth.uid() = user_id);
