-- Leads found by searching a map or directory have a website (or none) and an area.
-- Safe to run more than once.
alter table public.leads add column if not exists website  text not null default '';
alter table public.leads add column if not exists location text not null default '';
