# App downloads

Place the built Android app here so the website's "Download for Android" button works:

    apps/web/public/downloads/One-Vizcaya.apk

Build it with (real-number sign-in works on sideloaded installs):

    cd apps/mobile
    flutter build apk --release --dart-define=FORCE_RECAPTCHA=true
    cp build/app/outputs/flutter-apk/*.apk ../web/public/downloads/One-Vizcaya.apk

The .apk itself is gitignored (too large / rebuilt often) — only this README is tracked.
