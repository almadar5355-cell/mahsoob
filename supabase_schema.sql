-- ==============================================================================
-- Mahsoob SaaS Database Schema — Supabase PostgreSQL
-- Almadar Tech Solutions (المدار للحلول البرمجية)
-- ==============================================================================
-- Run this script in your Supabase SQL Editor:
-- (Supabase Dashboard -> Project -> SQL Editor -> New Query -> Paste & Run)
-- ==============================================================================

-- 1. Table: tenants (المطاعم والتراخيص السحابية)
CREATE TABLE IF NOT EXISTS public.tenants (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    city TEXT NOT NULL DEFAULT 'البصرة',
    owner_name TEXT NOT NULL DEFAULT '',
    owner_phone TEXT NOT NULL DEFAULT '',
    license_key TEXT UNIQUE NOT NULL,
    status TEXT NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended', 'trial')),
    subscription_type TEXT NOT NULL DEFAULT 'سنوي',
    subscription_fee NUMERIC NOT NULL DEFAULT 1800000,
    currency TEXT NOT NULL DEFAULT 'IQD',
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '1 year'),
    last_payment_date TIMESTAMPTZ NOT NULL DEFAULT now(),
    max_branches INTEGER NOT NULL DEFAULT 10,
    max_staff INTEGER NOT NULL DEFAULT 50,
    suspension_message TEXT DEFAULT '',
    branches JSONB NOT NULL DEFAULT '["الفرع الرئيسي"]'::jsonb,
    features JSONB NOT NULL DEFAULT '{
        "cashierShift": true,
        "purchasing": true,
        "supervisor": true,
        "warehouse": true,
        "kitchenChef": true,
        "ownerExecutive": true,
        "aiReceipts": true,
        "cookingBatches": true,
        "stealthMode": true,
        "pdfReports": true,
        "branchTransfers": true
    }'::jsonb,
    staff JSONB NOT NULL DEFAULT '[]'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- 2. Table: invoices (الاشتراكات والفوترة)
CREATE TABLE IF NOT EXISTS public.invoices (
    id TEXT PRIMARY KEY,
    tenant_id TEXT NOT NULL REFERENCES public.tenants(id) ON DELETE CASCADE,
    tenant_name TEXT NOT NULL,
    amount NUMERIC NOT NULL DEFAULT 0,
    period TEXT NOT NULL DEFAULT 'اشتراك سنوي',
    date TIMESTAMPTZ NOT NULL DEFAULT now(),
    status TEXT NOT NULL DEFAULT 'paid'
);

-- 3. Table: audit_logs (سجل العمليات والرقابة)
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id TEXT PRIMARY KEY,
    time TIMESTAMPTZ NOT NULL DEFAULT now(),
    actor TEXT NOT NULL DEFAULT 'إدارة المدار',
    action TEXT NOT NULL,
    details TEXT
);

-- 4. Table: system_settings (إعدادات المنظومة والرموز السرية للإدارة المركزية)
CREATE TABLE IF NOT EXISTS public.system_settings (
    key TEXT PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Seed master security configuration with secret PIN 6669
INSERT INTO public.system_settings (key, value)
VALUES ('admin_security', '{"system_reset_pin": "6669", "updated_by": "إدارة المدار"}'::jsonb)
ON CONFLICT (key) DO UPDATE
SET value = '{"system_reset_pin": "6669", "updated_by": "إدارة المدار"}'::jsonb;

-- ==============================================================================
-- Row Level Security (RLS) Policies
-- ==============================================================================
-- Allow anonymous/public access for Mahsoob SaaS Dashboard & Mobile App

ALTER TABLE public.tenants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.system_settings ENABLE ROW LEVEL SECURITY;

-- Drop existing policies if re-running
DROP POLICY IF EXISTS "Allow public read/write tenants" ON public.tenants;
DROP POLICY IF EXISTS "Allow public read/write invoices" ON public.invoices;
DROP POLICY IF EXISTS "Allow public read/write audit_logs" ON public.audit_logs;
DROP POLICY IF EXISTS "Allow public read system_settings" ON public.system_settings;

CREATE POLICY "Allow public read system_settings"
ON public.system_settings
FOR SELECT
TO anon, authenticated
USING (true);

-- Policies for tenants
CREATE POLICY "Allow public read/write tenants"
ON public.tenants
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- Policies for invoices
CREATE POLICY "Allow public read/write invoices"
ON public.invoices
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- Policies for audit_logs
CREATE POLICY "Allow public read/write audit_logs"
ON public.audit_logs
FOR ALL
TO anon, authenticated
USING (true)
WITH CHECK (true);

-- ==============================================================================
-- Enable Realtime for instant synchronization (Kill-Switch)
-- ==============================================================================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND tablename = 'tenants'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.tenants;
  END IF;
END $$;
