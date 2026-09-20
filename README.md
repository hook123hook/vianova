# ViaNova

International marriage, family reunification & visa consultancy website.
Static HTML/CSS/JS + Vercel Serverless Functions + Supabase.

## Structure

```
├── index.html              # EN homepage
├── tr/                     # TR pages
├── countries/              # EN country pages
├── assets/                 # styles.css, app.js, logos, flags
├── api/cases.js            # Vercel Function - inserts into Supabase
├── api/config.js           # Returns Supabase config to admin panel
├── api/xmr/                # Monero payment API endpoints
├── admin/                  # Admin panel (auth + realtime notifications)
├── supabase/
│   ├── schema.sql          # case_assessments + RLS + realtime
│   ├── schema-xmr.sql      # Monero tables + pop_xmr_address()
│   └── schema-complete.sql # ALL-IN-ONE (run this single file)
├── vercel.json             # cleanUrls, cache, security headers
└── .env.example            # environment variables template
```

---

## Setup

### 1. Create Supabase Project

Project is already created: `zkbxacyhiucomtfevbfi`
- Dashboard: https://supabase.com/dashboard/project/zkbxacyhiucomtfevbfi

### 2. Create Database Tables

1. Supabase Dashboard > **SQL Editor**
2. Click **New query**
3. Open `supabase/schema-complete.sql` and copy its entire content
4. Paste into the SQL Editor and click **Run**

This creates:
- `case_assessments` - consultation form submissions
- `xmr_address_pool` - Monero address pool (auto-seeded by bridge)
- `xmr_invoices` - payment invoices
- `xmr_payments` - payment audit ledger (immutable)
- `pop_xmr_address()` - atomic address allocation function
- RLS policies (anonymous = zero access, admin = full access)
- Realtime notifications (live updates in admin panel)
- `updated_at` trigger (automatic timestamp updates)

### 3. Create Admin User

1. Supabase Dashboard > **Authentication** > **Users**
2. Click **Add user**
   - Email: `admin@vianova.com` (your preferred email)
   - Password: choose a strong password
   - Check **Auto Confirm**
3. Click **Create User**

This user will log into the admin panel. RLS ensures only `authenticated` users can read/modify data.

### 4. Get API Keys

1. Supabase Dashboard > **Project Settings** > **API**
2. Copy these values:

| Key | Used In |
|-----|---------|
| **Project URL** (`https://zkbxacyhiucomtfevbfi.supabase.co`) | Vercel env: `SUPABASE_URL` |
| **anon public** key (eyJ...) | Vercel env: `SUPABASE_ANON_KEY` |
| **service_role** key (eyJ...) | Vercel env: `SUPABASE_SERVICE_ROLE_KEY` |

Important: `service_role` key is used ONLY server-side (api/cases.js, api/xmr/).
Never sent to the client. Admin panel uses `anon key`; data is protected by RLS.

### 5. Deploy to Vercel

1. https://vercel.com/dashboard > **Add New** > **Project**
2. Import from GitHub: `hook123hook/vianova`
3. Framework Preset: **Other** (static, no build needed)
4. Add Environment Variables:

```
SUPABASE_URL = https://zkbxacyhiucomtfevbfi.supabase.co
SUPABASE_ANON_KEY = eyJ...
SUPABASE_SERVICE_ROLE_KEY = eyJ...
```

5. Click **Deploy**

### 6. Link Custom Domain (optional)

Vercel > Settings > Domains > Add `vianova.com`

---

## Admin Panel

After deployment, go to `https://your-site.vercel.app/admin/`

Features:
- Login with Supabase Auth credentials
- Real-time case notifications (toast + browser notification)
- Status management: New / Read / Contacted / Archived
- Search and filter cases
- Case detail drawer with full info
- Delete cases
- XMR payment monitoring with CSV export
- Auto-refresh every 30 seconds

## Form Flow

When a consultation form is submitted:
1. Text summary is generated for SimpleX (existing flow preserved)
2. Same data is saved to `case_assessments` table via `/api/cases`
3. If Supabase is not configured, form still works (silent fallback)

## Local Development

```bash
npx vercel dev
# or static preview:
npx serve .
```
