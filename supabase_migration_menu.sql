-- ==============================================================================
-- Mahsoob SaaS Migration — Raw Materials & Menu System & AI Hub
-- Almadar Tech Solutions (المدار للحلول البرمجية)
-- ==============================================================================
-- Run this in your Supabase SQL Editor:
-- (Supabase Dashboard -> Project -> SQL Editor -> New Query -> Paste & Run)
-- ==============================================================================

ALTER TABLE public.tenants
ADD COLUMN IF NOT EXISTS raw_materials JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS menu_categories JSONB DEFAULT '[]'::jsonb,
ADD COLUMN IF NOT EXISTS menu_items JSONB DEFAULT '[]'::jsonb;

-- Ensure Realtime remains active for tenants table
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'tenants'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tenants;
  END IF;
END $$;
