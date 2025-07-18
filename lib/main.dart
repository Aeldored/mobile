import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/network_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/map_state_provider.dart';
import 'data/services/firebase_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize services
  final prefs = await SharedPreferences.getInstance();
  
  // Initialize Firebase with error handling
  try {
    await Firebase.initializeApp();
    developer.log('Firebase initialized successfully');
    
    // Initialize Firebase service
    final firebaseService = FirebaseService();
    await firebaseService.initialize();
  } catch (e) {
    developer.log('Firebase initialization failed: $e');
    developer.log('App will continue with local functionality only');
  }
  
  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );
  
  runApp(
    MultiProvider(
      providers: [
        // Independent providers
        ChangeNotifierProvider(create: (_) => AlertProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => MapStateProvider(prefs)),
        
        // NetworkProvider depends on AlertProvider
        ChangeNotifierProxyProvider<AlertProvider, NetworkProvider>(
          create: (_) {
            final networkProvider = NetworkProvider();
            // Initialize Firebase after the first frame
            WidgetsBinding.instance.addPostFrameCallback((_) {
              networkProvider.initializeFirebase(prefs).catchError((e) {
                developer.log('NetworkProvider Firebase initialization failed: $e');
              });
            });
            return networkProvider;
          },
          update: (_, alertProvider, networkProvider) {
            networkProvider?.setAlertProvider(alertProvider);
            return networkProvider ?? NetworkProvider();
          },
        ),
        
        // SettingsProvider depends on AlertProvider and NetworkProvider
        ChangeNotifierProxyProvider2<AlertProvider, NetworkProvider, SettingsProvider>(
          create: (_) => SettingsProvider(prefs),
          update: (_, alertProvider, networkProvider, settingsProvider) {
            settingsProvider?.setProviderDependencies(networkProvider, alertProvider);
            return settingsProvider ?? SettingsProvider(prefs);
          },
        ),
      ],
      child: const DisConXApp(),
    ),
  );
}