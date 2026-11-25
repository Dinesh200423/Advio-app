// Runs every migration in an in-process Postgres (PGlite) and checks the module switches as different people.
//   cd <a temp folder> && npm init -y && npm i @electric-sql/pglite && node <path>/modules_check.mjs <path to this repo>
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';

const root = process.argv[2];
const db = new PGlite();
await db.exec(`
  create role anon nologin; create role authenticated nologin;
  create schema auth;
  create table auth.users (id uuid primary key default gen_random_uuid(), email text, email_confirmed_at timestamptz);
  create function auth.uid() returns uuid language sql stable as $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create publication supabase_realtime;
`);
for (const f of fs.readdirSync(root + '/supabase/migrations').sort()) {
  try { await db.exec(fs.readFileSync(root + '/supabase/migrations/' + f, 'utf8')); console.log('ok  ', f); }
  catch (e) { console.log('FAIL', f, e.message); process.exit(1); }
}

// Supabase gives logged-in users table access by default; Row Level Security then decides which rows.
await db.exec('grant usage on schema public to authenticated; grant all on all tables in schema public to authenticated;');

// People: a founder, a sales person, a developer with Leads off, and a developer given Expenses.
const ids = {};
for (const [key, id, role, mods] of [
  ['founder', 'tm_f', 'founder', []],
  ['sales', 'tm_s', 'sales', ['leads', 'tasks', 'invoices']],
  ['dev', 'tm_d', 'developer', ['tasks', 'clients']],
  ['devPlus', 'tm_p', 'developer', ['tasks', 'expenses']],
  ['nobody', 'tm_n', 'designer', []],
]) {
  const u = (await db.query(`insert into auth.users(email, email_confirmed_at) values ('${key}@x.com', now()) returning id`)).rows[0].id;
  ids[key] = { user: u, member: id };
  await db.exec(`insert into public.team_members(id, name, role, email, user_id, modules) values ('${id}', '${key}', '${role}', '${key}@x.com', '${u}', '{${mods.join(',')}}') on conflict (id) do update set user_id='${u}', modules='{${mods.join(',')}}', role='${role}'`);
}
await db.exec(`
  insert into public.leads(id,name,source,status,owner_id) values ('l_mine_dev','Dev lead','website','newLead','tm_d'),('l_other','Other lead','website','newLead','tm_s');
  insert into public.tasks(id,title,due_date,assignee_id) values ('t_dev','dev task',now(),'tm_d'),('t_other','other task',now(),'tm_s');
  insert into public.invoices(id,number,client_id,issue_date,due_date,status) values ('inv1','INV-1','c1',now(),now(),'draft');
  insert into public.expenses(id,title,amount,category,date) values ('e1','Hosting',100,'tools',now());
`).catch(e => console.log('seed note:', e.message.slice(0, 120)));

const as = async (who, fn) => {
  await db.exec(`select set_config('request.jwt.claim.sub', '${ids[who].user}', false); set role authenticated`);
  try { return await fn(); } finally { await db.exec('reset role'); }
};
const count = (sql) => async () => { try { return (await db.query(sql)).rows.length; } catch (e) { return 'ERR ' + e.message.slice(0, 50); } };
const tryWrite = (sql) => async () => { try { const r = await db.query(sql); return r.affectedRows ?? 'ok'; } catch (e) { return 'refused'; } };

let failures = 0;
const check = (label, got, want) => { const ok = got === want; if (!ok) failures++; console.log(ok ? 'ok  ' : 'FAIL', label, ok ? '' : `(got ${got}, wanted ${want})`); };

check('founder sees every lead', await as('founder', count('select * from public.leads')), 2);
check('sales (leads on) sees every lead', await as('sales', count('select * from public.leads')), 2);
check('developer (leads off) sees only their own lead', await as('dev', count('select * from public.leads')), 1);
check('developer cannot change their own lead (read-only)', await as('dev', tryWrite("update public.leads set name='x' where id='l_mine_dev' returning id")), 0);
check('developer cannot add a lead', await as('dev', tryWrite("insert into public.leads(id,name,source,status,owner_id) values ('new','n','website','newLead','tm_d')")), 'refused');
check('sales can add a lead', await as('sales', tryWrite("insert into public.leads(id,name,source,status,owner_id) values ('new2','n','website','newLead','tm_s')")), 1);
check('developer (tasks on) sees all tasks', await as('dev', count('select * from public.tasks')), 2);
check('designer with nothing sees no tasks', await as('nobody', count('select * from public.tasks')), 0);
check('sales (invoices on) sees invoices', await as('sales', count('select * from public.invoices')), 1);
check('developer sees no invoices', await as('dev', count('select * from public.invoices')), 0);
check('developer without expenses sees none', await as('dev', count('select * from public.expenses')), 0);
check('developer given Expenses sees them', await as('devPlus', count('select * from public.expenses')), 1);
check('sales does not see expenses', await as('sales', count('select * from public.expenses')), 0);
check('developer (clients on) can read clients table', await as('dev', count('select * from public.clients')), 0);
check('a member cannot give themselves modules', await as('dev', tryWrite("update public.team_members set modules='{expenses}' where id='tm_d' returning id")), 0);
check('founder can change someone\'s modules', await as('founder', tryWrite("update public.team_members set modules='{tasks,leads}' where id='tm_d' returning id")), 1);
check('after that, the developer sees all leads', await as('dev', count('select * from public.leads')), 3);
check('only the founder can delete a task', await as('dev', tryWrite("delete from public.tasks where id='t_dev' returning id")), 0);
await db.exec('reset role');
await db.exec(`update public.team_members set active=false where id='tm_s'`);
check('a deactivated member sees nothing', await as('sales', count('select * from public.leads')), 0);

console.log(failures ? `\n${failures} FAILED` : '\nall passed');
process.exit(failures ? 1 : 0);
