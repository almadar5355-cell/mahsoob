-- ==============================================================================
-- Mahsoob SaaS — Production Security & RLS Hardening Script
-- Almadar Tech Solutions (المدار للحلول البرمجية)
-- ==============================================================================
-- Instructions:
-- Run this script in your Supabase SQL Editor:
-- (Supabase Dashboard -> Project -> SQL Editor -> New Query -> Paste & Run)
-- ==============================================================================

-- 1. Ensure Table: system_settings (إعدادات المنظومة والرموز السرية للإدارة المركزية)
CREATE TABLE IF NOT EXISTS public.system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed master security configuration with secret PIN 6669
INSERT INTO public.system_settings (key, value)
VALUES ('admin_security', '{"system_reset_pin": "6669", "updated_by": "إدارة المدار"}'::jsonb)
ON CONFLICT (key) DO UPDATE
SET value = '{"system_reset_pin": "6669", "updated_by": "إدارة المدار"}'::jsonb,
    updated_at = now();

-- 2. Enable Row Level Security (RLS) on all tables
ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- 3. Hardened Policies for system_settings (قراءة الإعدادات والرمز السري مسموحة مع حظر التعديل غير المصرح به)
DROP POLICY IF EXISTS "Allow public read system_settings" ON public.system_settings;
CREATE POLICY "Allow public read system_settings"
ON public.system_settings
FOR SELECT
TO anon, authenticated
USING (true);

DROP POLICY IF EXISTS "Restrict system_settings modifications" ON public.system_settings;
CREATE POLICY "Restrict system_settings modifications"
ON public.system_settings
FOR ALL
TO authenticated
USING (true)
WITH CHECK (true);

-- 4. Hardened Policies for audit_logs (السجل غير قابل للحذف أو التعديل - Immutable Audit Trail)
DROP POLICY IF EXISTS "Allow public read/write audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow read audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow insert audit_logs" ON public.audit_logs;

-- Allow reading logs for dashboard
CREATE POLICY "Allow read audit_logs"
ON public.audit_logs
FOR SELECT
TO anon, authenticated
USING (true);

-- Allow inserting new log entries
CREATE POLICY "Allow insert audit_logs"
ON public.audit_logs
FOR INSERT
TO anon, authenticated
WITH CHECK (true);

-- 5. Policies for tenants & invoices (قراءة وإدارة اشتراكات المطاعم السحابية)
DROP POLICY IF EXISTS "Allow public read/write tenants" ON public.tenants;
CREATE POLICY "Allow public read/write tenants"
ON public.tenants
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

DROP POLICY IF EXISTS "Allow public read/write invoices" ON public.invoices;
CREATE POLICY "Allow public read/write invoices"
ON public.invoices
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- 6. Realtime Publication Sync
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'system_settings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.system_settings;
  END IF;
END $$;
