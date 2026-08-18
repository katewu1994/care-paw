# copaw · Flutter

A Flutter rewrite of the shared pet-care handoff app. It keeps the original product flow—households, daily care tasks, recurring routines, assignment handoffs, calendar planning, pet care overviews, and profile management—with real-time Firebase sync on Android and iOS.

## What works

- Create a shared household with one or more named pets using the app's Firebase session
- Invite caregivers with a one-time 24-hour link/QR code, preview the destination household, and require owner approval before access
- Approve, decline, or remove caregivers from the household profile
- Seeded daily routines and a one-time care task
- Claim, assign, open, accept, decline, cancel, and complete task handoffs
- Add one-time tasks or weekday-based recurring routines
- Change or skip a single routine occurrence without affecting later days
- Browse a monthly calendar with routine, one-time, and urgent indicators
- See each pet's daily progress and manage its regular routines
- Edit household details with owner-only controls

## Firebase

The native apps are connected to the Firebase project `care-paw`:

- Android package: `com.copaw.care_paw`
- iOS bundle ID: `com.copaw.carePaw` (minimum iOS version: 15)
- Firebase Authentication: anonymous sessions on each app installation
- Cloud Firestore: `asia-northeast1` (Tokyo)
- Security rules: [`firestore.rules`](firestore.rules), deployed from this repo

All household data, pets, caregivers, routines, task updates, invitations, and join requests are stored in Firestore. Pets are embedded in each household document as a `pets` list of `{id, name, species}` maps; reads remain backward-compatible with legacy `petName` documents. Android and iOS restore the most recent household for the current Firebase session and subscribe to real-time updates. The in-memory store remains only as a fallback for tests and unsupported platforms; no Firebase Web app is registered.

## Secure invitations

Google account connection is temporarily removed. The app uses Firebase anonymous authentication, so an installation keeps its household access while that Firebase session remains on the device. Clearing app data or uninstalling the app can lose access to that anonymous session.

Deploy the rules and collection-group index after changing the authentication model:

   ```sh
   firebase deploy --only firestore:rules,firestore:indexes --project care-paw
   ```

The joining flow is intentionally two-stage:

- An owner creates a cryptographically random invitation that expires in 24 hours.
- A recipient opens the `copaw://invite/...` link or scans its QR code and sees only the household name, inviter, and pet names.
- Claiming the invitation creates a pending join request; it does not create a membership.
- The owner approves the caregiver request in the profile. Only that approval transaction creates the caregiver membership.
- Invitations cannot be enumerated, are single-use, and can be revoked. Owners can remove non-owner caregivers later.

## Notifications

Android and iOS now include an opt-in **Care notifications** switch in the household profile. It requests the native notification permission, registers the device's FCM token, presents notifications while the app is open, and removes the token again when switched off.

- Device tokens are stored under `households/{householdId}/members/{caregiverId}/devices`. The deployed Firestore rules allow only the device owner to read or change them; Cloud Functions use Admin SDK access.
- [`functions/index.js`](functions/index.js) sends FCM notifications for new tasks, assignments, claims, completions, and caregiver join requests. It also checks recurring routines every 10 minutes and sends a deduplicated reminder 10–25 minutes before the routine.
- Android declares the Android 13+ notification permission and uses the `copaw_care` notification channel.
- iOS includes the push-notification entitlement and background remote-notification mode. Push delivery still needs a real signed iPhone build; simulators cannot receive APNs pushes.

The client and backend source are ready, but the functions are intentionally **not deployed** until the Firebase project is on Blaze. Firestore rules have been deployed already.

### One-time owner handoff

The currently signed-in Firebase Console account is not an Owner of `care-paw`, so it cannot attach billing or deploy the Cloud Functions backend. A project Owner should:

1. In Firebase Console, open **Usage and billing** → **Modify plan**, choose **Blaze**, and attach a billing account.
2. In Google Cloud Billing, create a **$5/month budget alert** for the billing account. This is an alert threshold, not a hard spending cap.
3. In Apple Developer, enable Push Notifications for `com.copaw.carePaw`, create an APNs authentication key, then upload its key, key ID, and team ID in Firebase Console → Project settings → Cloud Messaging → iOS app.
4. Deploy the backend from this repository:

   ```sh
   cd functions
   npm ci
   cd ..
   firebase deploy --only functions --project care-paw
   ```

After that, test with two physical devices in the same household: enable the profile switch on both, create or assign a task on one device, and verify the other receives the notification.

## Run

```sh
flutter pub get
flutter run -d <android-or-ios-device>
```

To run the automated smoke test:

```sh
flutter test
```

## Project structure

```text
lib/
├── models/       # Household, caregiver, routine, and task types
├── screens/      # Onboarding, Today, Calendar, Pets, and Profile
├── services/     # Firebase Auth and Firestore persistence
├── state/        # Reactive task store and business state transitions
└── widgets/      # Shared visual components and task card
functions/        # Firestore-triggered and scheduled FCM notifications
```

Firebase client configuration is intentionally excluded from Git. Before running the native apps, provide `android/app/google-services.json`, `ios/Runner/GoogleService-Info.plist`, and generate `lib/firebase_options.dart` for the `care-paw` project. There is no Web Firebase configuration.
