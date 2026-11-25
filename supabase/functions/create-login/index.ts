// Creates (or resets) the login for a team member. Only the founder may call it.
//
// The app cannot do this itself: setting someone's password needs Supabase's admin key, which must never be
// inside an app. This function runs on Supabase's servers, where that key is supplied automatically
// (SUPABASE_SERVICE_ROLE_KEY) and never leaves.
//
// Request:  POST { "memberId": "tm_123", "password": "a temporary password" }
// The new login must change that password when they first sign in (user_metadata.must_change_password).
import { createClient } from 'npm:@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return reply(405, { error: 'Use POST.' });

  const url = Deno.env.get('SUPABASE_URL');
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY');
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (!url || !anonKey || !serviceKey) return reply(500, { error: 'The server is not set up correctly.' });

  // Who is asking? Use the caller's own token, so this cannot be done by guessing an id.
  const token = (req.headers.get('Authorization') ?? '').replace(/^Bearer\s+/i, '');
  if (!token) return reply(401, { error: 'Please sign in again.' });
  const asCaller = createClient(url, anonKey, { global: { headers: { Authorization: `Bearer ${token}` } } });
  const { data: who } = await asCaller.auth.getUser(token);
  if (!who?.user) return reply(401, { error: 'Please sign in again.' });

  const admin = createClient(url, serviceKey, { auth: { persistSession: false, autoRefreshToken: false } });

  const { data: caller } = await admin
    .from('team_members').select('role').eq('user_id', who.user.id).eq('active', true).maybeSingle();
  if (caller?.role !== 'founder') return reply(403, { error: 'Only the founder can create logins.' });

  let body: { memberId?: unknown; password?: unknown };
  try { body = await req.json(); } catch { return reply(400, { error: 'That request was not understood.' }); }
  const memberId = typeof body.memberId === 'string' ? body.memberId : '';
  const password = typeof body.password === 'string' ? body.password : '';
  if (!memberId) return reply(400, { error: 'Choose a team member.' });
  if (password.length < 8 || password.length > 72) return reply(400, { error: 'The password must be 8 to 72 characters.' });

  const { data: member } = await admin
    .from('team_members').select('id, name, email, active, user_id').eq('id', memberId).maybeSingle();
  if (!member) return reply(404, { error: 'That team member was not found.' });
  if (!member.active) return reply(400, { error: 'Reactivate this person before creating a login.' });
  const email = (member.email ?? '').trim().toLowerCase();
  if (!email) return reply(400, { error: 'Add an email address to this team member first.' });
  if (password.toLowerCase() === email) return reply(400, { error: 'The password cannot be the email address.' });

  const metadata = { must_change_password: true, name: member.name };
  let userId = member.user_id as string | null;
  let created = false;

  if (userId) {
    // Already has a login: this is a password reset.
    const { error } = await admin.auth.admin.updateUserById(userId, { password, email_confirm: true, user_metadata: metadata });
    if (error) return reply(400, { error: 'Could not update that password.' });
  } else {
    const { data, error } = await admin.auth.admin.createUser({ email, password, email_confirm: true, user_metadata: metadata });
    if (error || !data.user) {
      // An account with this email may already exist without being linked to the member.
      let found: string | null = null;
      for (let page = 1; page <= 5 && !found; page++) {
        const { data: list } = await admin.auth.admin.listUsers({ page, perPage: 200 });
        found = list?.users.find((u) => (u.email ?? '').toLowerCase() === email)?.id ?? null;
        if (!list || list.users.length < 200) break;
      }
      if (!found) return reply(400, { error: 'Could not create that login. Check the email address.' });
      const { error: updateError } = await admin.auth.admin.updateUserById(found, { password, email_confirm: true, user_metadata: metadata });
      if (updateError) return reply(400, { error: 'Could not update that password.' });
      userId = found;
    } else {
      userId = data.user.id;
      created = true;
    }
    // Link the login to the member (a database rule does this by email too; this makes it certain).
    const { error: linkError } = await admin.from('team_members').update({ user_id: userId }).eq('id', member.id).is('user_id', null);
    if (linkError) return reply(400, { error: 'The login was made but could not be linked. Try again.' });
  }

  return reply(200, { ok: true, created });
});
