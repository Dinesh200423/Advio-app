# ADVIO

The internal business app for ADVIO, a founder-led web and software studio in Chennai.
It brings leads, clients, projects, delivery checklists, quotations, invoices, expenses,
support and the team into one place.

**Status: prototype.** Everything runs on in-memory sample data. There is no backend,
no real sign-in and nothing is saved: changes last until the app is closed.

## What it covers

- **Leads** with the same fields as the website enquiry form (service, budget band, message), owners, follow-ups and notes.
- **Team**: members and roles, work assigned to people (tasks, leads, projects, support tickets, checklist items), workload per person, "My tasks", and a prompt for work nobody owns.
- **Projects** and **delivery checklists** built from service templates (websites, e-commerce, CRM, mobile app, workflow automation, monthly support).
- **Finance**: quotations, invoices with partial payments, expenses, reports.
- **Automation** rules, **support** tickets and maintenance plans, **settings**.

## Running

```
flutter pub get
flutter run            # Android or iOS device / emulator
flutter test
flutter analyze
```

Sign in with any email and a password of 6+ characters. Use More > Team > Switch to see the app as another team member.

## Look

Colours come from the ADVIO website (grey `#ECECEC`, ink `#1C1C1C`, lime `#D4F53C`) and live in
`lib/core/constants/app_colors.dart`. Inter is used for text and Krona One for titles and the wordmark;
both are bundled in `google_fonts/`.

## Structure

```
lib/
  app/            app widget, theme, router, bottom-nav shell
  core/           constants, shared components, formatters, validators
  data/           models, sample data, repository interface + in-memory implementation
  features/       one folder per module (screens, providers, routes)
  shared/widgets/ widgets shared by a few features
```

## Moving to a real backend (Supabase)

Screens never touch storage directly. They read Riverpod providers that sit on the
`Repository<T>` interface (`data/repositories/repository.dart`):

1. Write Supabase-backed implementations of `Repository<T>`.
2. Override the providers in `data/repositories/repositories.dart`.
3. Replace `features/auth/auth_providers.dart` with real auth, and map the signed-in user to a team member (`features/team/team_providers.dart`).
4. Add roles and permissions (who may see finance, who may edit templates). Today everyone sees everything.

Notifiers currently seed their state synchronously from `getAll()`, so the real implementation should
hydrate that snapshot at startup, or the notifiers should become `AsyncNotifier`s.

## Reliability and monitoring

- **Saving:** changes appear instantly and are saved in the background. A dropped connection is retried automatically;
  if saving still fails the change is undone, the person is told, and a Retry button is offered (lib/data/repositories/repository.dart).
  Saves run in order, so an older save can never overwrite a newer one.
- **Repeating an action is safe:** records get UUIDs on the device, and the two actions that touch two records
  (convert a lead to a client, the automation follow-up task) use predictable ids so a retry or double tap never duplicates.
- **Logging and crash reports:** everything goes through AppLog (lib/core/observability). Set SENTRY_DSN in env.json to send errors
  to Sentry. Without it nothing leaves the device. Logs carry ids and event names only: no names, emails or amounts, and no screenshots.

## Known limits

- No dark theme yet.
- PDF export, file attachments and sending email/WhatsApp are UI only.
- The website enquiry form is not connected to Leads yet (needs the backend).
- The Dart package and Android application id are still named after the original project (`freelance_os`, `com.freelanceos.freelance_os`). The visible app name is ADVIO.
