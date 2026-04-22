-- Auto-mark waves as transcoding_ready 5 minutes after admin approval.
-- Replaces the immediate-flip trigger from 20_wave_approval_trigger.sql
-- because flipping on-approve happens before Bunny has actually finished
-- transcoding. A 5-minute delay assumes transcoding is done by then, and
-- removes the dependency on Bunny's webhook which was unreliable.

-- 1. Remove the old immediate-flip trigger + function.
DROP TRIGGER IF EXISTS trg_mark_transcoding_ready_on_approve ON public.waves;
DROP FUNCTION IF EXISTS public.fn_mark_transcoding_ready_on_approve();

-- 2. Enable pg_cron (Supabase exposes it under `extensions` schema).
-- If this fails, enable the extension first via
-- Supabase Dashboard → Database → Extensions → pg_cron → enable.
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- 3. Schedule the job: every minute, flip any approved wave that's been
-- approved for 5+ minutes and isn't yet marked ready.
-- cron.schedule is idempotent by job name.
SELECT cron.schedule(
  'mark-waves-transcoding-ready',
  '* * * * *',  -- every minute
  $$
    UPDATE public.waves
    SET transcoding_ready = true
    WHERE status = 'approved'
      AND transcoding_ready = false
      AND approved_at IS NOT NULL
      AND approved_at < (now() - INTERVAL '5 minutes')
  $$
);

-- To remove later:
--   SELECT cron.unschedule('mark-waves-transcoding-ready');
