# DisConX Mobile

A Flutter mobile application for WiFi security analysis and threat detection, designed to protect users from malicious network attacks.

## Overview

DisConX (DICT Secure Connect) is a cybersecurity mobile application that provides real-time WiFi network analysis and protection against evil twin attacks. The app combines advanced threat detection algorithms with user education to enhance public network security awareness.

Built with Flutter using clean architecture principles, DisConX offers both online and offline functionality, making it accessible even without internet connectivity. The application integrates with government whitelists and provides comprehensive security assessments for WiFi networks.

## Key Features

### Security & Detection
- **Real-time WiFi Scanning** - Comprehensive network discovery and analysis
- **Evil Twin Detection** - Advanced algorithms using signal pattern analysis and MAC verification
- **Threat Scoring System** - Dynamic risk assessment (0-100 scale) for detected networks
- **Security Alerts** - Instant notifications for potential threats
- **Government Whitelist Integration** - Verification against approved network databases

### User Experience
- **Interactive Dashboard** - Visual network maps and security status
- **Educational Content** - Cybersecurity learning modules and quizzes
- **Offline Mode** - Full functionality without internet connection
- **Material Design 3** - Modern, accessible user interface
- **Multi-language Support** - English and Filipino/Tagalog (planned)

### Technical Features
- **Clean Architecture** - Scalable and maintainable codebase
- **Firebase Integration** - Cloud services for data sync and analytics
- **Cross-platform Support** - Android (primary) with iOS roadmap
- **Performance Optimized** - 60fps UI with efficient memory usage

## Requirements

- Flutter SDK >=3.0.0
- Android 6.0+ (API Level 23+)
- Dart >=3.0.0

## Quick Start

1. Install dependencies:
   ```bash
   flutter pub get
   ```

2. Run the app:
   ```bash
   flutter run
   ```

3. Build for production:
   ```bash
   flutter build apk --release
   ```

## Project Structure

```
lib/
├── main.dart              # Application entry point
├── app.dart               # Root app configuration
├── core/                  # Core utilities and theming
│   ├── constants/         # App-wide constants
│   ├── theme/             # Material Design 3 theming
│   └── utils/             # Helper utilities
├── data/                  # Data management layer
│   ├── models/            # Data models and serialization
│   ├── repositories/      # Repository pattern implementation
│   └── services/          # External service integrations
├── presentation/          # User interface layer
│   ├── screens/           # Application screens
│   │   ├── home/          # Dashboard and network overview
│   │   ├── scan/          # WiFi scanning interface
│   │   ├── alerts/        # Security alerts and threats
│   │   ├── education/     # Learning modules and quizzes
│   │   └── settings/      # User preferences and configuration
│   └── widgets/           # Reusable UI components
└── providers/             # State management providers
```

## Architecture

DisConX follows **Clean Architecture** principles with clear separation of concerns:

- **Presentation Layer**: Flutter widgets and screens using Material Design 3
- **Business Logic**: State management with Provider pattern
- **Data Layer**: Repository pattern with intelligent caching
- **External Services**: Firebase integration and native platform services

## Firebase Integration

The app is Firebase-ready with the following services configured:
- **Authentication** - Anonymous and email-based auth
- **Firestore** - Real-time data synchronization
- **Storage** - Whitelist file downloads
- **Analytics** - User behavior tracking
- **Performance Monitoring** - App performance metrics

## Development Commands

```bash
# Dependency management
flutter pub get              # Install dependencies
flutter pub upgrade          # Update dependencies

# Development
flutter run --debug          # Run debug build
flutter run --release        # Run release build

# Code quality
flutter analyze              # Static code analysis
flutter test                 # Run unit tests
flutter test --coverage      # Run tests with coverage

# Build
flutter build apk --release  # Build Android APK
flutter build appbundle      # Build Android App Bundle

# Maintenance
flutter clean                # Clean build cache
flutter doctor               # Check development setup
```
