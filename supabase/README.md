# Backend setup (Supabase)

The database lives in Supabase. Everything needed to create it is in `migrations/`:

| File | What it does |
|---|---|
| `20261124000000_schema.sql` | Tables, indexes, change-tracking triggers, and the link from a login to a team member |
| `20261124000100_security.sql` | Row Level Security: who can see and change what, by role |
| `20261124000200_link_logins.sql` | Links a login to a team member whichever is created first |
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

1. Add them in the app's Team screen (name, role and email).
2. Create their login under Authentication > Users > Add user > Create new user: the same email, a password you give
   them, and *Auto Confirm User* ticked.

The login is linked to the team member by email, in either order, and their role applies from their next sign-in.
To remove someone's access, deactivate them in the Team screen.

## Who can see what

| | founder | sales | developer / designer | support |
|---|---|---|---|---|
| Team list, clients, projects, checklists, templates | all | all | all | all |
| Leads | all | all | own | own |
| Tasks | all | own | own | own |
| Tickets | all | own | own | all |
| Quotations, invoices, maintenance plans | all | all | none | none |
| Expenses | all | none | none | none |
| Edit templates, automation, settings, team | yes | no | no | no |

"Own" means assigned to that person. A deactivated team member has no access at all.
