# Backend setup (Supabase)

The database lives in Supabase. Everything needed to create it is in `migrations/`:

| File | What it does |
|---|---|
| `20261124000000_schema.sql` | Tables, indexes, change-tracking triggers, and the link from a login to a team member |
| `20261124000100_security.sql` | Row Level Security: who can see and change what, by role |
| `20261124000200_link_logins.sql` | Links a login to a team member whichever is created first |
| `20261124000300_lead_website_location.sql` | Website and area columns on leads |
| `20261124000400_website_enquiry.sql` | The function the website's enquiry form calls |
| `20261124000500_modules.sql` | Per-person module switches, and the access rules built on them |
| `../seed.sql` | Creates the first (founder) team member. Run once, by hand |

## One-time setup

1. **Create a project** at supabase.com. Pick the region closest to Chennai.
2. **Turn off public sign-ups:** Authentication > Sign In / Providers > uncheck *Allow new users to sign up*.
   Accounts are invite-only.
3. **Install and log in to the CLI** (one time, from this folder). It opens a browser:
   ```
   npx supabase login
   npx supabase init
   npx supabase link --project-ref YOUR-PROJECT-REF
   ```
4. **Create the tables and rules:**
   ```
   npx supabase db push
   ```
5. **Create the founder:** run `seed.sql` in Dashboard > SQL Editor (the email is already set), then create the
   login under Authentication > Users > Add user > Create new user with that same email, a strong password, and
   *Auto Confirm User* ticked. Either order works.
6. **Optional: crash reports.** Create a free project at sentry.io (platform: Flutter) and put its DSN in env.json as SENTRY_DSN.
7. **Give the app its keys:** copy `env.example.json` to `env.json` (it is git-ignored), fill in the project URL and
   the **anon** key (Project Settings > API), then run `flutter run --dart-define-from-file=env.json`.

Never put the `service_role` key in the app, in `env.json` or in git.

## Adding people

1. In the app: Team, add them with a name, role and email, and switch on the modules they should use.
2. Open their profile and tap **Create login**. Set (or accept) a temporary password and pass it on privately. They
   are asked to choose their own the first time they sign in.

The first time, deploy the function that does this (it holds the admin key the app must never have):

```
npx supabase login
npx supabase functions deploy create-login --remote=YOUR-PROJECT-REF --use-api --workdir .
```

Run it from the project root. The admin key is supplied to the function by Supabase itself; you never copy it anywhere.
To remove someone's access, deactivate them in the Team screen.

## Modules

Every team member has a list of modules they may use: Leads, Clients, Projects, Tasks, Delivery checklists,
Quotations, Invoices and payments, Expenses, Support and maintenance, Automation, Reports. The founder always has all of them.

A module that is switched off is hidden in the app and closed in the database. Where work is assigned (leads, tasks, tickets)
the person can still read what is assigned to them, but cannot change it. Deleting, templates, automation rules and the team list
stay with the founder. New members start from their role's usual modules:

| | Leads | Clients | Projects | Tasks | Checklists | Quotations | Invoices | Expenses | Support | Automation | Reports |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Sales | yes | yes | yes | yes | yes | yes | yes | | yes | | yes |
| Developer / Designer | | yes | yes | yes | yes | | | | yes | | |
| Support | | yes | yes | yes | yes | | | | yes | | yes |
