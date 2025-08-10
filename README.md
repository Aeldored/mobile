# DisConX Mobile - DICT Wi-Fi Security Scanner

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Ready-orange.svg)](https://firebase.google.com/)
[![Android](https://img.shields.io/badge/Android-5.0%2B-green.svg)](https://www.android.com/)
[![Version](https://img.shields.io/badge/Version-1.0.0-brightgreen.svg)](#)
[![License](https://img.shields.io/badge/License-DICT--CALABARZON-blue.svg)](#)

## 📱 Download & Install

### Ready to Protect Your Wi-Fi? Get DiSConX Now!

### 📥 Direct Download Options:

**🚀 [⬇️ DOWNLOAD APK - Direct Download](https://github.com/Aeldored/disconx-suite/raw/main/mobile/releases/disconx-mobile-v1.0.0.apk)**

**Alternative Download Methods:**
- **GitHub Releases**: [Browse all releases](https://github.com/Aeldored/disconx-suite/releases)
- **Repository Files**: [View in repository](releases/disconx-mobile-v1.0.0.apk)

> **Latest Version**: v1.0.0 | **File Size**: ~80 MB | **Build Date**: August 2025

#### 📋 Installation Instructions:
1. **📥 Download the APK**:
   - Click the **"⬇️ DOWNLOAD APK - Direct Download"** button above
   - APK will automatically download to your device's Downloads folder
   - File name: `disconx-mobile-v1.0.0.apk`
2. **⚙️ Enable Installation from Unknown Sources**:
   - Go to **Settings** > **Security & Privacy** > **Install unknown apps**
   - Select your browser/file manager and toggle **"Allow from this source"**
3. **📲 Install DiSConX**:
   - Tap the downloaded `disconx-mobile-v1.0.0.apk` file
   - Follow the installation prompts
   - Tap **"Install"** when prompted
4. **🚀 Launch & Setup**:
   - Open DiSConX from your app drawer
   - Grant required permissions (Location, Wi-Fi access)
   - Complete the quick security tutorial

#### 📋 System Requirements:
- **Android 5.0+** (API level 21 or higher)
- **RAM**: 2GB minimum, 4GB recommended  
- **Storage**: 100 MB free space required
- **Permissions**: Location, Wi-Fi state, Network access
- **Hardware**: Wi-Fi capability required

#### 🛡️ Security & Verification:
- **Digitally Signed**: Official DICT-CALABARZON certificate
- **Virus Scanned**: Clean - verified by multiple security vendors
- **Privacy Compliant**: No personal data collection without consent
- **Open Source**: Full source code available in this repository

---

## 🔍 Overview

**DisConX (DICT Secure Connect)** is a government-grade cybersecurity mobile application developed for **DICT-CALABARZON** to protect Filipino citizens from **evil twin Wi-Fi attacks** and other wireless network threats.

The app combines advanced threat detection algorithms with user education to enhance public network security awareness. Built with Flutter using clean architecture principles, DisConX offers both online and offline functionality, making it accessible even without internet connectivity.

### 🎯 Mission Statement
Empowering every Filipino with the tools and knowledge to safely navigate the digital world through advanced Wi-Fi security protection and cybersecurity education.

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

---

## 📦 For Repository Maintainers - Building & Releasing APK

### Build Production APK
```bash
# Navigate to mobile directory
cd mobile

# Clean previous builds
flutter clean && flutter pub get

# Build release APK
flutter build apk --release --target-platform android-arm64

# APK will be generated at: build/app/outputs/flutter-apk/app-release.apk
```

### Creating GitHub Release
1. **Build the APK** using the commands above
2. **Test thoroughly** on multiple Android devices
3. **Create Git tag**:
   ```bash
   git tag mobile-v1.0.0
   git push origin mobile-v1.0.0
   ```
4. **Create GitHub Release**:
   - Go to repository **Releases** section
   - Click **"Create a new release"**
   - Select tag `mobile-v1.0.0`
   - Upload `app-release.apk` as `disconx-mobile-v1.0.0.apk`
   - Add release notes with features and security updates

---

## 🤝 For End Users

### Why Choose DiSConX?

#### ✅ **Protect Yourself from Wi-Fi Threats**
- **Evil Twin Detection**: Automatically identifies fake Wi-Fi hotspots trying to steal your data
- **Real-time Scanning**: Continuously monitors networks for suspicious activity
- **Government Verified**: Uses official DICT whitelist of safe networks

#### ✅ **Learn Cybersecurity While You Browse**
- **Interactive Education**: Built-in learning modules about Wi-Fi security
- **Security Tips**: Practical advice for staying safe online
- **Threat Awareness**: Understand how cybercriminals target public Wi-Fi users

#### ✅ **Works Everywhere, Anytime**
- **Offline Mode**: Full functionality without internet connection
- **Battery Optimized**: Won't drain your phone battery
- **Fast & Responsive**: Instant network analysis and alerts

### 📞 Support & Feedback

- **Technical Issues**: Create an issue in this repository
- **Security Concerns**: Report to DICT-CALABARZON cybersecurity team
- **Feature Requests**: Submit through GitHub Discussions
- **General Inquiries**: Contact the development team

### 📄 Privacy & Legal

- **Data Collection**: Only anonymous usage statistics (optional)
- **Location Data**: Used locally for network mapping, never transmitted
- **Government Use**: Authorized by DICT-CALABARZON for public safety
- **Open Source**: Full transparency with publicly available code

---

## 🏛️ Official Government Project

This application is an **official cybersecurity initiative** by the **Department of Information and Communications Technology - CALABARZON Region (DICT-CALABARZON)**, developed to enhance public Wi-Fi security awareness and protect citizens from cyber threats.

**Project Status**: ✅ **Production Ready** | **Government Approved** | **Open Source**