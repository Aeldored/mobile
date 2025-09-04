import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app.dart';
import 'providers/network_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/auth_provider.dart';
import 'providers/alert_provider.dart';
import 'providers/map_state_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Only perform essential initialization that must happen before UI
  // Set preferred orientations to portrait only
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  // Initialize only SharedPreferences (lightweight and required for providers)
  final prefs = await SharedPreferences.getInstance();
  
  // Defer all heavy initialization to splash screen to prevent ANR
  // Firebase, services, and heavy operations will happen during splash
  developer.log('🚀 Main initialization complete - deferring heavy operations to splash screen');
  
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
            // Firebase initialization now happens during splash screen
            // This ensures all heavy operations complete during loading
            return networkProvider;
          },
          update: (_, alertProvider, networkProvider) {
            networkProvider?.setAlertProvider(alertProvider);
            alertProvider.setNetworkProvider(networkProvider ?? NetworkProvider());
            return networkProvider ?? NetworkProvider();  
          },
        ),
        
        // SettingsProvider depends on AlertProvider and NetworkProvider
        ChangeNotifierProxyProvider2<AlertProvider, NetworkProvider, SettingsProvider>(
          create: (_) => SettingsProvider(prefs),
          update: (_, alertProvider, networkProvider, settingsProvider) {
            settingsProvider?.setProviderDependencies(networkProvider, alertProvider);
            // Also set SettingsProvider dependency in NetworkProvider
            networkProvider.setSettingsProvider(settingsProvider!);
            return settingsProvider;
          },
        ),
      ],
      child: const DisConXApp(),
    ),
  );
}