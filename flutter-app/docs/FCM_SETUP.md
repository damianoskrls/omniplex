# Push notifications (FCM)

Οι ειδοποιήσεις **αποθηκεύονται πάντα** στη βάση και εμφανίζονται στην εφαρμογή (polling + λίστα).

Για **push στο κινητό** (ακόμα και κλειστή εφαρμογή), χρειάζονται δύο μέρη:

## 1. API (`admin-api/.env`)

```env
FCM_SERVER_KEY=your-firebase-legacy-server-key
PUBLIC_API_URL=http://192.168.1.6:3001
```

- `FCM_SERVER_KEY`: Firebase Console → Project Settings → **Cloud Messaging** → **Server key** (Legacy).
  Αν δεν υπάρχει Legacy key, ενεργοποίησε Cloud Messaging API ή χρησιμοποίησε νεότερο FCM HTTP v1 (μελλοντική αναβάθμιση).
- `PUBLIC_API_URL`: δημόσιο URL του API (για εικόνες σε push). Όχι `localhost` για πραγματικά κινητά.

Μετά την αλλαγή: `cd admin-api && npm start`

Έλεγχος από gym-admin: στις ρυθμίσεις ειδοποιήσεων θα δείχνει `fcm_configured: true`.

## 2. Flutter app (Firebase)

### Γρήγορη ρύθμιση (FlutterFire CLI)

```bash
# Εγκατάσταση CLI (μία φορά)
dart pub global activate flutterfire_cli

# Στο root του flutter-app, με logged-in Firebase account
cd flutter-app
flutterfire configure
```

Αυτό ενημερώνει:
- `lib/firebase_options.dart`
- `android/app/google-services.json`
- `ios/Runner/GoogleService-Info.plist`

### Android

Μετά το `flutterfire configure`, πρόσθεσε στο `android/settings.gradle.kts` plugins block:

```kotlin
id("com.google.gms.google-services") version "4.4.2" apply false
```

Και στο `android/app/build.gradle.kts`:

```kotlin
plugins {
    id("com.android.application")
    id("com.google.gms.google-services")
    id("dev.flutter.flutter-gradle-plugin")
}
```

### iOS

**Ελάχιστη έκδοση: iOS 15.0** (απαιτείται από Firebase). Το project είναι ήδη ρυθμισμένο· αν ξαναδείς σφάλμα `supports 13.0`, τρέξε:

```bash
cd flutter-app
flutter pub get
cd ios && pod install
```

1. Άνοιξε **`ios/Runner.xcworkspace`** (όχι το `.xcodeproj`) στο Xcode.
2. Runner → Signing & Capabilities → **+ Capability** → **Push Notifications**.
3. `pod install` στο `ios/` αν χρειάζεται.

Αν δεις `Module 'flutter_local_notifications' not found`:

```bash
flutter config --no-enable-swift-package-manager
flutter clean && flutter pub get
cd ios && rm -rf Pods Podfile.lock && pod install
```

### Δοκιμή

1. Σύνδεση πελάτη στην εφαρμογή (καταχωρείται FCM token στο API).
2. Από gym-admin: **Ειδοποιήσεις → Ανακοίνωση σε όλους**.
3. Κλείσε την εφαρμογή — θα πρέπει να έρθει system push.

Χωρίς Firebase στην εφαρμογή, οι ειδοποιήσεις λειτουργούν **μόνο όσο η εφαρμογή είναι ανοιχτή** (polling κάθε 45 δευτ.).
