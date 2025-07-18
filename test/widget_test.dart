// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:disconx/app.dart';
import 'package:disconx/providers/network_provider.dart';
import 'package:disconx/providers/settings_provider.dart';
import 'package:disconx/providers/alert_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:disconx/providers/auth_provider.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    // Initialize shared preferences for testing
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AlertProvider()),
          ChangeNotifierProxyProvider<AlertProvider, NetworkProvider>(
            create: (_) => NetworkProvider(),
            update: (_, alertProvider, networkProvider) {
              networkProvider?.setAlertProvider(alertProvider);
              return networkProvider ?? NetworkProvider();
            },
          ),
          ChangeNotifierProvider(create: (_) => SettingsProvider(prefs)),
          ChangeNotifierProvider(create: (_) => AuthProvider()),
        ],
        child: const DisConXApp(),
      ),
    );

    // Verify that the app loads
    expect(find.text('DisConX'), findsOneWidget);
    
    // Wait for initialization
    await tester.pumpAndSettle();
    
    // Verify bottom navigation is present
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
    expect(find.text('Alerts'), findsOneWidget);
    expect(find.text('Learn'), findsOneWidget);
    expect(find.text('Settings'), findsOneWidget);
  });
}
