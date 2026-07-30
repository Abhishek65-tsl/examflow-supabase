Deployment Test
# ExamFlow

A responsive assessment platform for Classes 10 and 12. The frontend is React + Vite. Supabase supplies hosted PostgreSQL, Auth and the generated Data API, so no Node server is needed.

## Features

- Email/password authentication and student/admin roles
- Admin CSV test import, draft/publish and delete
- Downloadable CSV template and bundled example
- Timed exam, question palette and server-side automatic grading
- Student attempts, score history and progress charts
- Admin school metrics, student directory and results access
- Responsive desktop/mobile UI
- PostgreSQL Row Level Security
- GitHub Pages deployment workflow

## 1. Create Supabase

1. Create a free project at https://supabase.com.
2. Open **SQL Editor**, paste `supabase/schema.sql`, and run it once.
3. In **Authentication > URL Configuration**, set Site URL to your local or GitHub Pages URL.
4. Copy Project URL and the Publishable key from project settings.

## 2. Configure locally

```bash
cp .env.example .env.local
```

Edit `.env.local`:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_KEY
```

Never put the `service_role` key in this app. The publishable/anon key is intended for browser use when RLS policies are enabled.

## 3. Run

```bash
npm install
npm run dev
```

## 4. Create the first administrator

Sign up normally in the app. Then run this once in Supabase SQL Editor:

```sql
update public.profiles
set role='admin'
where id=(select id from auth.users where email='teacher@example.com');
```

Sign out and sign in again. New accounts default to `student`.

## 5. Import a test

1. Sign in as administrator.
2. Open **Manage tests**.
3. Download the template or use `sample-test.csv`.
4. Keep all rows for one test under a single title.
5. Upload the CSV. It is created as a draft.
6. Review it and click **Publish**.

The simple importer intentionally handles one test per file. Text containing commas is supported because Papa Parse applies standard CSV quoting.

## 6. Deploy to GitHub Pages

1. Create a GitHub repository named `examflow-supabase` and push these files.
2. If the repository has another name, change `base` in `vite.config.js`.
3. In repository **Settings > Secrets and variables > Actions**, create:
   - `VITE_SUPABASE_URL`
   - `VITE_SUPABASE_PUBLISHABLE_KEY`
4. In **Settings > Pages**, choose **GitHub Actions** as the source.
5. Push to `main`. `.github/workflows/deploy.yml` builds and deploys the app.
6. Add the final Pages URL to Supabase Authentication redirect URLs.

## Security design

Correct answers are stored separately in `answer_keys`. Students can read published questions but cannot select answer keys. `submit_test` is a PostgreSQL security-definer function that calculates grades in the database, records the attempt atomically, and returns only the result. RLS limits students to their own attempts while administrators can access school data.

For real school use, add institutional privacy terms, account recovery rules, audit exports, automated backups, accessibility testing, and a paid plan/SLA before relying on the system for high-stakes exams.

## Project structure

```text
src/
  components/       UI, exam, admin and analytics
  lib/              Supabase and CSV utilities
  App.jsx
  styles.css
supabase/schema.sql Database, grading RPC and RLS
.github/workflows/  GitHub Pages deployment
sample-test.csv
```
