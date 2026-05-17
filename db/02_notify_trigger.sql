-- ============================================================================
-- Trigger: notify admin (via Edge Function → Resend) on new pending remembrance.
-- Builds the same payload shape that a native Supabase DB Webhook would send,
-- then POSTs it via pg_net (async, won't block the visitor's insert).
-- ============================================================================

-- pg_net provides net.http_post; not enabled by default on all projects.
create extension if not exists pg_net;

create or replace function public.notify_pending_remembrance()
returns trigger
language plpgsql
security definer  -- runs as the function owner so it can call net.http_post
set search_path = public, net
as $$
begin
  -- Skip non-pending inserts (e.g. admin re-inserts or future imports).
  if NEW.status <> 'pending' then
    return NEW;
  end if;

  perform net.http_post(
    url     := 'https://tmnfqdmklbauznpoqrll.supabase.co/functions/v1/notify-pending',
    headers := '{"Content-Type":"application/json"}'::jsonb,
    body    := jsonb_build_object(
      'type',       TG_OP,
      'table',      TG_TABLE_NAME,
      'schema',     TG_TABLE_SCHEMA,
      'record',     to_jsonb(NEW),
      'old_record', null
    )
  );

  return NEW;
end;
$$;

drop trigger if exists notify_pending_remembrance_trigger on public.remembrances;

create trigger notify_pending_remembrance_trigger
  after insert on public.remembrances
  for each row
  execute function public.notify_pending_remembrance();

-- ---------- Test (run separately after creating the trigger) ----------
-- insert into remembrances (name, connection, message)
-- values ('Webhook Live Test', 'self', 'Trigger → function → Resend → inbox');
--
-- Then check engineerbk@gmail.com and clean up:
-- delete from remembrances where name = 'Webhook Live Test';
