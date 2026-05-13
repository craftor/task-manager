-- Run this in Supabase Dashboard → SQL Editor
-- Adds missing columns to tasks table for full sync

ALTER TABLE tasks ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS parent_task_id TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS tags TEXT;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS estimated_minutes INTEGER;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS actual_minutes INTEGER;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS is_recurring BOOLEAN DEFAULT false;
ALTER TABLE tasks ADD COLUMN IF NOT EXISTS recurring_rule TEXT;
