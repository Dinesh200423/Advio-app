-- The website enquiry form, as a database function the public site can call.
--
-- The site posts the form to  POST {project url}/rest/v1/rpc/submit_enquiry  using the public anon key.
-- Visitors have no table access at all (anon has no privileges on any table), so this one function is the
-- only door, and it can only do one thing: add an enquiry. It never returns stored data.
--
-- What it does for each enquiry:
--   * checks every field (length, email shape, known service and budget)
--   * silently accepts and drops bot submissions (the form's hidden "website" field is filled in)
--   * if the same email already has an open lead, adds a note to that lead instead of a duplicate
--   * otherwise creates the lead, a follow-up task for tomorrow 11:00 IST, and a notification for everyone
--   * refuses once an hour's worth of enquiries pass a sane limit, so a flood cannot fill the database
--
-- Safe to run more than once.

create or replace function public.submit_enquiry(payload jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare
  v_name     text := btrim(coalesce(payload ->> 'name', ''));
  v_email    text := lower(btrim(coalesce(payload ->> 'email', '')));
  v_company  text := btrim(coalesce(payload ->> 'company', ''));
  v_service  text := btrim(coalesce(payload ->> 'service', ''));
  v_budget   text := btrim(coalesce(payload ->> 'budget', ''));
  v_message  text := btrim(coalesce(payload ->> 'message', ''));
  v_service_key text;
  v_budget_key  text;
  v_value       numeric(14, 2) := 0;
  v_owner    text;
  v_existing public.leads%rowtype;
  v_id       text;
  v_now      timestamptz := now();
  v_due      timestamptz;
  v_label    text;
begin
  -- A real person never sees the hidden field. Pretend it worked so bots learn nothing.
  if btrim(coalesce(payload ->> 'website', '')) <> '' then
    return jsonb_build_object('ok', true);
  end if;

  if char_length(v_name) < 2 or char_length(v_name) > 100 then
    raise exception 'Please enter your name.' using errcode = '22023';
  end if;
  if v_email !~ '^[^\s@]+@[^\s@]+\.[^\s@]{2,}$' or char_length(v_email) > 254 then
    raise exception 'Please enter a valid email address.' using errcode = '22023';
  end if;
  if char_length(v_message) < 10 or char_length(v_message) > 1200 then
    raise exception 'Please describe your project in a few words.' using errcode = '22023';
  end if;
  if char_length(v_company) > 150 then
    raise exception 'That company name is too long.' using errcode = '22023';
  end if;

  v_service_key := case v_service
    when 'Website Development' then 'website'
    when 'Custom Software / Web Application' then 'software'
    when 'Business Automation' then 'automation'
    else 'other'
  end;

  select key, value into v_budget_key, v_value from (values
    ('Under ₹25,000', 'under25k', 20000),
    ('₹25,000 – ₹60,000', 'from25kTo60k', 42500),
    ('₹60,000 – ₹1,50,000', 'from60kTo150k', 105000),
    ('₹1,50,000+', 'above150k', 200000),
    ('Not sure yet', 'unsure', 0)
  ) as b(label, key, value) where b.label = v_budget;

  -- Flood guard: far more than any real day of enquiries within one hour.
  if (select count(*) from public.leads where source = 'website' and created_at > v_now - interval '1 hour') >= 60 then
    raise exception 'We are receiving a lot of enquiries right now. Please try again in a little while.' using errcode = '54000';
  end if;

  v_label := coalesce(nullif(v_company, ''), v_name);
  select id into v_owner from public.team_members where id = 'tm_founder' and active;

  -- The same person enquiring again: add to their open lead rather than creating a second one.
  select * into v_existing from public.leads
   where lower(email) = v_email and status not in ('won', 'lost')
   order by created_at desc limit 1;

  if found then
    -- Cap how much a single lead can grow from the public form.
    if jsonb_array_length(v_existing.notes) < 20 then
      update public.leads set
        notes = jsonb_build_array(jsonb_build_object(
          'id', 'note_' || replace(gen_random_uuid()::text, '-', ''),
          'text', 'Enquired again through the website: ' || v_message,
          'at', to_jsonb(v_now))) || notes,
        history = jsonb_build_array(jsonb_build_object(
          'id', 'act_' || replace(gen_random_uuid()::text, '-', ''),
          'title', 'Enquired again on the website',
          'detail', v_service,
          'at', to_jsonb(v_now),
          'kind', 'lead')) || history
       where id = v_existing.id;
      insert into public.notifications (id, user_id, title, body, at, kind, route)
      values ('n_' || replace(gen_random_uuid()::text, '-', ''), null,
              'Repeat website enquiry', v_existing.name || ' wrote again', v_now, 'lead', '/leads/' || v_existing.id);
    end if;
    return jsonb_build_object('ok', true);
  end if;

  v_id := 'lead_web_' || replace(gen_random_uuid()::text, '-', '');

  insert into public.leads (id, name, company, email, source, status, service, budget, estimated_value, owner_id, interest, created_at, history)
  values (v_id, v_name, v_company, v_email, 'website', 'newLead', v_service_key, v_budget_key, coalesce(v_value, 0), v_owner, v_message, v_now,
          jsonb_build_array(jsonb_build_object(
            'id', 'act_' || replace(gen_random_uuid()::text, '-', ''),
            'title', 'Lead created',
            'detail', 'Source: Website enquiry',
            'at', to_jsonb(v_now),
            'kind', 'lead')));

  -- Tomorrow 11:00 India time, matching what the app's own "new lead" automation does.
  v_due := (date_trunc('day', v_now at time zone 'Asia/Kolkata') + interval '1 day 11 hours') at time zone 'Asia/Kolkata';
  insert into public.tasks (id, title, description, priority, due_date, created_at, assignee_id)
  values ('task_followup_' || v_id, 'Follow up with ' || v_name, 'Website enquiry from ' || v_label || '.', 'medium', v_due, v_now, v_owner)
  on conflict (id) do nothing;

  insert into public.notifications (id, user_id, title, body, at, kind, route)
  values ('n_' || replace(gen_random_uuid()::text, '-', ''), null,
          'New website enquiry', v_label || ' · ' || v_service, v_now, 'lead', '/leads/' || v_id);

  return jsonb_build_object('ok', true);
end;
$$;

-- Only the two API roles may call it; nobody else gets a default grant.
revoke all on function public.submit_enquiry(jsonb) from public;
grant execute on function public.submit_enquiry(jsonb) to anon, authenticated;
