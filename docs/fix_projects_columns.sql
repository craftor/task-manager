-- Run this in Supabase Dashboard → SQL Editor
-- Fixes missing columns in the projects table

-- Add missing columns (skip if already exist)
ALTER TABLE projects ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS start_date TIMESTAMPTZ;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS end_date TIMESTAMPTZ;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS sort_order INTEGER DEFAULT 0;
ALTER TABLE projects ADD COLUMN IF NOT EXISTS is_default BOOLEAN DEFAULT false;
