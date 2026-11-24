-- Linking a login to a team member, in either order.
--
-- The first migration links a login to a team member when the LOGIN is created (or confirmed).
-- That only works if the team member row already exists. In practice you may add the team member
-- in the app first, or create the login in the Supabase dashboard first. This makes both work:
-- when a team member row is created or its email changes, it is linked to the confirmed login that
-- has the same email, if there is one.
--
-- Only confirmed logins are linked, for the same reason as before: an unconfirmed account proves nothing
-- about who owns the email address.

create or replace function public.link_login_to_member() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  if new.user_id is null and new.email <> '' then
    select u.id into new.user_id
      from auth.users u
     where lower(u.email) = lower(new.email)
       and u.email_confirmed_at is not null
       and not exists (select 1 from public.team_members other where other.user_id = u.id and other.id <> new.id)
     limit 1;
  end if;
  return new;
end;
$$;

create trigger link_login_to_member
before insert or update of email on public.team_members
for each row execute function public.link_login_to_member();

-- Catch up anyone who already exists but was never linked (for example, the founder, if the
-- login was created before the first team member row).
update public.team_members m
   set user_id = u.id
  from auth.users u
 where m.user_id is null
   and m.email <> ''
   and lower(u.email) = lower(m.email)
   and u.email_confirmed_at is not null
   and not exists (select 1 from public.team_members other where other.user_id = u.id);
