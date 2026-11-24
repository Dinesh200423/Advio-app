-- Run once, after the migrations, to create the first account (the founder).
--
-- 1. The founder's login email is set below.
-- 2. Run this in the Supabase SQL editor (Dashboard > SQL Editor).
-- 3. Create the login under Authentication > Users > Add user > Create new user: use the same email,
--    choose a strong password, and tick "Auto Confirm User". The login is linked to this team member
--    automatically, whichever of steps 2 and 3 you do first.
--

insert into public.team_members (id, name, role, email)
values ('tm_founder', 'Dinesh', 'founder', 'advio.md@gmail.com')
on conflict (id) do nothing;
