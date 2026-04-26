-- ═══════════════════════════════════════════════════════════════════════════════
-- Admin push notification triggers
-- Notifies all admins via VPS push service when:
--   1. A user uploads a new wave (status = 'pending')
--   2. A user submits a report
--   3. A user requests account deletion
-- ═══════════════════════════════════════════════════════════════════════════════


-- ═══ 1. New wave → notify admins ═══════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_admins_new_wave()
RETURNS trigger AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'http://push:3000/notify-admins-wave',
    headers := jsonb_build_object(
      'content-type',  'application/json',
      'authorization', 'Bearer ' || current_setting('app.push_shared_secret', true)
    ),
    body    := jsonb_build_object(
      'wave_id', NEW.id::text,
      'user_id', NEW.user_id::text
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_wave_notify_admins
  AFTER INSERT ON public.waves
  FOR EACH ROW
  WHEN (NEW.status = 'pending')
  EXECUTE FUNCTION public.notify_admins_new_wave();


-- ═══ 2. New report → notify admins ═════════════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_admins_new_report()
RETURNS trigger AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'http://push:3000/notify-admins-report',
    headers := jsonb_build_object(
      'content-type',  'application/json',
      'authorization', 'Bearer ' || current_setting('app.push_shared_secret', true)
    ),
    body    := jsonb_build_object(
      'report_id',            NEW.id::text,
      'reporter_id',          NEW.reporter_id::text,
      'reported_entity_type', NEW.reported_entity_type,
      'category',             NEW.category
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_new_report_notify_admins
  AFTER INSERT ON public.reports
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_new_report();


-- ═══ 3. New delete request → notify admins ══════════════════════════════════════

CREATE OR REPLACE FUNCTION public.notify_admins_delete_request()
RETURNS trigger AS $$
BEGIN
  PERFORM net.http_post(
    url     := 'http://push:3000/notify-admins-delete-request',
    headers := jsonb_build_object(
      'content-type',  'application/json',
      'authorization', 'Bearer ' || current_setting('app.push_shared_secret', true)
    ),
    body    := jsonb_build_object(
      'request_id', NEW.id::text,
      'user_id',    NEW.user_id::text,
      'reason',     NEW.reason
    )
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_delete_request_notify_admins
  AFTER INSERT ON public.delete_account_requests
  FOR EACH ROW
  EXECUTE FUNCTION public.notify_admins_delete_request();
