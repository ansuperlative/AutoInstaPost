# SETUP.md — AutoInstaPost

Step-by-step setup for `AutoInstaPost_v2_production.json`. 100% free stack, no paid APIs.

---

## Step 0 — Import
1. Open n8n → **Workflows → Import from File** → select `AutoInstaPost_v2_production.json`.
2. 40 nodes across 10 labeled sections will appear. Don't run yet.

---

## Step 1 — Groq API key
1. https://console.groq.com/keys → free sign up → **Create API Key**.
2. n8n → **Settings → Environments** (or `.env` if self-hosted):
   ```
   GROQ_API_KEY=gsk_your_key_here
   ```

---

## Step 2 — Pollinations AI (image generation)
Nothing to set up — no signup, no key. It's a URL-based service, already wired into the **Pollinations - Build Image URL (FREE)** node. Just confirm your n8n host can reach `image.pollinations.ai` (no firewall block).

---

## Step 3 — Cloudinary (image hosting)
1. https://cloudinary.com → free account → copy your **Cloud Name** from the dashboard.
2. **Settings → Upload → Add upload preset** → Signing Mode = **Unsigned**.
3. ⚠️ In that same preset's settings, enable **"Remote fetch URLs"** — required because the workflow uploads by remote Pollinations URL, not by file/base64.
4. Env vars:
   ```
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_UPLOAD_PRESET=your_preset_name
   ```

---

## Step 4 — Google Sheets (duplicate check + logging)
1. Create a new Google Sheet. **Name the tab exactly `posts`** (lowercase — this must match `GOOGLE_SHEET_TAB` below, Google Sheets node matching is case-sensitive).
2. Header row, exactly these 8 columns in order:
   ```
   Date | Topic | Prompt | Caption | Image URL | Instagram URL | Status | Error
   ```
3. Copy the Sheet ID from its URL: `docs.google.com/spreadsheets/d/`**`THIS_PART`**`/edit`
4. n8n → **Credentials → New → Google Sheets OAuth2** → authorize with your Google account.
5. Open the 3 Google Sheets nodes in the workflow (**Get Existing Topics**, **Log Success Row**, **Log Failure Row**) and select that credential on each.
6. Env vars:
   ```
   GOOGLE_SHEET_ID=your_sheet_id
   GOOGLE_SHEET_TAB=posts
   ```
7. **Note:** the **Get Existing Topics** node has `alwaysOutputData` enabled, so an empty/fresh sheet (no rows yet) won't stall the workflow on its first run — it'll just treat the used-topics list as empty.

---

## Step 5 — Instagram / Meta Graph API
1. https://developers.facebook.com → create a **Business** app.
2. Add the **Instagram Graph API** product.
3. Your Instagram account must be **Business or Creator**, linked to a **Facebook Page**.
4. Graph API Explorer → generate a token with these scopes:
   - `instagram_basic`
   - `instagram_content_publish`
   - `pages_show_list`
   - `pages_read_engagement`
5. Exchange for a long-lived token (valid ~60 days):
   ```
   GET https://graph.facebook.com/v19.0/oauth/access_token?grant_type=fb_exchange_token&client_id=APP_ID&client_secret=APP_SECRET&fb_exchange_token=SHORT_TOKEN
   ```
6. Get your Instagram Business Account ID:
   ```
   GET https://graph.facebook.com/v19.0/me/accounts?access_token=YOUR_TOKEN
   GET https://graph.facebook.com/v19.0/{page-id}?fields=instagram_business_account&access_token=YOUR_TOKEN
   ```
7. Env vars:
   ```
   IG_ACCESS_TOKEN=your_long_lived_token
   IG_BUSINESS_ACCOUNT_ID=your_ig_business_account_id
   ```
8. If your Meta app is in **Development mode**, add your own Instagram account under **App Dashboard → Roles → Instagram Testers** and accept the invite, or publishing will fail with an OAuth/permission error even with a valid token.

⚠️ Token expires in ~60 days — set a reminder to refresh it.

---

## Step 6 — Telegram notifications
1. Telegram → **@BotFather** → `/newbot` → get your token.
2. n8n → **Credentials → New → Telegram API** → paste the token.
3. Select that credential on both Telegram nodes in the workflow.
4. Get your chat ID: message your bot once, then open:
   ```
   https://api.telegram.org/bot<YOUR_TOKEN>/getUpdates
   ```
   → look for `"chat":{"id": ...}`.
5. Env var:
   ```
   TELEGRAM_CHAT_ID=your_chat_id
   ```

---

## Step 7 — Full environment variable checklist

```
GROQ_API_KEY=
CLOUDINARY_CLOUD_NAME=
CLOUDINARY_UPLOAD_PRESET=
GOOGLE_SHEET_ID=
GOOGLE_SHEET_TAB=posts
IG_ACCESS_TOKEN=
IG_BUSINESS_ACCOUNT_ID=
TELEGRAM_CHAT_ID=
IG_ACCOUNT_LABEL=nature_page_01
```

Plus 2 n8n-side credentials (set on nodes directly, not env vars): **Google Sheets OAuth2**, **Telegram API**.

---

## Step 8 — Test run
1. Run via **Manual Trigger (Test)**.
2. Every node should go green.
3. On success: a new Sheets row appears, a ✅ Telegram message arrives, and the post goes live on Instagram.
4. On any red node: click it, read the error (the same error is also logged to Sheets and sent via Telegram).

---

## Step 9 — Activate
Toggle the workflow **Active** (top-right) — it now runs daily at 10 AM with zero manual intervention.

---

## Troubleshooting

| Symptom | Cause | Fix |
|---|---|---|
| Workflow stalls right after the Sheets read node, no error shown | Sheet was empty (only header row) | Already fixed via `alwaysOutputData` — update to latest JSON if you hit this |
| `Error in loading <pollinations-url> ... 500` | Pollinations transient overload, or `seed` value too large | Retry (already 3x); ensure `seed` uses `Date.now() % 2147483647`, not raw `Date.now()` |
| Cloudinary "remote fetch not allowed" | Upload preset doesn't have Remote fetch URLs enabled | See Step 3.3 |
| `(#10) Requires instagram_content_publish permission` | Token missing that scope, or app in Development mode without your account added as a tester | See Step 5.4 and 5.8 |
| Groq 401 | Wrong/missing `GROQ_API_KEY`, or missing `Bearer ` prefix | Check header value format |
| `Could not get parameter` on a Sheets node | Either the credential lacks Sheets/Drive API access, or the node depends on an upstream node that didn't run in this execution | Reconnect credential; always test the full chain via Manual Trigger, not a single node in isolation |
| Telegram message never arrives | Wrong chat ID, or bot never messaged first | Re-fetch chat ID via `getUpdates` |
