import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wifi_iot/wifi_iot.dart';
import '../models/network_model.dart';
import 'native_wifi_controller.dart';

class SavedNetworksService {
  static final SavedNetworksService _instance = SavedNetworksService._internal();
  factory SavedNetworksService() => _instance;
  SavedNetworksService._internal();

  static const String _savedNetworksKey = 'saved_networks';
  static const String _networkCredentialsKey = 'network_credentials';

  /// Get list of saved networks from device
  Future<List<SavedNetwork>> getSavedNetworks() async {
    try {
      final List<SavedNetwork> savedNetworks = <SavedNetwork>[];
      
      // Try to get saved networks from device (Android-specific)
      // Enhanced: Use native controller for system saved networks
      try {
          final nativeController = NativeWiFiController();
          final systemNetworks = await nativeController.getSystemSavedNetworks();
          
          for (final networkData in systemNetworks) {
            final savedNetwork = SavedNetwork(
              ssid: networkData['ssid'] ?? 'Unknown',
              bssid: networkData['bssid'] ?? 'Unknown',
              security: SecurityType.wpa2, // Default for system networks
              isConfigured: true,
              lastConnected: DateTime.now(),
            );
            savedNetworks.add(savedNetwork);
          }
          
          developer.log('Android: Found ${systemNetworks.length} system configured networks');
        } catch (e) {
          developer.log('Failed to get system networks, using local storage: $e');
        }
      
      // Always include locally stored networks
      final localSavedNetworks = await _getLocalSavedNetworks();
      savedNetworks.addAll(localSavedNetworks);
      
      // Remove duplicates based on SSID (prefer system over local)
      final uniqueNetworks = <String, SavedNetwork>{};
      for (final network in savedNetworks) {
        if (!uniqueNetworks.containsKey(network.ssid) || network.isConfigured) {
          uniqueNetworks[network.ssid] = network;
        }
      }
      
      final result = uniqueNetworks.values.toList();
      developer.log('Found ${result.length} total saved networks');
      return result;
      
    } catch (e) {
      developer.log('Error getting saved networks: $e');
      // Fall back to local storage
      return await _getLocalSavedNetworks();
    }
  }

  /// Check if a network is saved/known
  Future<bool> isNetworkSaved(String ssid) async {
    try {
      final savedNetworks = await getSavedNetworks();
      return savedNetworks.any((network) => network.ssid == ssid);
    } catch (e) {
      developer.log('Error checking if network is saved: $e');
      return false;
    }
  }

  /// Get saved credentials for a network
  Future<String?> getSavedCredentials(String ssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsMap = prefs.getStringList(_networkCredentialsKey) ?? <String>[];
      
      for (final entry in credentialsMap) {
        final parts = entry.split('|');
        if (parts.length == 2 && parts[0] == ssid) {
          return parts[1]; // Return the password
        }
      }
      
      return null;
    } catch (e) {
      developer.log('Error getting saved credentials: $e');
      return null;
    }
  }

  /// Save network credentials locally
  Future<void> saveNetworkCredentials(String ssid, String password) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final credentialsMap = prefs.getStringList(_networkCredentialsKey) ?? <String>[];
      
      // Remove existing entry for this SSID
      credentialsMap.removeWhere((entry) => entry.startsWith('$ssid|'));
      
      // Add new entry
      credentialsMap.add('$ssid|$password');
      
      // Limit to 50 saved networks
      if (credentialsMap.length > 50) {
        credentialsMap.removeAt(0);
      }
      
      await prefs.setStringList(_networkCredentialsKey, credentialsMap);
      developer.log('Saved credentials for network: $ssid');
    } catch (e) {
      developer.log('Error saving network credentials: $e');
    }
  }

  /// Save network as successfully connected
  Future<void> saveConnectedNetwork(NetworkModel network) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedNetworks = await _getLocalSavedNetworks();
      
      // Remove existing entry for this SSID
      savedNetworks.removeWhere((saved) => saved.ssid == network.name);
      
      // Add updated entry
      savedNetworks.add(SavedNetwork(
        ssid: network.name,
        bssid: network.macAddress,
        security: network.securityType,
        isConfigured: true,
        lastConnected: DateTime.now(),
      ));
      
      // Limit to 50 saved networks
      if (savedNetworks.length > 50) {
        savedNetworks.removeAt(0);
      }
      
      // Save to preferences
      final networkStrings = savedNetworks.map((network) => network.toJson()).toList();
      await prefs.setStringList(_savedNetworksKey, networkStrings);
      
      developer.log('Saved connected network: ${network.name}');
    } catch (e) {
      developer.log('Error saving connected network: $e');
    }
  }

  /// Attempt auto-connection to a saved network
  Future<bool> autoConnectToNetwork(NetworkModel network) async {
    try {
      // Check if network is saved
      final isSaved = await isNetworkSaved(network.name);
      if (!isSaved) {
        return false;
      }
      
      // Get saved credentials
      final savedPassword = await getSavedCredentials(network.name);
      
      // For open networks, try direct connection
      if (network.securityType == SecurityType.open) {
        return await _attemptConnection(network.name, null);
      }
      
      // For secured networks, use saved password
      if (savedPassword != null) {
        return await _attemptConnection(network.name, savedPassword);
      }
      
      return false;
    } catch (e) {
      developer.log('Error auto-connecting to network: $e');
      return false;
    }
  }

  /// Remove saved network
  Future<void> removeSavedNetwork(String ssid) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      
      // Remove from saved networks
      final savedNetworks = await _getLocalSavedNetworks();
      savedNetworks.removeWhere((network) => network.ssid == ssid);
      final networkStrings = savedNetworks.map((network) => network.toJson()).toList();
      await prefs.setStringList(_savedNetworksKey, networkStrings);
      
      // Remove from credentials
      final credentialsMap = prefs.getStringList(_networkCredentialsKey) ?? <String>[];
      credentialsMap.removeWhere((entry) => entry.startsWith('$ssid|'));
      await prefs.setStringList(_networkCredentialsKey, credentialsMap);
      
      developer.log('Removed saved network: $ssid');
    } catch (e) {
      developer.log('Error removing saved network: $e');
    }
  }

  /// Get locally stored saved networks
  Future<List<SavedNetwork>> _getLocalSavedNetworks() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final networkStrings = prefs.getStringList(_savedNetworksKey) ?? <String>[];
      
      return networkStrings.map((jsonString) {
        return SavedNetwork.fromJson(jsonString);
      }).toList();
    } catch (e) {
      developer.log('Error getting local saved networks: $e');
      return <SavedNetwork>[];
    }
  }


  /// Attempt connection to network
  Future<bool> _attemptConnection(String ssid, String? password) async {
    try {
      // Use WiFiIoT plugin for connection (Android)
      final isEnabled = await WiFiForIoTPlugin.isEnabled();
      if (!isEnabled) {
        developer.log('WiFi is not enabled');
        return false;
      }
      
      // For demo purposes, simulate connection
      // In production, use: await WiFiForIoTPlugin.connect(ssid, password: password);
      await Future.delayed(const Duration(seconds: 2));
      
      // Simulate success rate based on network type
      final random = DateTime.now().millisecondsSinceEpoch % 10;
      final success = random < 8; // 80% success rate
      
      developer.log('Auto-connection to $ssid: ${success ? 'success' : 'failed'}');
      return success;
    } catch (e) {
      developer.log('Error attempting connection: $e');
      return false;
    }
  }
}

/// Represents a saved network
class SavedNetwork {
  final String ssid;
  final String bssid;
  final SecurityType security;
  final bool isConfigured;
  final DateTime lastConnected;

  SavedNetwork({
    required this.ssid,
    required this.bssid,
    required this.security,
    required this.isConfigured,
    required this.lastConnected,
  });

  String toJson() {
    return '$ssid|$bssid|${security.name}|$isConfigured|${lastConnected.millisecondsSinceEpoch}';
  }

  factory SavedNetwork.fromJson(String jsonString) {
    final parts = jsonString.split('|');
    return SavedNetwork(
      ssid: parts[0],
      bssid: parts[1],
      security: SecurityType.values.firstWhere((s) => s.name == parts[2], orElse: () => SecurityType.open),
      isConfigured: parts[3] == 'true',
      lastConnected: DateTime.fromMillisecondsSinceEpoch(int.parse(parts[4])),
    );
  }
}