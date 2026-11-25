-- Per-person module switches.
--
-- Each team member has a list of modules they may use (team_members.modules). The founder always has all of them.
-- A module that is switched off hides that area of the app AND closes it in the database, so hiding a screen is never
-- the only protection. Where work can be assigned to a person (leads, tasks, tickets), they can still READ the items
-- assigned to them even with the module off, but cannot change them.
--
-- Deleting stays with the founder. Templates, automation rules and the team list are still managed by the founder only.
-- Safe to run more than once.

alter table public.team_members add column if not exists modules text[] not null default '{}';

-- People who already exist get the defaults for their role. New members get theirs from the app.
update public.team_members set modules = case role
  when 'founder' then array['leads','clients','projects','tasks','checklists','quotations','invoices','expenses','support','automation','reports']
  when 'sales'   then array['leads','clients','projects','tasks','checklists','quotations','invoices','support','reports']
  when 'support' then array['clients','projects','tasks','checklists','support','reports']
  else                array['clients','projects','tasks','checklists','support']
end
where modules = '{}';

create or replace function app.has_module(module_name text) returns boolean
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select m.role = 'founder' or module_name = any (m.modules)
       from public.team_members m
      where m.user_id = (select auth.uid()) and m.active
      limit 1),
    false)
$$;
revoke all on function app.has_module(text) from public, anon;
grant execute on function app.has_module(text) to authenticated;

-- ------------------------------------------------------------------ clients

drop policy if exists "members can see clients" on public.clients;
drop policy if exists "members can add clients" on public.clients;
drop policy if exists "members can edit clients" on public.clients;
create policy "clients module: see" on public.clients
  for select to authenticated using ((select app.has_module('clients')));
create policy "clients module: add" on public.clients
  for insert to authenticated with check ((select app.has_module('clients')));
create policy "clients module: edit" on public.clients
  for update to authenticated using ((select app.has_module('clients'))) with check ((select app.has_module('clients')));

-- ------------------------------------------------------------------ leads

drop policy if exists "see leads you own, or all as founder/sales" on public.leads;
drop policy if exists "add leads" on public.leads;
drop policy if exists "edit leads you can see" on public.leads;
create policy "leads module: see all, or your own" on public.leads
  for select to authenticated using ((select app.has_module('leads')) or owner_id = (select app.member_id()));
create policy "leads module: add" on public.leads
  for insert to authenticated with check ((select app.has_module('leads')));
create policy "leads module: edit" on public.leads
  for update to authenticated using ((select app.has_module('leads'))) with check ((select app.has_module('leads')));

-- ------------------------------------------------------------------ projects and checklists

drop policy if exists "members can see projects" on public.projects;
drop policy if exists "founder and sales create projects" on public.projects;
drop policy if exists "members can edit projects" on public.projects;
create policy "projects module: see" on public.projects
  for select to authenticated using ((select app.has_module('projects')));
create policy "projects module: add" on public.projects
  for insert to authenticated with check ((select app.has_module('projects')));
create policy "projects module: edit" on public.projects
  for update to authenticated using ((select app.has_module('projects'))) with check ((select app.has_module('projects')));

drop policy if exists "members can see templates" on public.checklist_templates;
create policy "checklists module: see templates" on public.checklist_templates
  for select to authenticated using ((select app.has_module('checklists')));

drop policy if exists "members can see project checklists" on public.project_checklists;
drop policy if exists "members can start project checklists" on public.project_checklists;
drop policy if exists "members can update project checklists" on public.project_checklists;
create policy "checklists module: see" on public.project_checklists
  for select to authenticated using ((select app.has_module('checklists')));
create policy "checklists module: start" on public.project_checklists
  for insert to authenticated with check ((select app.has_module('checklists')));
create policy "checklists module: update" on public.project_checklists
  for update to authenticated using ((select app.has_module('checklists'))) with check ((select app.has_module('checklists')));

-- ------------------------------------------------------------------ tasks

drop policy if exists "see your own tasks, or all as founder" on public.tasks;
drop policy if exists "members can add tasks" on public.tasks;
drop policy if exists "edit tasks you can see" on public.tasks;
create policy "tasks module: see all, or your own" on public.tasks
  for select to authenticated using ((select app.has_module('tasks')) or assignee_id = (select app.member_id()));
create policy "tasks module: add" on public.tasks
  for insert to authenticated with check ((select app.has_module('tasks')));
create policy "tasks module: edit" on public.tasks
  for update to authenticated using ((select app.has_module('tasks'))) with check ((select app.has_module('tasks')));

-- ------------------------------------------------------------------ money

drop policy if exists "founder and sales handle quotations" on public.quotations;
create policy "quotations module" on public.quotations
  for all to authenticated using ((select app.has_module('quotations'))) with check ((select app.has_module('quotations')));

drop policy if exists "founder and sales handle invoices" on public.invoices;
create policy "invoices module" on public.invoices
  for all to authenticated using ((select app.has_module('invoices'))) with check ((select app.has_module('invoices')));

drop policy if exists "founder handles expenses" on public.expenses;
create policy "expenses module" on public.expenses
  for all to authenticated using ((select app.has_module('expenses'))) with check ((select app.has_module('expenses')));

-- ------------------------------------------------------------------ support

drop policy if exists "founder and sales handle maintenance plans" on public.maintenance_plans;
create policy "support module: maintenance plans" on public.maintenance_plans
  for all to authenticated using ((select app.has_module('support'))) with check ((select app.has_module('support')));

drop policy if exists "see your tickets, or all as founder/support" on public.tickets;
drop policy if exists "members can open tickets" on public.tickets;
drop policy if exists "edit tickets you can see" on public.tickets;
create policy "support module: see all, or your own" on public.tickets
  for select to authenticated using ((select app.has_module('support')) or assignee_id = (select app.member_id()));
create policy "support module: open" on public.tickets
  for insert to authenticated with check ((select app.has_module('support')));
create policy "support module: edit" on public.tickets
  for update to authenticated using ((select app.has_module('support'))) with check ((select app.has_module('support')));

-- ------------------------------------------------------------------ activity feed

-- Money events are only shown to people who can use the matching module.
drop policy if exists "members can see the activity feed" on public.activity;
create policy "members can see the activity feed" on public.activity
  for select to authenticated
  using (
    (select app.member_role()) is not null
    and (kind not in ('invoice', 'payment') or (select app.has_module('invoices')))
    and (kind <> 'quotation' or (select app.has_module('quotations')))
    and (kind <> 'expense' or (select app.has_module('expenses')))
  );
