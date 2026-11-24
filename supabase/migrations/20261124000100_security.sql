-- ADVIO business app: who can see and change what.
--
-- Every table has Row Level Security switched on, so the database itself enforces these rules
-- no matter what the app does. Nobody who is not logged in can read or write anything.
--
-- Roles (team_members.role)
--   founder    everything
--   sales      all leads, quotations, invoices and maintenance plans; shared client/project info
--   developer  their own assigned tasks, tickets, leads; shared client/project/checklist info
--   designer   same as developer
--   support    all support tickets plus the developer access
--   (a deactivated member has no access at all)
--
-- Finance details: expenses are founder-only. Quotations, invoices and maintenance plans are founder + sales.

create schema if not exists app;
grant usage on schema app to authenticated;

-- Role and id of the team member behind the current login. Null when not logged in or deactivated.
create or replace function app.member_role() returns text
language sql stable security definer set search_path = '' as $$
  select m.role from public.team_members m where m.user_id = (select auth.uid()) and m.active limit 1
$$;

create or replace function app.member_id() returns text
language sql stable security definer set search_path = '' as $$
  select m.id from public.team_members m where m.user_id = (select auth.uid()) and m.active limit 1
$$;

revoke all on function app.member_role() from public, anon;
revoke all on function app.member_id() from public, anon;
grant execute on function app.member_role() to authenticated;
grant execute on function app.member_id() to authenticated;

-- Defence in depth: the anonymous (not logged in) role gets no access to anything.
revoke all on all tables in schema public from anon;
revoke all on all sequences in schema public from anon;

-- ------------------------------------------------------------------ enable RLS everywhere

alter table public.team_members        enable row level security;
alter table public.clients             enable row level security;
alter table public.leads               enable row level security;
alter table public.projects            enable row level security;
alter table public.tasks               enable row level security;
alter table public.checklist_templates enable row level security;
alter table public.project_checklists  enable row level security;
alter table public.quotations          enable row level security;
alter table public.invoices            enable row level security;
alter table public.expenses            enable row level security;
alter table public.tickets             enable row level security;
alter table public.maintenance_plans   enable row level security;
alter table public.automation_rules    enable row level security;
alter table public.activity            enable row level security;
alter table public.notifications       enable row level security;
alter table public.workspace_settings  enable row level security;

-- ------------------------------------------------------------------ team

create policy "members can see the team" on public.team_members
  for select to authenticated using ((select app.member_role()) is not null);
create policy "founder manages the team" on public.team_members
  for all to authenticated
  using ((select app.member_role()) = 'founder')
  with check ((select app.member_role()) = 'founder');

-- ------------------------------------------------------------------ crm

create policy "members can see clients" on public.clients
  for select to authenticated using ((select app.member_role()) is not null);
create policy "members can add clients" on public.clients
  for insert to authenticated with check ((select app.member_role()) is not null);
create policy "members can edit clients" on public.clients
  for update to authenticated
  using ((select app.member_role()) is not null)
  with check ((select app.member_role()) is not null);
create policy "founder deletes clients" on public.clients
  for delete to authenticated using ((select app.member_role()) = 'founder');

create policy "see leads you own, or all as founder/sales" on public.leads
  for select to authenticated
  using ((select app.member_role()) in ('founder', 'sales') or owner_id = (select app.member_id()));
create policy "add leads" on public.leads
  for insert to authenticated
  with check ((select app.member_role()) in ('founder', 'sales') or owner_id = (select app.member_id()));
-- Anyone who can see a lead can hand it to someone else, so the new row only has to be valid, not owned by them.
create policy "edit leads you can see" on public.leads
  for update to authenticated
  using ((select app.member_role()) in ('founder', 'sales') or owner_id = (select app.member_id()))
  with check ((select app.member_role()) is not null);
create policy "founder deletes leads" on public.leads
  for delete to authenticated using ((select app.member_role()) = 'founder');

-- ------------------------------------------------------------------ delivery

create policy "members can see projects" on public.projects
  for select to authenticated using ((select app.member_role()) is not null);
create policy "founder and sales create projects" on public.projects
  for insert to authenticated with check ((select app.member_role()) in ('founder', 'sales'));
create policy "members can edit projects" on public.projects
  for update to authenticated
  using ((select app.member_role()) is not null)
  with check ((select app.member_role()) is not null);
create policy "founder deletes projects" on public.projects
  for delete to authenticated using ((select app.member_role()) = 'founder');

create policy "see your own tasks, or all as founder" on public.tasks
  for select to authenticated
  using ((select app.member_role()) = 'founder' or assignee_id = (select app.member_id()));
create policy "members can add tasks" on public.tasks
  for insert to authenticated with check ((select app.member_role()) is not null);
create policy "edit tasks you can see" on public.tasks
  for update to authenticated
  using ((select app.member_role()) = 'founder' or assignee_id = (select app.member_id()))
  with check ((select app.member_role()) is not null);
create policy "founder deletes tasks" on public.tasks
  for delete to authenticated using ((select app.member_role()) = 'founder');

create policy "members can see templates" on public.checklist_templates
  for select to authenticated using ((select app.member_role()) is not null);
create policy "founder manages templates" on public.checklist_templates
  for all to authenticated
  using ((select app.member_role()) = 'founder')
  with check ((select app.member_role()) = 'founder');

create policy "members can see project checklists" on public.project_checklists
  for select to authenticated using ((select app.member_role()) is not null);
create policy "members can start project checklists" on public.project_checklists
  for insert to authenticated with check ((select app.member_role()) is not null);
create policy "members can update project checklists" on public.project_checklists
  for update to authenticated
  using ((select app.member_role()) is not null)
  with check ((select app.member_role()) is not null);
create policy "founder deletes project checklists" on public.project_checklists
  for delete to authenticated using ((select app.member_role()) = 'founder');

-- ------------------------------------------------------------------ finance

create policy "founder and sales handle quotations" on public.quotations
  for all to authenticated
  using ((select app.member_role()) in ('founder', 'sales'))
  with check ((select app.member_role()) in ('founder', 'sales'));

create policy "founder and sales handle invoices" on public.invoices
  for all to authenticated
  using ((select app.member_role()) in ('founder', 'sales'))
  with check ((select app.member_role()) in ('founder', 'sales'));

create policy "founder handles expenses" on public.expenses
  for all to authenticated
  using ((select app.member_role()) = 'founder')
  with check ((select app.member_role()) = 'founder');

create policy "founder and sales handle maintenance plans" on public.maintenance_plans
  for all to authenticated
  using ((select app.member_role()) in ('founder', 'sales'))
  with check ((select app.member_role()) in ('founder', 'sales'));

-- ------------------------------------------------------------------ support and operations

create policy "see your tickets, or all as founder/support" on public.tickets
  for select to authenticated
  using ((select app.member_role()) in ('founder', 'support') or assignee_id = (select app.member_id()));
create policy "members can open tickets" on public.tickets
  for insert to authenticated with check ((select app.member_role()) is not null);
create policy "edit tickets you can see" on public.tickets
  for update to authenticated
  using ((select app.member_role()) in ('founder', 'support') or assignee_id = (select app.member_id()))
  with check ((select app.member_role()) is not null);
create policy "founder deletes tickets" on public.tickets
  for delete to authenticated using ((select app.member_role()) = 'founder');

create policy "members can see automation rules" on public.automation_rules
  for select to authenticated using ((select app.member_role()) is not null);
create policy "founder manages automation rules" on public.automation_rules
  for all to authenticated
  using ((select app.member_role()) = 'founder')
  with check ((select app.member_role()) = 'founder');

-- The feed mentions money, so finance events are hidden from people who cannot see finance.
create policy "members can see the activity feed" on public.activity
  for select to authenticated
  using (
    (select app.member_role()) is not null
    and (kind not in ('invoice', 'payment', 'expense', 'quotation') or (select app.member_role()) in ('founder', 'sales'))
  );
create policy "members can log activity" on public.activity
  for insert to authenticated with check ((select app.member_role()) is not null);

create policy "see your notifications and broadcasts" on public.notifications
  for select to authenticated
  using ((select app.member_role()) is not null and (user_id is null or user_id = (select app.member_id())));
create policy "members can create notifications" on public.notifications
  for insert to authenticated with check ((select app.member_role()) is not null);
create policy "update your notifications" on public.notifications
  for update to authenticated
  using ((select app.member_role()) is not null and (user_id is null or user_id = (select app.member_id())))
  with check ((select app.member_role()) is not null);
create policy "delete your notifications" on public.notifications
  for delete to authenticated
  using (user_id = (select app.member_id()));

create policy "members can see workspace settings" on public.workspace_settings
  for select to authenticated using ((select app.member_role()) is not null);
create policy "founder edits workspace settings" on public.workspace_settings
  for update to authenticated
  using ((select app.member_role()) = 'founder')
  with check ((select app.member_role()) = 'founder');

-- ------------------------------------------------------------------ realtime

-- Lets the app update live when a teammate changes something. Row Level Security applies to these too.
alter publication supabase_realtime add table
  public.team_members, public.clients, public.leads, public.projects, public.tasks,
  public.project_checklists, public.tickets, public.activity, public.notifications;
