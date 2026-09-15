# BookUp Customer App (iOS / Android)

White-label Flutter app for customer booking. Each tenant gets branded colors, app name, and bundle ID via `assets/tenant_config.json`.

## Run on iOS (simulator)

1. Install Flutter and Xcode.
2. Update `assets/tenant_config.json` with your tenant `business_id` and `api_base_url`.
3. Start the Admin API (`admin-api` on port 3001).
4. From this directory:

```bash
flutter pub get
open -a Simulator
flutter run -d ios
```

## White-label build

Use the build script from the repo root:

```bash
pip install requests Pillow
python build-scripts/build_tenant.py \
  --tenant-id YOUR_TENANT_SLUG \
  --platform ios \
  --api-base http://localhost:3001 \
  --api-secret YOUR_JWT_TOKEN
```

For release IPA builds, configure Apple signing in Xcode or via CI secrets (see `.github/workflows/build_tenant.yml`).

## Features

- Login / Register (`/api/mobile/*`)
- Browse services and book slots (`/api/booking/*`)
- View and cancel bookings
- Membership credits (when enabled)
- Tenant branding from config
