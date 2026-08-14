# One Vizcaya — Tomorrow's Debug & Test-Run Playbook

> Follow this top-to-bottom to (A) push the merged code live, (B) fix real-number
> phone login via Google Play so a municipality can test with their own numbers,
> and (C) start clean debugging. Everything here is self-contained.

**Where the code is:** all features are merged to `main` (PRs #90 + #91).
**Companion:** deeper build/deploy notes live in `docs/Computer-Shop-Runbook.md`.

---

## PART A — Deploy checklist (push the merged code live)

The code is on `main` but not yet running in production. Do these once:

- [ ] **Deploy the 3 new Cloud Functions** — notifications, the FB importer, and
      rainfall alerts don't work until this runs:
      ```bash
      firebase deploy --only functions
      ```
      Ships: `onNewAnnouncement`, `fetchLinkPreview`, `rainfallWatch`.
- [ ] **Set the weather API key** (for `rainfallWatch`):
      ```bash
      firebase functions:secrets:set OPENWEATHER_API_KEY
      # paste the same key used in apps/mobile/lib/secrets.dart, then redeploy:
      firebase deploy --only functions
      ```
- [ ] **Rebuild the APK/AAB** — all mobile changes (notifications, weather,
      dark mode, profile, credits). See Part B for the Play build.
- [ ] **Deploy web** — map time filter + announcements importer:
      ```bash
      npm run build:web && firebase deploy --only hosting
      ```
- [ ] **Rules / indexes / storage:** unchanged this round — **nothing to deploy.**

---

## PART B — Fix real-number phone login (Google Play Internal Testing)

**The error:** *"missing a valid app identifier — Play Integrity and reCAPTCHA
unsuccessful."* A sideloaded APK can't pass Play Integrity. Installing the app
**from Google Play** lets Google re-sign it so Play Integrity works — but Firebase
must know Google's signing fingerprint. **That registration (Phase 5) is the
actual fix.** Test numbers keep working throughout as a fallback.

### Phase 1 — Play Console account ($25, one-time)
1. **play.google.com/console** → sign in with the managing Google account.
2. Choose account type (Personal is fine) → pay **$25** → accept agreements →
   verify identity.

### Phase 2 — Create the app
1. **Create app** → name **One Vizcaya** · English · **App** · **Free** →
   accept declarations → **Create**.

### Phase 3 — Make an uploadable signed build
Play **rejects debug-signed** uploads, so create an upload key once (separate
from `debug.keystore`):
```bash
keytool -genkey -v -keystore upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```
Put it at `apps/mobile/android/app/upload-keystore.jks`, then create
`apps/mobile/android/key.properties`:
```
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=upload
storeFile=upload-keystore.jks
```
> **Back up the `.jks` + passwords.** Both files are gitignored — never commit them.

Build the App Bundle (Play wants `.aab`):
```bash
cd apps/mobile && flutter build appbundle --release
# → build/app/outputs/bundle/release/app-release.aab
```
> Each upload needs a **higher versionCode**. You're at `1.3.13+16`; the next
> upload must be `+17`, then `+18`… (edit `version:` in `apps/mobile/pubspec.yaml`).

### Phase 4 — Upload to Internal Testing
1. Play Console → **Testing → Internal testing → Create new release**.
2. When prompted, **accept Play App Signing** (let Google manage the signing key).
3. **Upload** `app-release.aab` → name the release → **Save → Review release →
   Start rollout to Internal testing**.

### Phase 5 — ⚠️ THE FIX: register Google's signing SHA in Firebase
Google re-signs the app, so Firebase needs **Google's** fingerprint.
1. Play Console → **Test and release → App integrity → Play app signing**.
2. Copy **both** the **App signing key** `SHA-1` **and** `SHA-256`
   (also copy the **Upload key** SHA-1 + SHA-256).
3. Firebase Console → **Project settings → Your apps → Android app
   (`com.onevizcaya.app`) → Add fingerprint** → paste **SHA-1 and SHA-256**
   (add the upload-key ones too).
4. Firebase → **App Check → Android app → Play Integrity** → confirm that
   **SHA-256** is listed there as well.
> No rebuild needed — SHA registration is server-side; effective in a few minutes.
> (SHA-256 powers Play Integrity; SHA-1 powers the reCAPTCHA fallback — you need both.)

### Phase 6 — Play Integrity + App Check
1. Google Cloud Console (same project) → confirm **Play Integrity API = Enabled**.
2. Firebase → **App Check → Authentication** → leave on **Monitor**.
   **Do NOT click Enforce** (it's at 0% verified — enforcing would block everyone).

### Phase 7 — Add testers & install from Play
1. Play Console → **Internal testing → Testers** → create an email list → add
   the **Google accounts** of every tester (their phone must be signed into that
   account).
2. **Copy link** (opt-in URL) → send to testers.
3. On each phone: open the link → **Become a tester** → **Install One Vizcaya
   from the Play Store** (not a sideloaded APK).

### Phase 8 — Verify + safety nets
1. On a tester phone (installed **from Play**, current Google Play Services),
   sign in with a **real number** → the SMS should send.
2. Firebase → **App Check → metrics**: the **verified** rate climbs off 0%.
3. **Safety net:** Firebase → **Authentication → Sign-in method → Phone →
   "Phone numbers for testing"** → add 2–3 numbers with fixed codes. These send
   no SMS and always work (great for repeat demos / weak Play Services devices).

### 💰 Cost note for municipality-wide testing
Real sign-ins send billed SMS (Blaze). PH SMS is ~a few cents each with a small
free daily allotment. During testing:
- Keep a **controlled tester list** (a few dozen), not the whole town at once.
- Use **test numbers** for repeat/demo logins (₱0, no SMS).
- Watch **Firebase → Usage** for the phone-auth quota.

---

## PART C — Start clean tomorrow

### Branch off the updated `main`
`claude/gov-review-changes` is merged (twice) and finished — don't reuse it.
Start new work fresh:
```bash
git fetch origin main
git checkout -B <your-new-branch> origin/main
```

### Suggested debug priorities (on a real device)
1. **Real-number phone login** via the Play Internal Testing build (Part B).
2. **Notifications inbox** — needs the functions deployed (Part A); post an
   announcement and confirm it pushes + lands in the bell inbox.
3. **Weather** — eyeball the redesigned detail screen (blue/black + moon phase)
   and the home card's 24-hr rain / heat index.
4. **Residency flow** — GPS auto-verify on registration; certified path via the
   web "Residency" approval queue.
5. **FB importer** — web Announcements → "Import from link" pulls title/text/image.

### Quick sanity checks
```bash
# mobile static analysis
cd apps/mobile && flutter analyze

# web builds
cd apps/web && npm run build

# functions syntax
cd apps/functions && node -c index.js
```

### Files to have on hand at a computer (gitignored secrets)
`firebase_options.dart`, `google-services.json`, `secrets.dart`, `debug.keystore`,
`key.properties`, `upload-keystore.jks` — see `docs/Computer-Shop-Runbook.md` §1
for exact paths.
