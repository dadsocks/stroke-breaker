# Putting Practice

Flutter app scaffolded specifically for iOS (minimum deployment target iOS 16) with Firebase Core, Firebase Authentication, and Google Sign-In dependencies wired up in code.

## Prerequisites

- Flutter 3.38.x (or newer stable).
- Xcode 15+ with CocoaPods (`gem install cocoapods`).
- A Firebase project with access to the Firebase Console.

## Run the app

```bash
cd putting_practice
flutter pub get
flutter run -d ios
```

The home screen displays a Google Sign-In button hooked up to `firebase_auth`. Once Firebase is configured the button signs users in/out and shows profile details.

## Configure Firebase for iOS

1. **Create a Firebase project** (https://console.firebase.google.com) or reuse an existing one.
2. **Add an iOS app** to the project.
   - Bundle ID: match `PRODUCT_BUNDLE_IDENTIFIER` in `ios/Runner.xcodeproj` (defaults to `com.example.puttingPractice` until you change it in Xcode).
   - App nickname: anything you prefer.
   - App Store ID: optional for now.
3. **Download `GoogleService-Info.plist`** from the registration wizard.
4. **Add the file to the Flutter project**:
   - Place the file at `ios/Runner/GoogleService-Info.plist`.
   - Open `ios/Runner.xcworkspace` in Xcode, drag the plist into the `Runner` target, and ensure “Copy items if needed” and the `Runner` target are checked.
5. **Install CocoaPods** dependencies:
   ```bash
   cd putting_practice/ios
   pod install
   ```
6. **Initialize Firebase in Dart**: already handled in `lib/main.dart` with `await Firebase.initializeApp();` so no further work is needed after the plist is present.

## Enable Google Sign-In

1. In the Firebase Console, go to **Authentication → Sign-in method** and enable **Google**. Configure a support email address.
2. Open `ios/Runner/Info.plist` in Xcode (or a text editor) and update the placeholders added for you:
   - Replace every `REVERSED_CLIENT_ID` value with the `REVERSED_CLIENT_ID` entry from `GoogleService-Info.plist`.
   - Replace `CLIENT_ID` with the `CLIENT_ID` value from the same plist (this allows GoogleSignIn to find the OAuth client at runtime).
3. Confirm that the file now contains:
   - A `CFBundleURLTypes` entry with the reversed client ID (required for the Google Sign-In callback).
   - `LSApplicationQueriesSchemes` entries for `google` and `com.googleusercontent.apps.<your reversed client id>` so the Google app redirect works on iOS.
4. Make sure `GoogleService-Info.plist` is part of the `Runner` target and checked into source control (never share it publicly if it contains secrets).

## Notes

- Minimum iOS version is enforced via `platform :ios, '16.0'` in `ios/Podfile` and the Xcode project settings.
- Dependencies already added to `pubspec.yaml`: `firebase_core`, `firebase_auth`, and `google_sign_in`.
- After any dependency or native configuration change, rerun `flutter pub get` followed by `cd ios && pod install`.
