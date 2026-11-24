-- ADVIO business app: tables.
--
-- Conventions
--   * Primary keys are text because the app generates ids on the device ("lead_<uuid>").
--   * Main fields are real columns. Nested lists that belong to one record (notes, history,
--     line items, milestones, checklist stages) are jsonb, stored on the parent row.
--     Trade-off: two people editing the same record's list at the same moment can overwrite each other.
--   * References to other records are plain text ids and are not enforced for clients/projects
--     (the app lets you delete a client and keep its projects). References to team members
--     are enforced and become null if the member row is ever removed.
--   * updated_at is maintained by a trigger so the app can detect changes.

create or replace function public.set_updated_at() returns trigger
language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- ------------------------------------------------------------------ team

create table public.team_members (
  id         text primary key,
  user_id    uuid unique references auth.users (id) on delete set null,
  name       text not null,
  role       text not null check (role in ('founder', 'developer', 'designer', 'sales', 'support')),
  email      text not null default '',
  phone      text not null default '',
  active     boolean not null default true,
  joined_at  timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create unique index team_members_email_key on public.team_members (lower(email)) where email <> '';

-- ------------------------------------------------------------------ crm

create table public.clients (
  id         text primary key,
  name       text not null,
  company    text not null default '',
  email      text not null default '',
  phone      text not null default '',
  address    text not null default '',
  website    text not null default '',
  status     text not null default 'active',
  created_at timestamptz not null default now(),
  notes      jsonb not null default '[]',
  history    jsonb not null default '[]',
  updated_at timestamptz not null default now()
);

create table public.leads (
  id              text primary key,
  name            text not null,
  company         text not null default '',
  email           text not null default '',
  phone           text not null default '',
  source          text not null,
  status          text not null,
  service         text not null default 'other',
  budget          text,
  estimated_value numeric(14, 2) not null default 0,
  owner_id        text references public.team_members (id) on delete set null,
  interest        text not null default '',
  website         text not null default '',
  location        text not null default '',
  created_at      timestamptz not null default now(),
  follow_ups      jsonb not null default '[]',
  notes           jsonb not null default '[]',
  history         jsonb not null default '[]',
  updated_at      timestamptz not null default now()
);
create index leads_owner_idx on public.leads (owner_id);
create index leads_status_idx on public.leads (status);

-- ------------------------------------------------------------------ delivery

create table public.projects (
  id          text primary key,
  name        text not null,
  client_id   text not null,
  status      text not null,
  budget      numeric(14, 2) not null default 0,
  start_date  timestamptz not null,
  end_date    timestamptz not null,
  description text not null default '',
  owner_id    text references public.team_members (id) on delete set null,
  milestones  jsonb not null default '[]',
  files       jsonb not null default '[]',
  history     jsonb not null default '[]',
  updated_at  timestamptz not null default now()
);
create index projects_client_idx on public.projects (client_id);
create index projects_owner_idx on public.projects (owner_id);

create table public.tasks (
  id          text primary key,
  title       text not null,
  description text not null default '',
  project_id  text,
  priority    text not null default 'medium',
  status      text not null default 'todo',
  due_date    timestamptz not null,
  created_at  timestamptz not null default now(),
  assignee_id text references public.team_members (id) on delete set null,
  updated_at  timestamptz not null default now()
);
create index tasks_assignee_idx on public.tasks (assignee_id);
create index tasks_due_idx on public.tasks (due_date);
create index tasks_project_idx on public.tasks (project_id);

create table public.checklist_templates (
  id          text primary key,
  name        text not null,
  category    text not null,
  description text not null default '',
  stages      jsonb not null default '[]',
  updated_at  timestamptz not null default now()
);

-- A project's own copy of a template. Editing the template never changes these rows.
create table public.project_checklists (
  id             text primary key,
  project_id     text not null,
  template_id    text not null,
  template_name  text not null,
  category       text not null,
  service_period text,
  created_at     timestamptz not null default now(),
  stages         jsonb not null default '[]',
  updated_at     timestamptz not null default now()
);
create index project_checklists_project_idx on public.project_checklists (project_id);

-- ------------------------------------------------------------------ finance

create table public.quotations (
  id               text primary key,
  number           text not null unique,
  client_id        text not null,
  title            text not null,
  items            jsonb not null default '[]',
  issue_date       timestamptz not null,
  valid_until      timestamptz not null,
  status           text not null default 'draft',
  discount_percent numeric(6, 2) not null default 0,
  tax_percent      numeric(6, 2) not null default 0,
  notes            text not null default '',
  terms            text not null default '',
  updated_at       timestamptz not null default now()
);

create table public.invoices (
  id               text primary key,
  number           text not null unique,
  client_id        text not null,
  project_id       text,
  items            jsonb not null default '[]',
  issue_date       timestamptz not null,
  due_date         timestamptz not null,
  status           text not null default 'draft',
  discount_percent numeric(6, 2) not null default 0,
  tax_percent      numeric(6, 2) not null default 0,
  notes            text not null default '',
  payments         jsonb not null default '[]',
  updated_at       timestamptz not null default now()
);
create index invoices_client_idx on public.invoices (client_id);

create table public.expenses (
  id           text primary key,
  title        text not null,
  amount       numeric(14, 2) not null,
  category     text not null,
  date         timestamptz not null,
  vendor       text not null default '',
  notes        text not null default '',
  receipt_name text,
  updated_at   timestamptz not null default now()
);
create index expenses_date_idx on public.expenses (date);

-- ------------------------------------------------------------------ support and operations

create table public.tickets (
  id          text primary key,
  number      text not null unique,
  title       text not null,
  client_id   text not null,
  description text not null default '',
  priority    text not null default 'medium',
  status      text not null default 'open',
  created_at  timestamptz not null default now(),
  assignee_id text references public.team_members (id) on delete set null,
  notes       jsonb not null default '[]',
  updated_at  timestamptz not null default now()
);
create index tickets_assignee_idx on public.tickets (assignee_id);

create table public.maintenance_plans (
  id          text primary key,
  client_id   text not null,
  name        text not null,
  monthly_fee numeric(14, 2) not null default 0,
  next_review timestamptz not null,
  includes    jsonb not null default '[]',
  active      boolean not null default true,
  updated_at  timestamptz not null default now()
);

create table public.automation_rules (
  id         text primary key,
  name       text not null,
  trigger    text not null,
  action     text not null,
  kind       text not null,
  enabled    boolean not null default true,
  runs       integer not null default 0,
  last_run   timestamptz,
  updated_at timestamptz not null default now()
);

create table public.activity (
  id     text primary key,
  title  text not null,
  detail text,
  at     timestamptz not null default now(),
  kind   text not null default 'note'
);
create index activity_at_idx on public.activity (at desc);

-- user_id null means the notification is for everyone.
create table public.notifications (
  id      text primary key,
  user_id text references public.team_members (id) on delete cascade,
  title   text not null,
  body    text not null default '',
  at      timestamptz not null default now(),
  kind    text not null default 'note',
  read    boolean not null default false,
  route   text
);
create index notifications_user_idx on public.notifications (user_id, at desc);

-- One row of company-wide settings (business details, currency, default tax).
create table public.workspace_settings (
  id                   boolean primary key default true check (id),
  business_name        text not null default 'ADVIO',
  business_address     text not null default 'Chennai, India',
  tax_id               text not null default '',
  website              text not null default '',
  phone                text not null default '',
  currency             text not null default 'INR',
  default_tax_percent  numeric(6, 2) not null default 18,
  updated_at           timestamptz not null default now()
);
insert into public.workspace_settings default values;

-- ------------------------------------------------------------------ updated_at triggers

do $$
declare t text;
begin
  foreach t in array array[
    'team_members', 'clients', 'leads', 'projects', 'tasks', 'checklist_templates', 'project_checklists',
    'quotations', 'invoices', 'expenses', 'tickets', 'maintenance_plans', 'automation_rules', 'workspace_settings'
  ] loop
    execute format('create trigger set_updated_at before update on public.%I for each row execute function public.set_updated_at()', t);
  end loop;
end;
$$;

-- ------------------------------------------------------------------ link logins to team members

-- When someone accepts an invite, attach their login to the team member with the same email.
--
-- This only happens once the email address is CONFIRMED. Otherwise anyone could register an account with a
-- teammate's address (without owning it) and claim that team member's role before the real person arrives.
-- An invited person's address is confirmed when they accept the invite, which fires the update branch.
create or replace function public.link_team_member() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.email_confirmed_at is not null then
    update public.team_members
       set user_id = new.id
     where lower(email) = lower(new.email) and user_id is null;
  end if;
  return new;
end;
$$;

create trigger link_team_member after insert or update of email_confirmed_at on auth.users
for each row execute function public.link_team_member();
