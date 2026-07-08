# VTalano Flutter App — Setup Guide

## 1. Install Flutter SDK

Download from https://docs.flutter.dev/get-started/install/windows
- Extract to `C:\flutter`
- Add `C:\flutter\bin` to your system PATH
- Run `flutter doctor` to verify

## 2. Bootstrap the project

Open a terminal in this directory and run:

```bash
# Install dependencies
flutter pub get

# Check for any issues
flutter doctor

# Generate platform boilerplate (first time only)
flutter create --project-name vtalanoa_app --org com.vtalanoa . --platforms android,ios,web,windows
```

> Note: `flutter create .` will generate the android/, ios/, web/, and windows/ 
> boilerplate without overwriting your existing lib/ files. Merge the 
> AndroidManifest.xml additions from android/app/src/main/AndroidManifest.xml 
> into the generated one.

## 3. Android — minimum SDK version

In `android/app/build.gradle`, set:
```gradle
android {
    compileSdk 34
    defaultConfig {
        minSdk 21        // Required for flutter_webrtc
        targetSdk 34
    }
}
```

## 4. Run on Android

```bash
flutter run -d android
```

Or select a device in VS Code / Android Studio.

## 5. Run on other platforms

```bash
flutter run -d chrome      # Web
flutter run -d windows     # Windows desktop
```

## Project structure

```
lib/
├── main.dart                       # Entry point
├── app.dart                        # Router + providers
├── core/
│   ├── theme/app_theme.dart        # Dark theme (matches vtalanoa.com)
│   ├── constants/api_constants.dart # API base URL + endpoints
│   ├── models/                     # User, Meeting data classes
│   ├── services/                   # API, Auth, Meeting HTTP services
│   └── providers/auth_provider.dart
└── features/
    ├── auth/                       # Login + Register screens
    ├── dashboard/                  # Meeting list + schedule
    └── room/                       # WebRTC video call + chat
        ├── services/webrtc_service.dart   # Cloudflare SFU + Socket.IO
        ├── providers/room_provider.dart
        └── widgets/                       # VideoTile, ControlsBar, ChatPanel
```

## Changing the API server

Edit `lib/core/constants/api_constants.dart`:
```dart
static const String baseUrl        = 'https://vtalanoa.com';
static const String signalingUrl   = 'https://navuli-meet-signaling.onrender.com';
```

For local dev, change to your machine's IP:
```dart
static const String baseUrl        = 'http://192.168.x.x/meet.navulifiji.com/public';
static const String signalingUrl   = 'http://192.168.x.x:3001';
```
