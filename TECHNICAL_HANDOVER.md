# ExamFlow: Technical and AI Handover Documentation

> **Purpose:** Concise but complete project context for developers and AI coding assistants such as Cursor, GitHub Copilot, or ChatGPT.  
> **Current state:** Working React/Vite application deployed through GitHub Pages and connected directly to Supabase.  
> **Repository name assumed by deployment:** `examflow-supabase`.

## 1. Project objective

ExamFlow is a responsive web assessment platform for secondary-school students, initially targeting Classes 10 and 12. Teachers or administrators create and publish multiple-choice tests, preferably through a simple CSV upload. Students register, sign in, take timed tests, submit answers, and review their scores and progress. Administrators receive test, student, attempt, and performance summaries.

The project intentionally avoids a custom Node/Express backend in its first version. The React frontend communicates directly with Supabase, which provides hosted PostgreSQL, authentication, a generated Data API, and PostgreSQL functions. Database access is controlled through Row Level Security (RLS), while grading is executed inside PostgreSQL so correct answers are not exposed to the student browser.

### Primary goals

- Make test creation easy for non-technical teachers.
- Support student and administrator roles through one application and one login page.
- Provide a modern, card-based, mobile-responsive interface.
- Keep initial hosting and infrastructure costs at or near zero.
- Preserve data integrity and prevent students from downloading answer keys.
- Keep the architecture simple enough to extend with AI coding tools.

### Current scope

The application supports email/password authentication, automatic profile creation, role-based navigation, CSV test import, draft/published test states, timed exams, question navigation, database-side grading, attempt history, basic dashboards, student directory, and GitHub Pages deployment.

The current version is appropriate for demonstration, pilot testing, and controlled low-stakes use. Before high-stakes or organization-wide use, add audit logging, backup/recovery procedures, password recovery UI, accessibility testing, privacy controls, stronger test-attempt rules, monitoring, and formal security review.

---

## 2. Technology architecture

```text
Browser
  React 18 + Vite
  CSS responsive UI
  Supabase JavaScript client
  Papa Parse CSV processing
  Recharts analytics
        |
        | HTTPS using publishable/anon key
        v
Supabase
  Authentication
  PostgreSQL database
  Generated Data API
  Row Level Security policies
  submit_test(...) grading RPC
        |
        v
GitHub Pages
  Hosts only the compiled static frontend
  GitHub Actions builds the Vite dist directory
```

### Main dependencies

- `react` and `react-dom`: UI and component state.
- `@supabase/supabase-js`: authentication, database queries, and RPC calls.
- `papaparse`: browser-side CSV parsing and downloadable template generation.
- `recharts`: dashboard charts.
- `lucide-react`: interface icons.
- `vite`: local development and production build tooling.

No Node server runs in production. Node.js is required only to install packages and build or serve the frontend during development.

---

## 3. User roles and workflows

### Student

1. Registers with name, email, and password.
2. A database trigger creates a `profiles` row with role `student`.
3. Views published tests permitted by RLS.
4. Starts a test and receives questions without answer keys.
5. Selects answers while the browser displays a countdown.
6. Submits question IDs and selected options to the `submit_test` RPC.
7. PostgreSQL grades and stores the attempt atomically.
8. Views the returned result and later sees attempt history and progress.

### Administrator

1. Registers normally and is promoted to `admin` through a controlled SQL update.
2. Views school-level metrics and the student directory.
3. Downloads a CSV template or uploads a prepared CSV.
4. The frontend creates a draft test, its questions, and protected answer keys.
5. Publishes the test to make it visible to students.
6. Reviews attempts and analytics.

Do not allow users to select `admin` during public registration. Administrator promotion must remain a trusted administrative action or later be replaced by an invitation workflow.

---

## 4. Repository structure

```text
examflow-supabase/
├── .github/
│   └── workflows/
│       └── deploy.yml          # GitHub Pages build/deployment workflow
├── src/
│   ├── components/
│   │   ├── Admin.jsx           # Admin dashboard, tests, CSV import, students
│   │   ├── Auth.jsx            # Sign-in and registration interface
│   │   ├── Charts.jsx          # Shared Recharts chart components
│   │   ├── Layout.jsx          # Sidebar, header, navigation, sign-out
│   │   └── Student.jsx         # Student dashboard, tests, exam, result, analytics
│   ├── lib/
│   │   ├── csv.js              # CSV schema, parser, template download
│   │   └── supabase.js         # Supabase client initialization
│   ├── App.jsx                 # Session/profile loading and page routing
│   ├── main.jsx                # React entry point
│   └── styles.css              # Global responsive design system
├── supabase/
│   └── schema.sql              # Tables, types, triggers, RPC, indexes, RLS
├── .env.example                # Required environment-variable names
├── .gitignore                  # Excludes credentials and generated folders
├── index.html                  # Vite HTML entry
├── package.json                # Dependencies and npm scripts
├── package-lock.json           # Reproducible npm dependency lock
├── sample-test.csv             # Example import file
├── README.md                   # Setup guide
└── vite.config.js              # Vite plugins and GitHub Pages base path
```

### Important file responsibilities

#### `src/App.jsx`

The application coordinator. It initializes the Supabase session listener, loads the signed-in user's profile, decides whether to show authentication or the application, and selects role-specific pages. It also holds the active test and latest result state. Navigation is state-based rather than URL-router-based.

#### `src/components/Auth.jsx`

Provides email/password registration and sign-in. Registration sends `full_name` as user metadata. The database trigger then copies that name into `profiles`. Confirmation behavior depends on Supabase Auth configuration.

#### `src/components/Layout.jsx`

Provides the shared shell, responsive sidebar, role-aware navigation items, profile summary, and sign-out. Administrator navigation includes Students; student navigation does not.

#### `src/components/Admin.jsx`

Contains:

- `AdminDashboard`: counts students/tests and summarizes submitted attempts.
- `AdminTests`: lists tests, imports CSV, publishes drafts, and deletes tests.
- `Students`: lists registered student profiles.

The current CSV import performs sequential inserts from the browser. This is understandable but not transactional. A future improvement should move complete test import into one PostgreSQL RPC so partial tests are rolled back if any row fails.

#### `src/components/Student.jsx`

Contains:

- `StudentDashboard`: completion, average, pass, excellence, and trend metrics.
- `StudentTests`: published test listing.
- `Exam`: loads questions, manages answers, countdown, navigation, and submission.
- `Result`: displays the result returned by the grading RPC.
- `Analytics`: displays attempt history.

The countdown currently runs in the browser. The database validates availability dates but does not yet enforce elapsed duration per attempt. For high-stakes use, add an attempt-start record and server-side expiry validation.

#### `src/lib/csv.js`

Defines the required CSV headers, creates a downloadable sample template, and parses uploaded files with Papa Parse. The expected columns are:

```text
test_title, subject, class_name, duration_minutes,
starts_at, ends_at, question,
option_a, option_b, option_c, option_d,
correct_option, marks, explanation
```

The importer currently assumes one test per CSV and takes test metadata from the first row. It validates header presence but should later validate consistent metadata, allowed answer values, date formats, duplicate display order, empty options, and maximum file size before writing.

#### `src/lib/supabase.js`

Reads `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`, detects missing configuration, and creates the browser client. Never place a Supabase `service_role` key in this file or any `VITE_` variable because Vite embeds such values into the public browser bundle.

#### `src/styles.css`

Defines the entire current visual system: cards, buttons, badges, forms, tables, sidebar, exam layout, charts, result screen, and mobile breakpoints. The principal brand color is blue, and the UI is optimized for app-like cards on desktop and mobile.

---

## 5. Supabase configuration

### Required environment variables

Create `.env.local` in the repository root:

```env
VITE_SUPABASE_URL=https://YOUR_PROJECT.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=YOUR_PUBLISHABLE_OR_ANON_KEY
```

For GitHub Pages, create repository Actions secrets with the same names. Never commit `.env.local`.

### Initial database setup

Run the complete `supabase/schema.sql` once in the Supabase SQL Editor. The script creates custom enum types, tables, indexes, trigger/function logic, RLS policies, and grants.

### First administrator promotion

```sql
update public.profiles
set role = 'admin'
where id = (
  select id from auth.users where email = 'teacher@example.com'
);
```

After changing the role, sign out and sign in again so the frontend reloads the profile.

### Authentication URL configuration

For production, set the Supabase Auth Site URL to the deployed GitHub Pages URL and add the same address to allowed Redirect URLs. Keep the localhost URL for development. This is required for confirmation and future password-reset links.

---

## 6. Database model

### Enum types

```text
user_role: student | admin
test_status: draft | published | archived
attempt_status: in_progress | submitted
```

### `profiles`

Application-level extension of `auth.users`.

- `id uuid`: primary key and foreign key to `auth.users.id`; cascades on user deletion.
- `full_name text`: display name copied from signup metadata.
- `role user_role`: defaults to `student`.
- `created_at timestamptz`: creation time.

A trigger named `on_auth_user_created` calls `handle_new_user()` after an Auth user is created.

### `tests`

One assessment definition.

- `id uuid`: primary key.
- `title`, `subject`, `class_name`: test metadata.
- `duration_minutes int`: constrained from 1 to 300.
- `status test_status`: defaults to `draft`.
- `starts_at`, `ends_at`: optional availability window.
- `created_by uuid`: administrator profile; defaults to `auth.uid()`.
- `created_at timestamptz`.

### `questions`

Question text, options, marks, and ordering.

- `test_id`: cascades when a test is deleted.
- `body`: question statement.
- `option_a` through `option_d`: four required options.
- `marks`: positive numeric value.
- `display_order`: unique per test.

Correct answers are deliberately not stored here.

### `answer_keys`

Protected grading information.

- `question_id`: primary key and foreign key to `questions`.
- `correct_option`: constrained to A, B, C, or D.
- `explanation`: optional review text.

Students receive no select policy on this table. Administrators can manage it.

### `attempts`

One submitted test attempt.

- `test_id`, `student_id`: test and student references.
- `status`: currently inserted as `submitted` by the grading function.
- `score`, `total_marks`, `percentage`.
- `correct_count`, `total_questions`.
- `submitted_at`.

The schema defines `in_progress`, but the current UI does not create an attempt when a test starts. This is an intended extension point for resume, attempt limits, and robust server-side timing.

### `attempt_answers`

Question-level records for an attempt.

- `attempt_id`, `question_id`.
- `selected_option`: nullable for unanswered questions.
- `is_correct`.
- `marks_awarded`.
- Unique constraint on `(attempt_id, question_id)`.

### Relationships

```text
auth.users 1 ── 1 profiles
profiles   1 ── * tests               (created_by)
profiles   1 ── * attempts            (student_id)
tests      1 ── * questions
questions  1 ── 1 answer_keys
tests      1 ── * attempts
attempts   1 ── * attempt_answers
questions  1 ── * attempt_answers
```

---

## 7. Security and grading

### Row Level Security summary

- Profiles: users read their own profile; administrators read all; users cannot change their own role.
- Tests: authenticated users read published tests; administrators also read drafts and can insert/update/delete.
- Questions: authenticated users read questions for published tests; administrators manage all.
- Answer keys: administrators only.
- Attempts: students read their own; administrators read all.
- Attempt answers: students read records belonging to their own attempts; administrators read all.

The helper function `is_admin()` checks the current profile using `auth.uid()`.

### `submit_test(p_test_id, p_answers)` RPC

This security-definer PostgreSQL function is the trust boundary for grading:

1. Rejects unauthenticated callers.
2. Confirms the test is published and inside its availability window.
3. Calculates total marks and question count from the database.
4. Creates the attempt for the authenticated student.
5. Iterates through questions and protected answer keys.
6. Finds the student's selected option in the submitted JSON array.
7. Calculates correctness and marks.
8. Writes each `attempt_answers` row.
9. Updates the attempt totals and percentage.
10. Returns a compact result object.

Expected submission payload:

```json
[
  {
    "question_id": "UUID",
    "selected_option": "B"
  }
]
```

Do not move grading into React. Do not grant students direct read access to `answer_keys`. Any replacement grading logic should remain server-side and transactional.

---

## 8. Frontend state and data flow

The project currently uses React local state rather than Redux, Zustand, or React Router.

```text
App
├── session
├── profile
├── page
├── active test
└── latest result
```

`App.jsx` listens to Supabase Auth changes. When a session exists, it loads `profiles` and chooses administrator or student components. Page navigation is held in `page`; refreshing the browser returns to the default dashboard rather than preserving a nested route.

Supabase calls are made directly inside components, generally in `useEffect` or event handlers. For future scale, introduce:

- React Router for durable URLs.
- A `services/` or `repositories/` layer for Supabase queries.
- TanStack Query for caching, retries, loading, and invalidation.
- Shared error/loading/empty-state components.
- Form validation with Zod or a similar schema library.

---

## 9. Deployment

### Local commands

```bash
npm install
npm run dev
npm run build
npm run preview
```

### GitHub Pages

The workflow in `.github/workflows/deploy.yml` runs on pushes to `main` or manual dispatch. It checks out the repository, installs Node 20, runs `npm ci`, builds with Supabase secrets, uploads `dist`, and deploys it through GitHub Pages.

The repository's GitHub Pages source must be **GitHub Actions**. The `vite.config.js` production base path must match the repository name:

```js
base: process.env.GITHUB_ACTIONS ? '/examflow-supabase/' : '/'
```

If the repository is renamed, update this path. Otherwise JavaScript and CSS assets may return 404 errors.

### Deployment secrets

```text
VITE_SUPABASE_URL
VITE_SUPABASE_PUBLISHABLE_KEY
```

The production deployment contains the publishable key by design. Security depends on RLS, not secrecy of the browser key.

---

## 10. Known limitations and recommended roadmap

### Highest-priority improvements

1. **Attempt lifecycle:** create `in_progress` attempts at test start; store `started_at`; enforce duration and attempt limits server-side.
2. **Transactional CSV import:** replace browser sequential inserts with one validated PostgreSQL RPC.
3. **Result review policy:** control whether explanations/correct answers are released immediately, later, or never.
4. **Password recovery and account management:** add forgot-password, reset-password, change-password, and account deactivation flows.
5. **Question management:** add manual editor, reusable question bank, chapter/topic, difficulty, tags, image support, and bulk validation.
6. **Test rules:** randomize questions/options, negative marking, sections, pass marks, attempt limits, late submission, and autosave.
7. **Analytics:** topic mastery, class comparison, question difficulty/discrimination, completion funnels, downloadable reports, and date filters.
8. **Administration:** class/section entities, teacher invitations, student bulk import, test assignment, audit log, and soft deletion.
9. **Quality:** TypeScript, ESLint, unit/integration tests, Playwright end-to-end tests, error boundary, and centralized logging.
10. **Compliance:** accessibility, consent/privacy notice, retention/deletion controls, backups, data residency review, and organizational approval.

### Current behavioral cautions

- One CSV file should contain one test.
- The client timer is not authoritative.
- Multiple submissions are currently possible unless separately restricted.
- The admin import can partially complete if a later database insert fails.
- There is no URL router, so deep linking is unavailable.
- The application has basic analytics rather than advanced psychometric analysis.
- GitHub Pages is static hosting; all trusted logic must remain in Supabase.
- Supabase free-tier operational limits and inactivity behavior should be reviewed before formal production use.

---

## 11. AI/Cursor modification guardrails

When asking an AI assistant to improve the project, provide this document and require the following:

1. Preserve Supabase RLS and never expose `service_role` credentials.
2. Keep answer keys inaccessible to students.
3. Keep grading server-side through an RPC or another trusted backend.
4. Provide SQL migrations for every database change rather than editing production manually.
5. Update RLS policies whenever adding a table or data-access path.
6. Preserve administrator and student role separation.
7. Keep GitHub Pages base-path compatibility.
8. Maintain responsive behavior at desktop, tablet, and mobile widths.
9. Add explicit loading, error, empty, and success states.
10. Test build output with `npm run build` before committing.
11. Avoid destructive schema changes without migration and rollback guidance.
12. Update this document when architecture, schema, environment variables, or deployment changes.

### Recommended prompt for the next AI

```text
Analyze ExamFlow using TECHNICAL_HANDOVER.md and the current source code.
Before coding, identify affected components, database tables, RPC functions,
RLS policies, deployment configuration, and security risks. Preserve the rule
that students must never read answer_keys and grading must remain server-side.
Provide a migration-first plan, implement the smallest coherent change, update
documentation, and verify npm run build. Do not use a Supabase service_role key
in frontend code.
```

---

## 12. Definition of done for future changes

A change is complete only when:

- The UI works for the correct role and remains responsive.
- Unauthorized access is rejected by the database, not only hidden in the UI.
- New tables have RLS enabled and tested policies.
- Database changes are reproducible through SQL migration files.
- Loading, failure, no-data, and success cases are handled.
- Existing authentication, CSV import, test taking, grading, and deployment still work.
- `npm run build` succeeds.
- Relevant documentation and sample data are updated.

This document describes the current implementation as the baseline. Future development should evolve the project incrementally without weakening database-side authorization or exposing protected grading data.
