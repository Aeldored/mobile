# DiSConX - DICT Secure Connect Mobile App

[![Flutter](https://img.shields.io/badge/Flutter-3.0%2B-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Ready-orange.svg)](https://firebase.google.com/)
[![License](https://img.shields.io/badge/License-DICT--CALABARZON-green.svg)](#)

## Overview

**DiSConX** (DICT Secure Connect) is a government-grade mobile security application designed to protect users from evil twin Wi-Fi attacks on public networks. Developed for DICT-CALABARZON, this Flutter application serves as the mobile companion to a comprehensive web-based admin monitoring system.

### Key Capabilities
- **🔍 Real-time Network Scanning** - Detect and analyze nearby Wi-Fi networks
- **🛡️ Evil Twin Detection** - Advanced algorithms to identify malicious access points
- **📍 Government Whitelist Verification** - Cross-reference against DICT's verified network database
- **🚨 Intelligent Alert System** - Real-time threat notifications and auto-blocking
- **📚 Security Education** - Interactive learning modules about Wi-Fi security
- **📊 Network Analytics** - Visual mapping and signal strength monitoring

## 🏗️ Architecture Overview

DiSConX implements a **production-grade clean architecture** with enterprise-level patterns:

```
┌─────────────────────────────────────────────────────────────┐
│                    PRESENTATION LAYER                       │
├─────────────────────────────────────────────────────────────┤
│  Screens: Home │ Scan │ Alerts │ Education │ Settings       │
│  Widgets: Reusable UI Components & Custom Widgets          │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                   STATE MANAGEMENT                          │
├─────────────────────────────────────────────────────────────┤
│  Provider Pattern: NetworkProvider │ AuthProvider           │
│                   SettingsProvider │ AlertProvider          │
└─────────────────────────────────────────────────────────────┘
                              │
┌─────────────────────────────────────────────────────────────┐
│                      DATA LAYER                             │
├─────────────────────────────────────────────────────────────┤
│  Repositories: Network │ Alert │ Whitelist (with caching)   │
│  Services: Firebase │ Location │ Analytics                  │
│  Models: Strongly-typed data structures                     │
└─────────────────────────────────────────────────────────────┘
```

### Design Patterns
- **🎯 Provider Pattern** - Reactive state management
- **🏪 Repository Pattern** - Data abstraction with caching
- **🔧 Service Layer** - External API integration
- **🧩 Component Architecture** - Reusable UI components

## 📁 Project Structure

```
lib/
├── 🚀 main.dart                     # Application entry point
├── 📱 app.dart                      # Root app configuration
├── 🎨 core/                         # Core utilities & theming
│   ├── constants/                   # App-wide constants
│   ├── theme/                       # Material Design 3 theming
│   └── utils/                       # Helper utilities
├── 📊 data/                         # Data management layer
│   ├── models/                      # Data models & serialization
│   ├── repositories/                # Repository pattern implementation
│   └── services/                    # External service integrations
├── 🖥️ presentation/                 # User interface layer
│   ├── screens/                     # Application screens
│   │   ├── home/                    # Network overview & quick actions
│   │   ├── scan/                    # Active network scanning
│   │   ├── alerts/                  # Security alerts & threats
│   │   ├── education/               # Learning modules
│   │   └── settings/                # User preferences
│   └── widgets/                     # Reusable UI components
└── 🔄 providers/                    # State management providers
```

## 🛠️ Setup & Installation

### Prerequisites

- **Flutter SDK** `>=3.0.0` with Dart `>=3.0.0`
- **Android Studio** or **VS Code** with Flutter extensions
- **Android Device/Emulator** with API level 23+ (Android 6.0+)
- **Git** for version control

### Quick Start

1. **Clone the Repository**
   ```bash
   git clone https://github.com/dict-calabarzon/disconx-mobile.git
   cd disconx
   ```

2. **Install Dependencies**
   ```bash
   flutter pub get
   ```

3. **Verify Installation**
   ```bash
   flutter doctor
   ```

4. **Run the Application**
   ```bash
   flutter run
   ```

### Asset Setup

The application requires placeholder images in the `assets/images/` directory:
- `map_placeholder.png` - Network map background
- `image1.png` & `image2.png` - Educational content

**Note**: These directories and files are already configured and present in the repository.

## 🔥 Firebase Integration

DiSConX is **Firebase-ready** with enterprise-level cloud integration capabilities.

### Current State
- ✅ **Firebase SDK Integrated** - All services configured
- ✅ **Offline-First Design** - Works without Firebase connection
- ✅ **Production-Ready Services** - Analytics, Firestore, Storage, Auth
- ⏳ **Activation Required** - Uncomment initialization when backend is ready

### Activation Steps

1. **Create Firebase Project**
   ```bash
   # Visit https://console.firebase.google.com/
   # Create project: "disconx-production"
   ```

2. **Configure Android App**
   ```bash
   # Package name: com.dict.disconx
   # Download google-services.json to android/app/
   ```

3. **Uncomment Firebase Initialization**
   ```dart
   // In android/build.gradle.kts
   classpath("com.google.gms:google-services:4.4.0")
   
   // In android/app/build.gradle.kts  
   id("com.google.gms.google-services")
   
   // In main.dart
   await Firebase.initializeApp();
   ```

### Firebase Services Ready

| Service | Status | Capabilities |
|---------|--------|-------------|
| **🔐 Authentication** | ✅ Ready | Anonymous & email auth |
| **💾 Firestore** | ✅ Ready | Real-time data sync, offline caching |
| **📁 Storage** | ✅ Ready | Whitelist file downloads |
| **📊 Analytics** | ✅ Ready | User behavior & performance tracking |
| **⚡ Performance** | ✅ Ready | Custom trace monitoring |
| **🔔 Messaging** | ✅ Ready | Push notifications |

## 🌐 Government Whitelist Integration

DiSConX integrates with DICT's centralized whitelist system:

### Data Flow
```
DICT Backend API → Firebase Firestore → Local Cache → App UI
     ↓                    ↓                ↓
Government DB      Real-time Sync    Offline Access
```

### Implementation
- **📦 Multi-source Fetching** - Firebase Storage + Firestore fallback
- **🔄 Real-time Updates** - Live whitelist synchronization  
- **💾 Smart Caching** - 24-hour cache with force refresh
- **🔐 Data Integrity** - Checksum verification for security

## 🚀 Build & Deployment

### Development Build
```bash
flutter run --debug
```

### Production Build
```bash
# Android APK
flutter build apk --release

# Android App Bundle (Google Play)
flutter build appbundle --release
```

### Build Artifacts
- **APK**: `build/app/outputs/flutter-apk/app-release.apk`
- **AAB**: `build/app/outputs/bundle/release/app-release.aab`

## 🔧 Development Commands

Essential commands for development workflow:

```bash
# 📦 Dependency Management
flutter pub get                    # Install dependencies
flutter pub upgrade                # Update dependencies

# 🔍 Code Quality
flutter analyze                    # Static code analysis
flutter test                       # Run unit tests

# 🧹 Maintenance  
flutter clean                      # Clean build cache
flutter pub deps                   # Dependency tree
```

## 🏛️ Security Features

### Evil Twin Detection
- **📡 Signal Analysis** - Strength patterns and anomaly detection
- **🔍 MAC Address Verification** - Government whitelist cross-reference
- **🚨 Auto-blocking** - Immediate protection from suspicious networks
- **📍 Location Correlation** - Geographic verification against known APs

### Privacy Protection
- **🕵️ Anonymous Mode** - Optional anonymous authentication
- **🔒 Local-First Storage** - Sensitive data kept on device
- **⚡ Minimal Data Collection** - Only security-relevant information
- **🛡️ Encrypted Communications** - All API calls secured

## 🧪 Testing

### Test Configuration
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/widget_test.dart

# Test with coverage
flutter test --coverage
```

### Test Structure
- **🧪 Widget Tests** - UI component testing
- **⚡ Unit Tests** - Business logic validation
- **🔄 Integration Tests** - End-to-end scenarios

## 🔧 Configuration

### Environment Configuration
```dart
// lib/core/constants/app_constants.dart
class AppConstants {
  static const String baseApiUrl = 'https://api.disconx.dict.gov.ph';
  static const String appName = 'DisConX';
  static const Duration cacheExpiration = Duration(hours: 24);
}
```

### App Permissions (Android)
- `INTERNET` - API communication
- `ACCESS_NETWORK_STATE` - Network connectivity
- `ACCESS_WIFI_STATE` - Wi-Fi scanning
- `ACCESS_FINE_LOCATION` - Precise location for verification
- `CAMERA` - QR code scanning (future feature)

## 📈 Performance Optimization

- **⚡ Efficient State Management** - Minimal rebuilds with Provider
- **🎨 Optimized Rendering** - SliverList for large data sets
- **💾 Smart Caching** - Repository pattern with TTL
- **📱 Memory Management** - Proper resource disposal

## 🐛 Troubleshooting

### Common Issues & Solutions

**Build Failures**
```bash
flutter clean && flutter pub get
```

**Firebase Connection Issues**
```bash
# Verify google-services.json placement
# Check package name consistency
# Ensure Firebase initialization is uncommented
```

**Performance Issues**
```bash
# Enable performance profiling
flutter run --profile
```

## 🚦 Project Status

### ✅ Production Ready
- **Architecture**: Clean, scalable, maintainable
- **Code Quality**: No compilation errors, modern Flutter APIs
- **Firebase**: Enterprise-level integration prepared
- **Security**: Government-grade implementation
- **Testing**: Framework ready for comprehensive testing

### 📋 Deployment Checklist
- [ ] Update package name to `com.dict.disconx`
- [ ] Add Firebase configuration files
- [ ] Enable Firebase services
- [ ] Configure backend API endpoints
- [ ] Add production signing certificates

## 🤝 Contributing

Please follow the established architecture patterns and code style when contributing:

1. **🔍 Code Review** - All changes require review
2. **🧪 Testing** - Add tests for new features
3. **📝 Documentation** - Update docs for significant changes
4. **🎨 UI/UX** - Follow Material Design 3 guidelines

## 📄 License

**© 2025 DICT-CALABARZON. All rights reserved.**

This software is developed exclusively for DICT-CALABARZON and its authorized government use cases.

---

**Project Lead**: DICT-CALABARZON Development Team  
**Support**: [dict-calabarzon@gov.ph](mailto:dict-calabarzon@gov.ph)  
**Documentation**: Internal development reference available in `CLAUDE.md`