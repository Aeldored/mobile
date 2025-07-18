import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/constants/app_constants.dart';
import '../models/network_model.dart';
import '../services/firebase_service.dart';

class NetworkRepository {
  final Dio _dio;
  // Firebase service reserved for future integration - not currently used
  final SharedPreferences _prefs;

  NetworkRepository({
    required Dio dio,
    required FirebaseService firebaseService,
    required SharedPreferences prefs,
  })  : _dio = dio,
        _prefs = prefs;

  // Fetch networks from API
  Future<List<NetworkModel>> fetchNetworks() async {
    try {
      final response = await _dio.get(
        AppConstants.networksEndpoint,
        options: Options(
          receiveTimeout: Duration(milliseconds: AppConstants.networkTimeout.inMilliseconds),
          sendTimeout: Duration(milliseconds: AppConstants.networkTimeout.inMilliseconds),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['networks'];
        final networks = data.map((json) => NetworkModel.fromJson(json)).toList();
        
        // Cache the networks
        await _cacheNetworks(networks);
        
        return networks;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch networks',
        );
      }
    } on DioException catch (e) {
      // If network error, try to load from cache
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.unknown) {
        return await _getCachedNetworks();
      }
      rethrow;
    }
  }

  // Get whitelist from API
  Future<List<String>> fetchWhitelist() async {
    try {
      final response = await _dio.get(
        AppConstants.whitelistEndpoint,
        options: Options(
          receiveTimeout: Duration(milliseconds: AppConstants.networkTimeout.inMilliseconds),
        ),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['whitelist'];
        final whitelist = data.cast<String>();
        
        // Cache the whitelist
        await _cacheWhitelist(whitelist);
        
        return whitelist;
      } else {
        throw DioException(
          requestOptions: response.requestOptions,
          response: response,
          message: 'Failed to fetch whitelist',
        );
      }
    } on DioException catch (e) {
      // If network error, try to load from cache
      if (e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.receiveTimeout ||
          e.type == DioExceptionType.unknown) {
        return await _getCachedWhitelist();
      }
      rethrow;
    }
  }

  // Report suspicious network
  Future<bool> reportNetwork(NetworkModel network, String reason) async {
    try {
      final response = await _dio.post(
        AppConstants.reportEndpoint,
        data: {
          'networkId': network.id,
          'macAddress': network.macAddress,
          'name': network.name,
          'reason': reason,
          'location': {
            'latitude': network.latitude,
            'longitude': network.longitude,
          },
          'timestamp': DateTime.now().toIso8601String(),
        },
      );

      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  // Save network to local history
  Future<void> saveToHistory(NetworkModel network) async {
    final history = await getNetworkHistory();
    
    // Remove if already exists
    history.removeWhere((n) => n.id == network.id);
    
    // Add to beginning
    history.insert(0, network);
    
    // Limit history size
    if (history.length > AppConstants.maxNetworkHistory) {
      history.removeRange(
        AppConstants.maxNetworkHistory,
        history.length,
      );
    }
    
    // Save to preferences
    final jsonList = history.map((n) => n.toJson()).toList();
    await _prefs.setString(AppConstants.keyNetworkHistory, jsonEncode(jsonList));
  }

  // Get network history
  Future<List<NetworkModel>> getNetworkHistory() async {
    final jsonString = _prefs.getString(AppConstants.keyNetworkHistory);
    if (jsonString == null) return [];
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => NetworkModel.fromJson(json)).toList();
  }

  // Block network
  Future<void> blockNetwork(String networkId) async {
    final blockedIds = await getBlockedNetworkIds();
    blockedIds.add(networkId);
    await _prefs.setStringList(AppConstants.keyBlockedNetworks, blockedIds.toList());
  }

  // Unblock network
  Future<void> unblockNetwork(String networkId) async {
    final blockedIds = await getBlockedNetworkIds();
    blockedIds.remove(networkId);
    await _prefs.setStringList(AppConstants.keyBlockedNetworks, blockedIds.toList());
  }

  // Get blocked network IDs
  Future<Set<String>> getBlockedNetworkIds() async {
    final ids = _prefs.getStringList(AppConstants.keyBlockedNetworks) ?? [];
    return ids.toSet();
  }

  // Private cache methods
  Future<void> _cacheNetworks(List<NetworkModel> networks) async {
    final jsonList = networks.map((n) => n.toJson()).toList();
    await _prefs.setString('cached_networks', jsonEncode(jsonList));
    await _prefs.setString('cache_timestamp', DateTime.now().toIso8601String());
  }

  Future<List<NetworkModel>> _getCachedNetworks() async {
    final jsonString = _prefs.getString('cached_networks');
    if (jsonString == null) return [];
    
    // Check cache expiration
    final cacheTimestamp = _prefs.getString('cache_timestamp');
    if (cacheTimestamp != null) {
      final cachedTime = DateTime.parse(cacheTimestamp);
      if (DateTime.now().difference(cachedTime) > AppConstants.cacheExpiration) {
        return []; // Cache expired
      }
    }
    
    final List<dynamic> jsonList = jsonDecode(jsonString);
    return jsonList.map((json) => NetworkModel.fromJson(json)).toList();
  }

  Future<void> _cacheWhitelist(List<String> whitelist) async {
    await _prefs.setStringList(AppConstants.keyWhitelistCache, whitelist);
    await _prefs.setString('whitelist_cache_timestamp', DateTime.now().toIso8601String());
  }

  Future<List<String>> _getCachedWhitelist() async {
    final whitelist = _prefs.getStringList(AppConstants.keyWhitelistCache) ?? [];
    
    // Check cache expiration
    final cacheTimestamp = _prefs.getString('whitelist_cache_timestamp');
    if (cacheTimestamp != null) {
      final cachedTime = DateTime.parse(cacheTimestamp);
      if (DateTime.now().difference(cachedTime) > AppConstants.cacheExpiration) {
        return []; // Cache expired
      }
    }
    
    return whitelist;
  }

  // Clear all cached data
  Future<void> clearCache() async {
    await _prefs.remove('cached_networks');
    await _prefs.remove('cache_timestamp');
    await _prefs.remove(AppConstants.keyWhitelistCache);
    await _prefs.remove('whitelist_cache_timestamp');
  }
}