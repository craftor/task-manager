-- Run this in Supabase Dashboard → SQL Editor
-- Creates the default project which is needed for task sync

INSERT INTO projects (id, user_id, name, color, icon, created_at, updated_at)
VALUES ('00000000-0000-0000-0000-000000000001', 
  (SELECT id FROM auth.users LIMIT 1), 
  'Default', '#607D8B', 'folder', now(), now())
ON CONFLICT (id) DO NOTHING;
