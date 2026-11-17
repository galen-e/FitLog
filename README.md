# FitLog

A workout tracker and social fitness app. Log workouts, track body weight and strength, create a profile, follow other users, and share completed workouts with likes and comments. Accounts use Supabase Authentication; private workout data and shared social content are stored in Supabase so they sync across devices.

Includes a weekly split planner and calendar with rest-day recovery tips.

## Configure Supabase
1. Create a Supabase project.
2. In the Supabase SQL Editor, run the contents of `supabase-schema.sql`. This creates the tables, row-level security policies, profile creation trigger, and media bucket used by FitLog.
3. Open **Project Settings → API** and copy the Project URL and `anon`/publishable key into `supabase-config.js`.
4. In **Authentication → URL Configuration**, set **Site URL** to `https://galen-e.github.io/FitLog/` and add `https://galen-e.github.io/FitLog/**` to the redirect URL allow list. FitLog sends signup confirmation emails back to the app directory so GitHub Pages does not route them to the account's root 404 page.
5. Email confirmation may remain enabled. New accounts must confirm their email before their first login.

The anon/publishable key is intended for browser use. Never put a Supabase `service_role` key in this app. Row-level security is the access boundary.

Existing local-only accounts are not imported. FitLog removes the old `fitlog1` browser record and new accounts are created through Supabase Auth. The local-only data previously stored in that record cannot be recovered after it is cleared.

## Deploy to GitHub Pages
1. Configure Supabase as described above.
2. Push this folder to a GitHub repository, keeping `index.html`, `supabase-config.js`, and `supabase-schema.sql` at the repository root.
3. Go to **Settings → Pages**.
4. Under **Build and deployment**, choose **Deploy from a branch**, select `main` and `/ (root)`, then Save.
5. After deployment, open `https://<your-username>.github.io/<repo-name>/` and create an account.

## Install on your phone
- **iPhone:** open the URL in Safari → Share → Add to Home Screen.
- **Android:** open in Chrome → menu → Install app / Add to Home screen.

Use the same email and password on each device. Supabase Realtime updates the shared feed, likes, comments, follows, and profiles while the app is open. Private workout records load from your account when you sign in.
