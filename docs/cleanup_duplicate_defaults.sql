-- Run this in Supabase Dashboard → SQL Editor
-- Removes duplicate default projects, keeps the fixed UUID one

DELETE FROM projects 
WHERE (name = 'Default' OR is_default = true) 
  AND id != '00000000-0000-0000-0000-000000000001';
