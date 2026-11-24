// Runs the migrations and the website-enquiry function in an in-process Postgres (PGlite) and checks what an
// anonymous visitor can and cannot do. No database or network needed.
//   cd <a temp folder> && npm init -y && npm i @electric-sql/pglite && node <path>/enquiry_check.mjs <path to this repo>
import { PGlite } from '@electric-sql/pglite';
import fs from 'node:fs';
const root = process.argv[2];
const db = new PGlite();
await db.exec(`
  create role anon nologin; create role authenticated nologin;
  create schema auth;
  create table auth.users (id uuid primary key default gen_random_uuid(), email text, email_confirmed_at timestamptz);
  create function auth.uid() returns uuid language sql as $$ select null::uuid $$;
  create publication supabase_realtime;
`);
const files = fs.readdirSync(root + '/supabase/migrations').sort();
for (const f of files) {
  try { await db.exec(fs.readFileSync(root + '/supabase/migrations/' + f, 'utf8')); console.log('ok  ', f); }
  catch (e) { console.log('FAIL', f, e.message); }
}
await db.exec(fs.readFileSync(root + '/supabase/seed.sql', 'utf8'));
await db.exec('grant usage on schema public to anon');

const call = async (p) => { try { const r = await db.query('select public.submit_enquiry($1::jsonb) as r', [JSON.stringify(p)]); return r.rows[0].r; } catch (e) { return 'ERR: ' + e.message; } };
const q = async (s) => (await db.query(s)).rows;
await db.exec('set role anon');
const base = { name: 'Neha Verma', email: 'Neha@Craftly.in', company: 'Craftly', service: 'Website Development', budget: '₹25,000 – ₹60,000', message: 'We need a marketplace website.' };

console.log('valid       ', await call(base));
console.log('direct read ', await q('select 1 from public.leads').then(() => 'ALLOWED (bad)').catch(e => 'refused: ' + e.message));
console.log('direct write', await db.exec("insert into public.leads(id,name,source,status) values('x','x','website','newLead')").then(() => 'ALLOWED (bad)').catch(e => 'refused: ' + e.message));
await db.exec('reset role');
console.log('lead        ', JSON.stringify(await q("select id,name,company,email,source,status,service,budget,estimated_value,owner_id,interest from public.leads")));
console.log('task        ', JSON.stringify(await q("select id,title,description,assignee_id,due_date from public.tasks")));
console.log('notif       ', JSON.stringify(await q("select title,body,user_id,kind,route from public.notifications")));
console.log('history     ', JSON.stringify(await q("select history from public.leads")));
await db.exec('set role anon');
console.log('repeat      ', await call({ ...base, email: 'neha@craftly.in', message: 'Also need a logo please' }));
console.log('bot         ', await call({ ...base, email: 'bot@x.com', website: 'http://spam' }));
console.log('bad email   ', await call({ ...base, email: 'nope' }));
console.log('short msg   ', await call({ ...base, message: 'hi' }));
console.log('no name     ', await call({ ...base, name: ' ' }));
console.log('long company', await call({ ...base, company: 'x'.repeat(200) }));
console.log('weird svc   ', await call({ ...base, email: 'a@b.co', service: 'drop table', budget: 'lots' }));
await db.exec('reset role');
console.log('counts      ', JSON.stringify(await q("select (select count(*) from public.leads) leads,(select count(*) from public.tasks) tasks,(select count(*) from public.notifications) notifs")));
console.log('lead notes  ', JSON.stringify(await q("select name, notes from public.leads where email='neha@craftly.in'")));
console.log('weird row   ', JSON.stringify(await q("select service,budget,estimated_value from public.leads where email='a@b.co'")));
await db.exec('set role anon');
await db.exec("reset role; insert into public.leads(id,name,source,status,created_at) select 'f'||g,'f','website','lost',now() from generate_series(1,60) g; set role anon");
console.log('flood       ', await call({ ...base, email: 'late@x.com' }));
