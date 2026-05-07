# Project Handoff

Last updated: 2026-05-07

## Current State

Wherehouse is a Flutter MVP for household item location. The repo intentionally does not commit Android/iOS platform shells; Codemagic generates Android during release builds.

Recent implemented features:

- Barcode scanning via `mobile_scanner`.
- Persistent `barcode` field on `Thing`/`ThingDraft`, searchable through DAO.
- Codemagic Android workflow injects INTERNET and CAMERA permissions.
- Container/batch intake using existing `thing_type = 'location'` and `contained_in`.
- Browse screen has "按位置入库" entry points for existing or new locations.
- Add screen supports batch mode with preset container id/name and "保存并继续".
- Location detail pages show contained items and provide "添加物品".
- `scripts/watch_codemagic.py` polls Codemagic sparsely using `.env` token values.

## Verification

The latest Codemagic Android release build succeeded for commit `5c89442 feat: add container batch intake`.

Build id:

```text
69fb3602bdb05ae19e004bf5
```

Result:

```text
Build APK: success
Publishing: success
finishedAt: 2026-05-06T12:44:13.959000+00:00
```

This local environment still lacks `flutter` and `dart`, so SDK-level validation is done through Codemagic.

## Operational Notes

`.env` is ignored by Git and currently stores local-only automation credentials such as `GITHUB_TOKEN` and `CODEMAGIC_API_TOKEN`. Do not print or commit these values.

To push with the local GitHub token without persisting credentials:

```bash
token=$(awk -F= '/^GITHUB_TOKEN=/{print substr($0, index($0,"=")+1)}' .env | tr -d '\r')
auth=$(printf 'x-access-token:%s' "$token" | base64 -w0)
git -c http.https://github.com/.extraheader="AUTHORIZATION: basic $auth" push origin main
```

To trigger Codemagic manually:

```bash
token=$(awk -F= '/^CODEMAGIC_API_TOKEN=/{print substr($0, index($0,"=")+1)}' .env | tr -d '\r')
curl -sS -H "x-auth-token: $token" -H 'Content-Type: application/json' \
  --data '{"appId":"69c7e5deb7c3e100bcd723c3","workflowId":"android-release","branch":"main"}' \
  https://api.codemagic.io/builds
```

Watch a build:

```bash
python3 scripts/watch_codemagic.py <build_id> --interval 60
```

## Next Useful Work

- Add lifecycle actions: used up, moved, discarded/donated, borrowed.
- Add QR labels for containers as an optional enhancement.
- Add pending-confirmation queue for AI/scan/batch results.
- Add CSV/JSON export and restore before any paid/BYOK positioning.
- Reduce repeated output in `watch_codemagic.py` keyword matching if it becomes noisy.
