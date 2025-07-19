# DisConX Android Launcher Icon Setup

## Overview
This guide will set up the DisConX app launcher icon for Android devices using the `logo_png.png` file. The logo will appear when the app is installed on Android devices.

## Prerequisites
- Flutter SDK installed
- Android Studio for testing
- Android device or emulator
- The `flutter_launcher_icons` package is already added to `pubspec.yaml`

## Setup Steps

### 1. Install Dependencies
```bash
cd /path/to/mobile
flutter pub get
```

### 2. Generate Android Launcher Icons
```bash
flutter pub run flutter_launcher_icons
```

### 3. Configuration Details
The `pubspec.yaml` is configured for **Android only** with:
- **Standard Icon**: DisConX logo for all Android versions
- **Adaptive Icon**: Modern Android adaptive icon with white background
- **Foreground**: DisConX logo as the main icon element
- **Background**: Clean white background for better logo visibility

### 4. Verify Android Icon Generation

#### Check Generated Files
```bash
# Standard launcher icons (all Android versions)
ls android/app/src/main/res/mipmap-mdpi/ic_launcher.png
ls android/app/src/main/res/mipmap-hdpi/ic_launcher.png
ls android/app/src/main/res/mipmap-xhdpi/ic_launcher.png
ls android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png
ls android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png

# Adaptive icons (Android 8.0+)
ls android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml
ls android/app/src/main/res/drawable/ic_launcher_background.xml
ls android/app/src/main/res/mipmap-*/ic_launcher_foreground.png
```

### 5. Test on Android Device
```bash
# Install on connected Android device
flutter install

# Or run in debug mode
flutter run -d android
```

## What You'll See

### On Device Home Screen
- **App Icon**: DisConX logo will appear as the app icon
- **App Name**: "DisConX" will appear below the icon
- **Modern Look**: On Android 8.0+, the icon will use adaptive design

### Icon Behavior
- **Tap to Launch**: Tapping the icon launches the DisConX app
- **Long Press**: Shows app info and shortcuts (standard Android behavior)
- **App Drawer**: Icon appears in the app drawer with other installed apps

## Icon Specifications

### Source Image
- **File**: `assets/logo_png.png`
- **Recommended Size**: 512x512 pixels minimum (1024x1024 preferred)
- **Format**: PNG with transparency support
- **Design**: Should work well on both light and dark backgrounds

### Generated Sizes
- **mdpi**: 48x48px (baseline)
- **hdpi**: 72x72px (1.5x)
- **xhdpi**: 96x96px (2x)
- **xxhdpi**: 144x144px (3x)
- **xxxhdpi**: 192x192px (4x)

## Troubleshooting

### Common Issues
1. **Icon not updating on device**: 
   - Uninstall the app completely: `flutter install --uninstall-only`
   - Reinstall: `flutter install`
   - Or clear app data in Android settings

2. **Icons not generated**: 
   - Ensure `flutter pub get` was run successfully
   - Check that `assets/logo_png.png` exists and is readable
   - Run `flutter clean` then regenerate icons

3. **Logo appears distorted**:
   - Ensure source image is square (equal width and height)
   - Minimum 512x512px, recommended 1024x1024px
   - Use PNG format with transparent background if needed

### Validation Commands
```bash
# Check if Android icons were generated
ls android/app/src/main/res/mipmap-*/ic_launcher*

# Regenerate if needed
flutter clean
flutter pub get
flutter pub run flutter_launcher_icons
```

### Testing on Device
```bash
# Check connected Android devices
flutter devices

# Install fresh copy
flutter install --uninstall-only
flutter install

# Verify icon appears correctly on home screen
```

## Final Result
After running the setup commands, your DisConX logo will appear as the app icon when:
- Installing the app on any Android device
- Viewing the app in the device's app drawer
- Seeing the app on the home screen
- Switching between apps (recent apps view)

The icon will automatically adapt to different Android versions and themes while maintaining the DisConX brand identity.