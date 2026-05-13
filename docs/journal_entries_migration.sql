-- Run this in Supabase Dashboard → SQL Editor
-- Creates the journal_entries table for cross-device sync of journal entries

CREATE TABLE IF NOT EXISTS journal_entries (
  id TEXT PRIMARY KEY,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  date_key TEXT NOT NULL,
  content TEXT NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_journal_entries_user ON journal_entries(user_id);
CREATE INDEX IF NOT EXISTS idx_journal_entries_date ON journal_entries(user_id, date_key);

ALTER TABLE journal_entries ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage own journal_entries" ON journal_entries;
CREATE POLICY "Users can manage own journal_entries" ON journal_entries
  FOR ALL USING (auth.uid() = user_id);
