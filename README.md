# DisConX Mobile

A Flutter mobile application for WiFi security analysis and threat detection.

## Overview

DisConX is a cybersecurity mobile app that helps protect users from evil twin WiFi attacks through real-time network scanning, threat detection, and security education.

## Key Features

- WiFi network scanning and analysis
- Evil twin attack detection
- Security threat alerts
- Educational content and quizzes
- Offline functionality

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
├── main.dart              # App entry point
├── app.dart               # Root configuration
├── core/                  # Utilities and theming
├── data/                  # Models, repositories, services
├── presentation/          # UI screens and widgets
└── providers/             # State management
```

## Development Commands

```bash
flutter analyze           # Code analysis
flutter test              # Run tests
flutter clean             # Clean build cache
```