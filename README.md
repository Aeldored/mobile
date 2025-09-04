# DisConX Mobile App

**DICT Secure Connect Mobile Application for CALABARZON**

A Flutter-based mobile application designed to protect citizens from evil twin Wi-Fi attacks and provide comprehensive cybersecurity awareness. Developed for the Department of Information and Communications Technology (DICT) - CALABARZON region.

## Overview

DisConX Mobile is a production-ready cybersecurity application that provides real-time Wi-Fi network monitoring, threat detection, and educational content to help users identify and avoid malicious networks.

### Key Features

- **🛡️ Evil Twin Detection** - Advanced algorithms to identify malicious Wi-Fi networks
- **📡 Real-time Network Scanning** - Continuous monitoring of nearby Wi-Fi networks
- **🚨 Threat Alerts** - Instant notifications for potential security risks
- **📚 Cybersecurity Education** - Interactive learning modules and quizzes
- **🗺️ Network Mapping** - Geographic visualization of network threats
- **📊 Security Dashboard** - Comprehensive overview of network security status
- **⚡ Offline-first Design** - Functionality without constant internet connection

## Tech Stack

- **Framework**: Flutter SDK >=3.0.0
- **Language**: Dart
- **State Management**: Provider Pattern
- **Database**: Firebase Firestore
- **Authentication**: Firebase Auth
- **Analytics**: Firebase Analytics & Performance
- **Maps**: Flutter Map with Leaflet
- **Location**: Geolocator
- **Networking**: Dio HTTP Client

## Prerequisites

Before setting up the project, ensure you have:

- Flutter SDK >=3.0.0
- Dart SDK >=3.0.0
- Android Studio / VS Code with Flutter extensions
- Android SDK (API level 21+)
- Firebase project configured
- Git

## Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd disconx-suite/mobile
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Ensure `google-services.json` is in `android/app/` directory
   - Verify Firebase configuration in `lib/data/services/firebase_service.dart`

4. **Generate launcher icons** (if needed)
   ```bash
   flutter pub run flutter_launcher_icons:main
   ```

## Development Commands

### Running the App
```bash
# Debug mode (development)
flutter run

# Release mode
flutter run --release

# Specific device
flutter run -d <device-id>
```

### Building
```bash
# Android APK
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# Clean build
flutter clean && flutter pub get && flutter run
```

### Testing & Quality
```bash
# Run tests
flutter test

# Code analysis (REQUIRED before commits)
flutter analyze

# Format code
dart format .
```

## Project Structure

```
lib/
├── core/
│   ├── services/           # Core system services
│   ├── theme/              # App theming and colors  
│   └── utils/              # Utility functions
├── data/
│   ├── models/             # Data models
│   ├── repositories/       # Data access layer
│   └── services/           # Business logic services
├── presentation/
│   ├── screens/            # Application screens
│   ├── widgets/            # Reusable UI components
│   └── dialogs/            # Modal dialogs
├── providers/              # State management
└── main.dart               # Application entry point
```

## Key Components

### Security Features
- **Security Analyzer** (`lib/data/services/security_analyzer.dart`)
- **Wi-Fi Connection Manager** (`lib/data/services/wifi_connection_manager.dart`)
- **Threat Reporting** (`lib/data/services/threat_reporting_service.dart`)

### Core Services
- **Firebase Service** (`lib/data/services/firebase_service.dart`)
- **Education Content** (`lib/data/services/education_content_service.dart`)
- **Network Activity Tracker** (`lib/data/services/network_activity_tracker.dart`)

### UI Screens
- **Home Screen** - Main dashboard with network overview
- **Scan Screen** - Active network scanning interface
- **Alerts Screen** - Security alerts and notifications
- **Education Screen** - Learning modules and quizzes
- **Settings Screen** - App configuration and preferences

## Configuration

### Environment Variables
Key configuration is managed in:
- `lib/data/services/firebase_service.dart` - Firebase settings
- `android/app/build.gradle` - Android-specific configuration
- `pubspec.yaml` - Dependencies and app metadata

### Permissions
The app requires these Android permissions:
- `ACCESS_FINE_LOCATION` - For network location detection
- `ACCESS_COARSE_LOCATION` - For basic location services
- `ACCESS_WIFI_STATE` - For Wi-Fi network information
- `CHANGE_WIFI_STATE` - For Wi-Fi connection management
- `INTERNET` - For Firebase connectivity

## Firebase Integration

### Required Services
- **Firestore** - Real-time database for threats and networks
- **Authentication** - User management
- **Analytics** - Usage tracking
- **Performance** - App performance monitoring
- **Messaging** - Push notifications

### Collections
- `networks` - Wi-Fi network information
- `threats` - Security threat reports
- `educational_content` - Learning materials
- `user_activity` - User interaction data

## Development Guidelines

### Code Style
- Follow Dart/Flutter style guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent file organization

### State Management
- Use Provider pattern for state management
- Follow the dependency hierarchy: NetworkProvider → AlertProvider → SettingsProvider
- Handle loading states appropriately

### Error Handling
- Implement graceful error handling
- Provide user-friendly error messages
- Use try-catch blocks for async operations

### Performance
- Optimize network calls
- Implement proper caching strategies
- Use ListView.builder for large lists
- Dispose of controllers and streams properly

## Testing

### Running Tests
```bash
# All tests
flutter test

# Specific test file
flutter test test/models/network_model_test.dart

# Test coverage
flutter test --coverage
```

### Test Structure
- Unit tests for models and services
- Widget tests for UI components
- Integration tests for user flows

## Deployment

### Android Release
1. Update version in `pubspec.yaml`
2. Build release APK: `flutter build apk --release`
3. Test on physical devices
4. Distribute through appropriate channels

### Pre-deployment Checklist
- [ ] All tests passing
- [ ] Flutter analyze returns no issues
- [ ] Firebase configuration verified
- [ ] Permissions properly configured
- [ ] Release build tested on multiple devices
- [ ] App signing configured for production

## Troubleshooting

### Common Issues

**Firebase Connection Issues**
- Verify `google-services.json` is correctly placed
- Check internet connectivity
- Ensure Firebase project is active

**Permission Errors**
- Check Android permissions in `android/app/src/main/AndroidManifest.xml`
- Test on Android 13+ for runtime permission handling

**Build Failures**
- Run `flutter clean && flutter pub get`
- Check Flutter SDK version compatibility
- Verify Gradle and Android SDK versions

### Getting Help
- Check Flutter documentation: https://flutter.dev/docs
- Firebase documentation: https://firebase.google.com/docs
- Project issues: Contact DICT-CALABARZON development team

## Contributing

This is a government project for DICT-CALABARZON. Development follows internal guidelines and approval processes.

## License

This project is licensed under DICT-CALABARZON terms. Unauthorized reproduction or distribution is prohibited.

---

**Version**: 1.0.0+1  
**Last Updated**: September 2025  
**Developed by**: DICT-CALABARZON Development Team