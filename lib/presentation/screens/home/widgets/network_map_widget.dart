import 'dart:developer' as developer;
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../providers/network_provider.dart';
import '../../../../providers/settings_provider.dart';
import '../../../../providers/map_state_provider.dart';
import '../../../../data/services/geocoding_service.dart';
import '../../../../data/services/access_point_service.dart';
import '../../../../data/services/permission_service.dart';
import '../../../../data/services/whitelist_service.dart';
import '../../../../data/models/network_model.dart';

class NetworkMapWidget extends StatefulWidget {
  const NetworkMapWidget({super.key});

  @override
  State<NetworkMapWidget> createState() => _NetworkMapWidgetState();
}

class _NetworkMapWidgetState extends State<NetworkMapWidget> with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  late final MapController _mapController;
  final GeocodingService _geocodingService = GeocodingService();
  final AccessPointService _accessPointService = AccessPointService();
  final PermissionService _permissionService = PermissionService();
  // Removed: Using NetworkProvider as single source of truth for whitelist data
  // final WhitelistService _whitelistService = WhitelistService();
  
  @override
  bool get wantKeepAlive => true;
  
  bool _isMapExpanded = false;
  MapOptions? _mapOptions;
  String _selectedProvince = 'All';
  LatLng? _currentLocation;
  bool _isLocating = false;
  bool _hasLocationPermission = false;
  bool _isLegendExpanded = false;
  bool _isMapReady = false;
  bool _mapInitialized = false;
  // Note: _showWhitelistedNetworks now comes from SettingsProvider
  List<WhitelistEntry> _whitelistedNetworks = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _mapController = MapController();
    _initializeMapOptions();
    _accessPointService.initialize();
    _checkLocationPermission();
    _loadWhitelistedNetworks();
    
    // Debug: Test whitelist service immediately and after delay
    _testWhitelistService();
    
    // Also test after a delay to ensure Firebase is ready
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        developer.log('🔄 DELAYED TEST: Testing whitelist after 1 second...');
        _testWhitelistService();
      }
    });
    
    // Set map as ready after a brief delay to allow for initialization
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        setState(() {
          _isMapReady = true;
        });
        _initializeMapState();
        
        // Force multiple whitelist loads to ensure success
        Future.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _whitelistedNetworks.isEmpty) {
            developer.log('🔄 Map ready, forcing whitelist reload attempt 1...');
            _loadWhitelistedNetworks();
          }
        });
        
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (mounted && _whitelistedNetworks.isEmpty) {
            developer.log('🔄 2 seconds later, forcing whitelist reload attempt 2...');
            _loadWhitelistedNetworks();
          }
        });
        
        Future.delayed(const Duration(milliseconds: 5000), () {
          if (mounted && _whitelistedNetworks.isEmpty) {
            developer.log('🔄 5 seconds later, forcing whitelist reload attempt 3...');
            _loadWhitelistedNetworks();
          }
        });
        
        // Extended retry attempts for Firebase initialization
        Future.delayed(const Duration(milliseconds: 10000), () {
          if (mounted && _whitelistedNetworks.isEmpty) {
            developer.log('🔄 10 seconds later, forcing whitelist reload attempt 4...');
            _loadWhitelistedNetworks();
          }
        });
        
        Future.delayed(const Duration(milliseconds: 15000), () {
          if (mounted && _whitelistedNetworks.isEmpty) {
            developer.log('🔄 15 seconds later, forcing whitelist reload attempt 5...');
            _loadWhitelistedNetworks();
          }
        });
      }
    });
    
    // Listen for settings changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncWithSettings();
      // Removed auto-updates - refresh should be manual only
      // _setupProviderListeners();
    });
  }
  

  /// Initialize map options once to prevent assertion errors
  void _initializeMapOptions() {
    _mapOptions = MapOptions(
      initialCenter: _getInitialCenter(),
      initialZoom: _getInitialZoom(),
      minZoom: 8.0,
      maxZoom: 18.0,
      // Restrict bounds to CALABARZON region
      cameraConstraint: CameraConstraint.contain(
        bounds: LatLngBounds(
          const LatLng(13.0, 120.0), // Southwest
          const LatLng(15.0, 122.0), // Northeast
        ),
      ),
      onTap: (tapPosition, point) => _onMapTap(point),
      onPositionChanged: (camera, hasGesture) => _onMapMoved(camera, hasGesture),
      // Keep interaction options constant to avoid assertion errors
      interactionOptions: const InteractionOptions(
        flags: InteractiveFlag.all,
      ),
    );
  }
  
  /// Initialize map state and restore last camera position
  void _initializeMapState() {
    if (_mapInitialized) return;
    
    try {
      final mapStateProvider = context.read<MapStateProvider>();
      
      // Restore camera position if available and map controller is ready
      if (mapStateProvider.hasCustomCameraPosition && _isMapControllerReady()) {
        _safeMapMove(mapStateProvider.cameraPosition, mapStateProvider.zoomLevel);
      }
      
      // Restore last known location if available
      if (mapStateProvider.lastKnownLocation != null) {
        setState(() {
          _currentLocation = mapStateProvider.lastKnownLocation;
        });
      }
      
      _mapInitialized = true;
    } catch (e) {
      developer.log('Error initializing map state: $e');
    }
  }
  
  /// Check if map controller is ready and safe to use
  bool _isMapControllerReady() {
    try {
      // Check if the widget is still mounted, map is ready, and controller is initialized
      return mounted && _isMapReady;
    } catch (e) {
      developer.log('Map controller not ready: $e');
      return false;
    }
  }
  
  /// Safely move map camera with enhanced animation and error handling
  Future<void> _safeMapMove(LatLng position, double zoom) async {
    if (!_isMapControllerReady()) {
      developer.log('Map controller not ready for move operation');
      return;
    }
    
    try {
      // Use smooth animated move for better user experience
      final currentZoom = _mapController.camera.zoom;
      final targetZoom = zoom;
      
      // If zooming in significantly, do a two-step animation for smoother UX
      if (targetZoom - currentZoom > 4.0) {
        // First step: Move to location with current zoom
        _mapController.move(position, currentZoom);
        await Future.delayed(const Duration(milliseconds: 300));
        
        // Second step: Zoom in smoothly
        if (_isMapControllerReady()) {
          _mapController.move(position, targetZoom);
        }
      } else {
        // Direct smooth move for smaller zoom changes
        _mapController.move(position, targetZoom);
      }
      
    } catch (e) {
      developer.log('Map move failed: $e');
      // Retry once after a short delay
      await Future.delayed(const Duration(milliseconds: 100));
      try {
        if (_isMapControllerReady()) {
          _mapController.move(position, zoom);
        }
      } catch (retryError) {
        developer.log('Map move retry failed: $retryError');
      }
    }
  }
  
  /// Sync with SettingsProvider location status
  void _syncWithSettings() {
    try {
      final settingsProvider = context.read<SettingsProvider>();
      final isLocationActuallyAvailable = settingsProvider.isLocationActuallyAvailable;
      
      if (_hasLocationPermission != isLocationActuallyAvailable) {
        setState(() {
          _hasLocationPermission = isLocationActuallyAvailable;
        });
      }
    } catch (e) {
      developer.log('Error syncing with settings: $e');
    }
  }

  Future<void> _checkLocationPermission() async {
    try {
      final status = await _permissionService.checkLocationPermission();
      if (mounted) {
        setState(() {
          _hasLocationPermission = status == PermissionStatus.granted;
        });
      }
    } catch (e) {
      developer.log('Error checking location permission: $e');
    }
  }

  /// Load whitelisted networks from Firestore with offline support
  Future<void> _loadWhitelistedNetworks() async {
    try {
      developer.log('🔍 MAIN LOAD: Loading whitelisted networks from map widget...');
      
      // Check if Firebase is initialized first
      if (Firebase.apps.isEmpty) {
        developer.log('⚠️ MAIN LOAD: Firebase not initialized yet, will retry later');
        return;
      }
      
      developer.log('🔍 MAIN LOAD: Getting whitelist entries from NetworkProvider...');
      final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
      final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
      
      developer.log('🔍 MAIN LOAD DEBUG:');
      developer.log('   - Firebase enabled: ${networkProvider.firebaseEnabled}');
      developer.log('   - Show verified networks: ${settingsProvider.showVerifiedNetworks}');
      developer.log('   - Current whitelist null: ${networkProvider.currentWhitelist == null}');
      if (networkProvider.currentWhitelist != null) {
        developer.log('   - Current whitelist access points: ${networkProvider.currentWhitelist!.accessPoints.length}');
      }
      
      // CRITICAL FIX: Check if NetworkProvider Firebase is initialized, if not, initialize it
      if (!networkProvider.firebaseEnabled) {
        developer.log('🔧 MAIN LOAD: NetworkProvider Firebase not initialized, initializing now...');
        try {
          final prefs = await SharedPreferences.getInstance();
          await networkProvider.initializeFirebase(prefs);
          developer.log('✅ MAIN LOAD: NetworkProvider Firebase initialized successfully');
          developer.log('   - After init, whitelist access points: ${networkProvider.currentWhitelist?.accessPoints.length ?? 0}');
        } catch (e) {
          developer.log('❌ MAIN LOAD: NetworkProvider Firebase initialization failed: $e');
        }
      }
      
      final whitelistEntries = networkProvider.getWhitelistEntries();
      
      developer.log('📊 Received ${whitelistEntries.length} whitelist entries');
      
      // Debug: Log details of first few entries
      for (int i = 0; i < whitelistEntries.length && i < 3; i++) {
        final entry = whitelistEntries[i];
        developer.log('📍 Entry $i: ${entry.ssid} at (${entry.latitude}, ${entry.longitude}) - Valid: ${entry.hasValidLocation}');
      }
      
      if (mounted) {
        setState(() {
          _whitelistedNetworks = whitelistEntries;
        });
        developer.log('✅ Set ${whitelistEntries.length} whitelisted networks from database in state');
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        developer.log('🎯 Show whitelist flag: ${settingsProvider.showVerifiedNetworks}');
      }
    } catch (e) {
      developer.log('❌ Error loading whitelist: $e');
      developer.log('❌ Error type: ${e.runtimeType}');
      
      // No fallback - use empty list if database fails
      if (mounted) {
        setState(() {
          _whitelistedNetworks = [];
        });
        developer.log('⚠️ Using empty whitelist due to database error');
      }
    }
  }
  /// Toggle whitelist visibility with forced map rebuild
  void _toggleWhitelistVisibility() {
    developer.log('🔄 TOGGLE WHITELIST BUTTON PRESSED!');
    final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
    developer.log('  - Current state: ${settingsProvider.showVerifiedNetworks}');
    developer.log('  - Current count: ${_whitelistedNetworks.length}');
    
    // Use the SettingsProvider to toggle and persist the setting
    settingsProvider.toggleShowVerifiedNetworks();
    
    developer.log('  - New state: ${settingsProvider.showVerifiedNetworks}');
    
    // CRITICAL FIX: Force map widget rebuild to ensure visibility changes apply
    if (mounted) {
      setState(() {
        // Trigger widget rebuild to apply toggle changes
        developer.log('🔄 FORCING MAP WIDGET REBUILD FOR TOGGLE VISIBILITY');
      });
    }
    
    // Refresh whitelist if showing and list is empty
    if (settingsProvider.showVerifiedNetworks && _whitelistedNetworks.isEmpty) {
      developer.log('  - Loading whitelist because showing but empty');
      _loadWhitelistedNetworks();
    }
  }
  
  /// Force refresh whitelist data from NetworkProvider
  Future<void> refreshWhitelistData() async {
    developer.log('🔄 Force refreshing whitelist data via NetworkProvider...');
    if (!mounted) return;
    
    final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
    
    // Trigger NetworkProvider to refresh its whitelist data
    await networkProvider.refreshWhitelist();
    
    // Get the updated entries
    final whitelistEntries = networkProvider.getWhitelistEntries();
    
    if (mounted) {
      setState(() {
        _whitelistedNetworks = whitelistEntries;
      });
      developer.log('✅ Updated whitelist data via NetworkProvider: ${whitelistEntries.length} entries');
    }
  }
  
  /// Debug method to test whitelist service
  Future<void> _testWhitelistService() async {
    developer.log('🧪 TESTING WHITELIST SERVICE...');
    developer.log('🧪 Expected: 17 access points from Firestore');
    
    try {
      // Check if Firebase is initialized first
      if (Firebase.apps.isEmpty) {
        developer.log('🧪 ⚠️ Firebase not initialized yet, skipping direct Firestore test');
        
        // Test the NetworkProvider which has proper initialization checks
        developer.log('🧪 Testing NetworkProvider (with initialization checks)...');
        if (mounted) {
          final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
          final entries = networkProvider.getWhitelistEntries();
          developer.log('🧪 NETWORKPROVIDER TEST Result: ${entries.length} entries');
        }
        return;
      }
      
      // Direct Firestore test
      developer.log('🧪 DIRECT FIRESTORE TEST...');
      final firestore = FirebaseFirestore.instance;
      developer.log('🧪 Project ID: ${firestore.app.options.projectId}');
      
      // Test the CORRECT collection name: access_points
      try {
        final accessPointsTest = await firestore.collection('access_points').get();
        developer.log('🧪 DIRECT TEST - access_points collection: ${accessPointsTest.docs.length} docs (expected 17)');
        
        if (accessPointsTest.docs.isNotEmpty) {
          final firstDoc = accessPointsTest.docs.first;
          final data = firstDoc.data();
          developer.log('🧪 First doc ID: ${firstDoc.id}');
          developer.log('🧪 First doc keys: ${data.keys.toList()}');
          developer.log('🧪 SSID field: ${data['ssid'] ?? data['networkName'] ?? data['name'] ?? 'NOT FOUND'}');
          developer.log('🧪 Latitude: ${data['latitude'] ?? data['lat'] ?? 'NOT FOUND'}');
          developer.log('🧪 Longitude: ${data['longitude'] ?? data['lng'] ?? data['lon'] ?? 'NOT FOUND'}');
          developer.log('🧪 IsActive: ${data['isActive'] ?? data['active'] ?? 'NOT FOUND'}');
        }
      } catch (e) {
        developer.log('🧪 access_points collection error: $e');
      }
      
      // Now test the NetworkProvider
      if (mounted) {
        final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
        final entries = networkProvider.getWhitelistEntries();
        developer.log('🧪 NETWORKPROVIDER TEST RESULT: Got ${entries.length} whitelist entries (expected 17)');
      
        if (entries.length != 17) {
          developer.log('🧪 ❌ MISMATCH: Expected 17, got ${entries.length}');
        } else {
          developer.log('🧪 ✅ SUCCESS: Got expected 17 entries');
        }
        
        // Debug: Log first few entries
        for (int i = 0; i < entries.length && i < 5; i++) {
          final entry = entries[i];
          developer.log('🧪 Entry ${i + 1}: ${entry.ssid} at (${entry.latitude}, ${entry.longitude})');
        }
      }
      
      // Also test the visibility state
      if (mounted) {
        final settingsProvider = Provider.of<SettingsProvider>(context, listen: false);
        developer.log('🧪 Visibility flag: ${settingsProvider.showVerifiedNetworks}');
      }
      developer.log('🧪 Current whitelist count in widget: ${_whitelistedNetworks.length}');
      
    } catch (e) {
      developer.log('🧪 TEST ERROR: $e');
      developer.log('🧪 Error type: ${e.runtimeType}');
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Required for AutomaticKeepAliveClientMixin
    
    try {
      final screenSize = MediaQuery.of(context).size;
      final isSmallScreen = screenSize.width < 600;
      final expandedHeight = screenSize.height * 0.7; // 70% of screen height
      
      return AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        height: _isMapExpanded 
            ? expandedHeight // 70% of screen height when expanded
            : (isSmallScreen ? 280 : 320), // Normal height
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          child: Stack(
            children: [
              _buildMap(),
              
              // Loading overlay
              if (!_isMapReady)
                _buildLoadingOverlay(),
              
              // Map controls (only show when map is ready)
              if (_isMapReady)
                _buildMapControls(),
              
              // Unified map legend
              if (_isMapReady)
                _buildUnifiedMapLegend(),
              
              // Map expansion is controlled only by the expand button
            ],
          ),
        ),
      );
    } catch (e) {
      developer.log('Error building map widget: $e');
      // Return a safe fallback widget
      return Container(
        height: 280,
        decoration: BoxDecoration(
          color: Colors.grey[100],
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: Colors.grey[400]),
              const SizedBox(height: 16),
              Text(
                'Map temporarily unavailable',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isMapExpanded = false;
                    _isLegendExpanded = false;
                  });
                },
                child: const Text('Reset'),
              ),
            ],
          ),
        ),
      );
    }
  }

  Widget _buildLoadingOverlay() {
    return Positioned.fill(
      child: Container(
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(
                color: AppColors.primary,
                strokeWidth: 3,
              ),
              const SizedBox(height: 16),
              Text(
                'Loading map...',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


  Widget _buildMap() {
    return Consumer<NetworkProvider>(
      builder: (context, networkProvider, child) {
        final networks = networkProvider.networks;
        
        // Ensure map controller is ready before building FlutterMap
        if (!_isMapReady) {
          return const Center(
            child: CircularProgressIndicator(),
          );
        }
        
        return FlutterMap(
          key: const ValueKey('network_map'),
          mapController: _mapController,
          options: _mapOptions!,
          children: [
            // Base map tiles
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.dict.disconx',
              maxZoom: 18,
              // Performance optimizations
              keepBuffer: 2,
              panBuffer: 1,
              // Error handling
              errorTileCallback: (tile, error, stackTrace) {
                developer.log('Map tile error: $error');
              },
            ),
            
            // Province boundaries (simplified)
            PolygonLayer(
              polygons: _buildProvincePolygons(),
            ),
            
            // Access point markers with performance optimization
            MarkerLayer(
              markers: _buildAccessPointMarkers(networks),
            ),
            
            // Whitelisted network markers - Using SettingsProvider with forced rebuild
            Consumer<SettingsProvider>(
              builder: (context, settings, child) {
                developer.log('🔍 MAP BUILD - WHITELIST MARKER CHECK (FIXED):');
                developer.log('  - Show flag: ${settings.showVerifiedNetworks}');
                developer.log('  - Count: ${_whitelistedNetworks.length}');
                developer.log('  - Map ready: $_isMapReady');
                developer.log('  - Will show markers: ${settings.showVerifiedNetworks && _whitelistedNetworks.isNotEmpty}');
                
                // CRITICAL FIX: Always return a MarkerLayer to force consistent rebuilds
                final shouldShowMarkers = settings.showVerifiedNetworks && _whitelistedNetworks.isNotEmpty;
                
                if (shouldShowMarkers) {
                  developer.log('✅ BUILDING WHITELIST MARKERS');
                  return MarkerLayer(
                    key: ValueKey('whitelist_markers_${_whitelistedNetworks.length}_${settings.showVerifiedNetworks}'),
                    markers: _buildWhitelistMarkers(),
                  );
                } else {
                  developer.log('❌ HIDING WHITELIST MARKERS');
                  // Return empty MarkerLayer instead of SizedBox to maintain layer consistency
                  return MarkerLayer(
                    key: ValueKey('whitelist_markers_empty_${settings.showVerifiedNetworks}'),
                    markers: const [],
                  );
                }
              },
            ),
            
            // Current location marker
            if (_currentLocation != null)
              MarkerLayer(
                markers: [_buildCurrentLocationMarker()],
              ),
            
            // City labels
            MarkerLayer(
              markers: _buildCityLabels(),
            ),
          ],
        );
      },
    );
  }

  /// Build dropdown legend widget for network pin explanations
  Widget _buildUnifiedMapLegend() {
    return Positioned(
      top: 16,    // Position at top left corner
      left: 16,   // Left side of map
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (mounted) {
              setState(() {
                _isLegendExpanded = !_isLegendExpanded;
              });
            }
          },
          borderRadius: const BorderRadius.all(Radius.circular(12)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.95),
            borderRadius: const BorderRadius.all(Radius.circular(12)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Always visible header
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.map_outlined, size: 18, color: AppColors.primary),
                  const SizedBox(width: 6),
                  const Text(
                    'Network Pins',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 300),
                    turns: _isLegendExpanded ? 0.5 : 0.0,
                    child: const Icon(
                      Icons.expand_more,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              // Expandable content
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 300),
                crossFadeState: _isLegendExpanded 
                    ? CrossFadeState.showSecond 
                    : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 10),
                    _buildUnifiedLegendItem(Colors.green, 'Safe Networks', Icons.shield_outlined),
                    _buildUnifiedLegendItem(Colors.red, 'Suspicious/Threats', Icons.warning_outlined),
                    _buildUnifiedLegendItem(Colors.orange, 'Unknown Status', Icons.help_outline),
                    _buildUnifiedLegendItem(Colors.blue, 'Your Connection', Icons.wifi),
                    _buildUnifiedLegendItem(
                      Colors.green[600]!, 
                      'Verified Networks (${_whitelistedNetworks.length})', 
                      Icons.verified,
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: AppColors.primary, width: 2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Text(
                          'Strong Signal',
                          style: TextStyle(
                            fontSize: 11,
                            color: Colors.black87,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ),
      ),
    );
  }


  /// Build unified legend item with better styling
  Widget _buildUnifiedLegendItem(Color color, String label, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 2),
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 10,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Polygon> _buildProvincePolygons() {
    final provinceColors = GeocodingService.getProvinceColors();
    final polygons = <Polygon>[];

    // Simplified province boundaries (in real implementation, use proper GeoJSON)
    final provinceBounds = {
      'Cavite': [
        const LatLng(14.6, 120.7),
        const LatLng(14.6, 121.2),
        const LatLng(14.0, 121.2),
        const LatLng(14.0, 120.7),
      ],
      'Laguna': [
        const LatLng(14.6, 121.0),
        const LatLng(14.6, 121.7),
        const LatLng(14.0, 121.7),
        const LatLng(14.0, 121.0),
      ],
      'Batangas': [
        const LatLng(14.2, 120.6),
        const LatLng(14.2, 121.6),
        const LatLng(13.4, 121.6),
        const LatLng(13.4, 120.6),
      ],
      'Rizal': [
        const LatLng(14.9, 121.0),
        const LatLng(14.9, 121.4),
        const LatLng(14.4, 121.4),
        const LatLng(14.4, 121.0),
      ],
      'Quezon': [
        const LatLng(14.3, 121.2),
        const LatLng(14.3, 122.2),
        const LatLng(13.5, 122.2),
        const LatLng(13.5, 121.2),
      ],
    };

    for (final entry in provinceBounds.entries) {
      final province = entry.key;
      final bounds = entry.value;
      final color = Color(provinceColors[province] ?? 0xFF9E9E9E);

      if (_selectedProvince == 'All' || _selectedProvince == province) {
        polygons.add(
          Polygon(
            points: bounds,
            color: color.withValues(alpha: 0.1),
            borderColor: color.withValues(alpha: 0.3),
            borderStrokeWidth: 1.0,
          ),
        );
      }
    }

    return polygons;
  }

  List<Marker> _buildAccessPointMarkers(List<NetworkModel> networks) {
    final markers = <Marker>[];
    
    // Performance optimization: limit markers based on zoom level
    final maxMarkers = networks.length > 100 ? 50 : networks.length;
    
    // Group networks by approximate location to prevent overlapping
    final locationGroups = <String, List<NetworkModel>>{};
    
    for (final network in networks) {
      if (network.latitude != null && network.longitude != null) {
        // Filter by province if selected
        if (_selectedProvince != 'All') {
          final cityInfo = _geocodingService.getCityInfo(network.cityName ?? '');
          if (cityInfo?['province'] != _selectedProvince) continue;
        }
        
        // Create location key with reduced precision to group nearby networks
        final latRounded = (network.latitude! * 1000).round() / 1000;
        final lngRounded = (network.longitude! * 1000).round() / 1000;
        final locationKey = '$latRounded,$lngRounded';
        
        locationGroups.putIfAbsent(locationKey, () => []).add(network);
      }
    }
    
    int markersAdded = 0;
    
    for (final entry in locationGroups.entries) {
      if (markersAdded >= maxMarkers) break;
      
      final networksAtLocation = entry.value;
      
      // Sort networks by priority (connected > suspicious > others)
      networksAtLocation.sort((a, b) {
        if (a.isConnected && !b.isConnected) return -1;
        if (!a.isConnected && b.isConnected) return 1;
        if (a.status == NetworkStatus.suspicious && b.status != NetworkStatus.suspicious) return -1;
        if (a.status != NetworkStatus.suspicious && b.status == NetworkStatus.suspicious) return 1;
        return b.signalStrength.compareTo(a.signalStrength);
      });
      
      if (networksAtLocation.length == 1) {
        // Single network - place normally
        final network = networksAtLocation.first;
        final position = LatLng(network.latitude!, network.longitude!);
        
        markers.add(_createSingleMarker(network, position));
        markersAdded++;
      } else {
        // Multiple networks - create cluster or offset markers
        final baseNetwork = networksAtLocation.first;
        final basePosition = LatLng(baseNetwork.latitude!, baseNetwork.longitude!);
        
        if (networksAtLocation.length <= 4) {
          // Small group - offset individual markers in a pattern
          for (int i = 0; i < networksAtLocation.length && markersAdded < maxMarkers; i++) {
            final network = networksAtLocation[i];
            final offsetPosition = _getOffsetPosition(basePosition, i, networksAtLocation.length);
            
            markers.add(_createSingleMarker(network, offsetPosition));
            markersAdded++;
          }
        } else {
          // Large group - create cluster marker
          markers.add(_createClusterMarker(networksAtLocation, basePosition));
          markersAdded++;
        }
      }
    }

    return markers;
  }
  
  /// Create offset position for markers in small groups
  LatLng _getOffsetPosition(LatLng basePosition, int index, int total) {
    if (index == 0) return basePosition; // First marker stays at original position
    
    // Create circular pattern around base position
    const double offsetDistance = 0.0008; // Approximately 80 meters
    final double angle = (2 * 3.14159 * index) / total;
    
    final double latOffset = offsetDistance * cos(angle);
    final double lngOffset = offsetDistance * sin(angle);
    
    return LatLng(
      basePosition.latitude + latOffset,
      basePosition.longitude + lngOffset,
    );
  }
  
  /// Create a single network marker
  Marker _createSingleMarker(NetworkModel network, LatLng position) {
    return Marker(
      point: position,
      width: _getMarkerSize(network),
      height: _getMarkerSize(network),
      child: GestureDetector(
        onTap: () => _showAccessPointDetails(network),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween(begin: 0.8, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Signal strength ring (if network has strong signal)
                  if (network.signalStrength > -50)
                    Container(
                      width: _getMarkerSize(network) + 8,
                      height: _getMarkerSize(network) + 8,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _getAccessPointColor(network).withValues(alpha: 0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  // Main marker
                  Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _getAccessPointColor(network),
                      border: Border.all(
                        color: Colors.white, 
                        width: network.isConnected ? 3 : 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _getAccessPointColor(network).withValues(alpha: 0.3),
                          blurRadius: network.isConnected ? 8 : 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        Center(
                          child: Icon(
                            _getAccessPointIcon(network),
                            color: Colors.white,
                            size: 16,
                          ),
                        ),
                        // Connection indicator
                        if (network.isConnected)
                          Positioned(
                            right: -1,
                            top: -1,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: Colors.green,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white, width: 1),
                              ),
                              child: const Icon(
                                Icons.person,
                                color: Colors.white,
                                size: 8,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  /// Create a cluster marker for multiple networks at same location
  Marker _createClusterMarker(List<NetworkModel> networks, LatLng position) {
    final networkCount = networks.length;
    final hasConnected = networks.any((n) => n.isConnected);
    final hasSuspicious = networks.any((n) => n.status == NetworkStatus.suspicious);
    
    // Determine cluster color based on network types
    Color clusterColor;
    if (hasConnected) {
      clusterColor = Colors.blue;
    } else if (hasSuspicious) {
      clusterColor = Colors.red;
    } else {
      clusterColor = AppColors.primary;
    }
    
    return Marker(
      point: position,
      width: 50,
      height: 50,
      child: GestureDetector(
        onTap: () => _showClusterDetails(networks, position),
        child: TweenAnimationBuilder<double>(
          duration: const Duration(milliseconds: 200),
          tween: Tween(begin: 0.8, end: 1.0),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Cluster background
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: clusterColor,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: clusterColor.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                  // Network count
                  Text(
                    networkCount.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  // Connected indicator
                  if (hasConnected)
                    Positioned(
                      right: 2,
                      top: 2,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1),
                        ),
                        child: const Icon(
                          Icons.person,
                          color: Colors.white,
                          size: 10,
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
  
  /// Show cluster details when cluster marker is tapped
  void _showClusterDetails(List<NetworkModel> networks, LatLng position) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ClusterDetailsSheet(
        networks: networks,
        position: position,
        onNetworkSelected: (network) {
          Navigator.pop(context);
          _showAccessPointDetails(network);
        },
      ),
    );
  }

  List<Marker> _buildCityLabels() {
    final markers = <Marker>[];
    final cities = _geocodingService.getAllCities();

    for (final city in cities) {
      final coordinates = _geocodingService.getRandomCityCoordinates(city);
      if (coordinates != null) {
        final cityInfo = _geocodingService.getCityInfo(city);
        
        // Filter by province if selected
        if (_selectedProvince != 'All' && cityInfo?['province'] != _selectedProvince) {
          continue;
        }

        markers.add(
          Marker(
            point: coordinates,
            width: 80,
            height: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: const BorderRadius.all(Radius.circular(8)),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              child: Text(
                city,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        );
      }
    }

    return markers;
  }

  /// Get marker size based on network properties
  double _getMarkerSize(NetworkModel network) {
    // Base size
    double size = 32.0;
    
    // Larger for connected networks
    if (network.isConnected) {
      size += 8.0;
    }
    
    // Larger for suspicious networks (make them more visible)
    if (network.status == NetworkStatus.suspicious) {
      size += 4.0;
    }
    
    // Adjust based on signal strength
    if (network.signalStrength > -50) {
      size += 4.0; // Very strong signal
    } else if (network.signalStrength > -70) {
      size += 2.0; // Good signal
    }
    
    return size;
  }

  Marker _buildCurrentLocationMarker() {
    return Marker(
      point: _currentLocation!,
      width: 40,
      height: 40,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: const Icon(
          Icons.person_pin,
          color: Colors.white,
          size: 20,
        ),
      ),
    );
  }

  /// Build markers for whitelisted networks
  List<Marker> _buildWhitelistMarkers() {
    developer.log('🗺️ Building whitelist markers...');
    developer.log('📊 Total whitelist entries: ${_whitelistedNetworks.length}');
    
    final markers = <Marker>[];
    
    for (final whitelistEntry in _whitelistedNetworks) {
      developer.log('🔍 Processing entry: ${whitelistEntry.ssid} - Valid location: ${whitelistEntry.hasValidLocation}');
      if (!whitelistEntry.hasValidLocation) {
        developer.log('⚠️ Skipping ${whitelistEntry.ssid} - invalid location');
        continue;
      }
      
      final position = LatLng(whitelistEntry.latitude, whitelistEntry.longitude);
      
      markers.add(
        Marker(
          point: position,
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => _showWhitelistDetails(whitelistEntry),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.green[600],
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.verified,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ),
      );
      developer.log('✅ Created marker for ${whitelistEntry.ssid} at (${whitelistEntry.latitude}, ${whitelistEntry.longitude})');
    }
    
    developer.log('🎯 Built ${markers.length} whitelist markers total');
    return markers;
  }

  /// Show details for a whitelisted network
  void _showWhitelistDetails(WhitelistEntry entry) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.verified,
                    color: Colors.green[600],
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry.ssid,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Government Verified Network',
                        style: TextStyle(
                          color: Colors.green[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 20),
            
            _buildDetailRow(Icons.location_on, 'Location', 
                entry.address ?? '${entry.city}, ${entry.province}'),
            if (entry.venue != null && entry.venue!.isNotEmpty)
              _buildDetailRow(Icons.business, 'Venue', entry.venue!),
            _buildDetailRow(Icons.calendar_today, 'Verified Date', 
                '${entry.verifiedAt.day}/${entry.verifiedAt.month}/${entry.verifiedAt.year}'),
            
            if (entry.notes != null && entry.notes!.isNotEmpty)
              _buildDetailRow(Icons.note, 'Notes', entry.notes!),
            
            const SizedBox(height: 20),
            
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.security, color: Colors.green[600]),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'This network has been verified as safe by DICT Philippines.',
                      style: TextStyle(
                        color: Colors.green[800],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label:',
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: Colors.grey[700],
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMapControls() {
    return Stack(
      children: [
        // Top-right controls (Province filter + Fullscreen)
        Positioned(
          top: 16,
          right: 16,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Province filter
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: const BorderRadius.all(Radius.circular(12)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: DropdownButton<String>(
                  value: _selectedProvince,
                  underline: const SizedBox(),
                  icon: const Icon(Icons.keyboard_arrow_down, size: 16),
                  items: ['All', ..._geocodingService.getProvinces()]
                      .map((province) => DropdownMenuItem(
                            value: province,
                            child: Text(
                              province,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ))
                      .toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value ?? 'All';
                    });
                  },
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Whitelist toggle - Using SettingsProvider
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Tooltip(
                      message: settings.showVerifiedNetworks 
                          ? 'Hide verified networks (${_whitelistedNetworks.length})' 
                          : 'Show verified networks (${_whitelistedNetworks.length})',
                      child: FloatingActionButton.small(
                        heroTag: "whitelist_toggle_button",
                        onPressed: _toggleWhitelistVisibility,
                        backgroundColor: settings.showVerifiedNetworks ? Colors.green[50] : Colors.white,
                        elevation: 0,
                        child: Icon(
                          settings.showVerifiedNetworks ? Icons.verified : Icons.verified_outlined,
                          color: settings.showVerifiedNetworks ? Colors.green[600] : Colors.grey[600],
                          size: 20,
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              const SizedBox(height: 12),
              
              // Fullscreen toggle
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Tooltip(
                  message: _isMapExpanded ? 'Collapse map' : 'Expand map',
                  child: FloatingActionButton.small(
                    heroTag: "expand_button",
                    onPressed: _toggleMapExpansion,
                    backgroundColor: Colors.white,
                    elevation: 0,
                    child: Icon(
                      _isMapExpanded ? Icons.unfold_less : Icons.unfold_more,
                      color: AppColors.primary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        // Bottom-right controls (Location button)
        Positioned(
          bottom: 16,
          right: 16,
          child: Consumer2<SettingsProvider, MapStateProvider>(
            builder: (context, settings, mapState, child) {
              final isLocationEnabled = settings.locationEnabled;
              final hasPermission = settings.locationPermissionStatus == PermissionStatus.granted;
              final hasCachedLocation = mapState.hasValidCachedLocation;
              
              // Determine button appearance and behavior
              Color buttonColor;
              IconData iconData;
              String tooltip;
              
              if (isLocationEnabled && hasPermission) {
                buttonColor = AppColors.primary;
                iconData = Icons.my_location;
                tooltip = 'Center on current location';
              } else if (hasCachedLocation) {
                buttonColor = Colors.orange;
                iconData = Icons.history;
                tooltip = 'Center on last known location';
              } else {
                buttonColor = Colors.grey;
                iconData = Icons.location_disabled;
                tooltip = 'Location not available - tap to enable in Settings';
              }
              
              return Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Tooltip(
                  message: tooltip,
                  child: FloatingActionButton.small(
                    heroTag: "location_button",
                    backgroundColor: buttonColor,
                    elevation: 0,
                    onPressed: _isLocating ? null : _centerOnCurrentLocation,
                    child: _isLocating 
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Icon(
                            iconData,
                            color: Colors.white,
                            size: 20,
                          ),
                  ),
                ),
              );
            },
          ),
        ),
        
        // Left-side controls (Refresh button - opposite to verified network toggle)
        Positioned(
          top: 80, // Position below the legend
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Tooltip(
              message: 'Refresh verified networks (${_whitelistedNetworks.length})',
              child: FloatingActionButton.small(
                heroTag: "refresh_whitelist_button",
                onPressed: _refreshWhitelistData,
                backgroundColor: Colors.blue[50],
                elevation: 0,
                child: Icon(
                  Icons.refresh,
                  color: Colors.blue[600],
                  size: 20,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }



  Color _getAccessPointColor(NetworkModel network) {
    switch (network.status) {
      case NetworkStatus.verified:
        return Colors.green;
      case NetworkStatus.trusted:
        return Colors.blue;
      case NetworkStatus.suspicious:
        return Colors.orange;
      case NetworkStatus.blocked:
        return Colors.red;
      case NetworkStatus.flagged:
        return Colors.purple;
      case NetworkStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getAccessPointIcon(NetworkModel network) {
    switch (network.status) {
      case NetworkStatus.verified:
        return Icons.verified;
      case NetworkStatus.trusted:
        return Icons.shield;
      case NetworkStatus.suspicious:
        return Icons.warning;
      case NetworkStatus.blocked:
        return Icons.block;
      case NetworkStatus.flagged:
        return Icons.flag;
      case NetworkStatus.unknown:
        return Icons.wifi;
    }
  }

  /// Get initial camera center based on saved state or default
  LatLng _getInitialCenter() {
    try {
      final mapStateProvider = context.read<MapStateProvider>();
      return mapStateProvider.cameraPosition;
    } catch (e) {
      return _geocodingService.getCalabarzonCenter();
    }
  }
  
  /// Get initial zoom level based on saved state or default
  double _getInitialZoom() {
    try {
      final mapStateProvider = context.read<MapStateProvider>();
      return mapStateProvider.zoomLevel;
    } catch (e) {
      return 9.0;
    }
  }
  
  /// Handle map movement and persist camera position
  void _onMapMoved(MapCamera camera, bool hasGesture) {
    // Only persist user-initiated movements (hasGesture = true)
    if (hasGesture && _mapInitialized) {
      try {
        final mapStateProvider = context.read<MapStateProvider>();
        mapStateProvider.updateCameraPosition(camera.center, camera.zoom);
      } catch (e) {
        developer.log('Error saving camera position: $e');
      }
    }
  }

  void _onMapTap(LatLng point) {
    // Close legend if it's expanded when tapping on map
    if (_isLegendExpanded) {
      setState(() {
        _isLegendExpanded = false;
      });
    }
    
    // Map expansion/collapse is now only controlled by the expand button
    // No tap-to-collapse functionality for better user control
    
    // Future: Add new access point at tapped location
  }
  


  /// Manually refresh whitelist data from Firestore
  Future<void> _refreshWhitelistData() async {
    try {
      developer.log('🔄 MANUAL REFRESH: User requested whitelist refresh');
      
      // Show loading feedback
      HapticFeedback.lightImpact();
      
      // Force refresh via NetworkProvider (bypassing cache)
      final networkProvider = Provider.of<NetworkProvider>(context, listen: false);
      
      // CRITICAL FIX: Ensure NetworkProvider Firebase is initialized before refresh
      if (!networkProvider.firebaseEnabled) {
        developer.log('🔧 MANUAL REFRESH: NetworkProvider Firebase not initialized, initializing now...');
        try {
          final prefs = await SharedPreferences.getInstance();
          await networkProvider.initializeFirebase(prefs);
          developer.log('✅ MANUAL REFRESH: NetworkProvider Firebase initialized successfully');
        } catch (e) {
          developer.log('❌ MANUAL REFRESH: NetworkProvider Firebase initialization failed: $e');
        }
      }
      
      await networkProvider.forceRefreshWhitelist();
      final refreshedEntries = networkProvider.getWhitelistEntries();
      
      if (mounted) {
        setState(() {
          _whitelistedNetworks = refreshedEntries;
        });
        
        // Show success feedback
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.refresh, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Refreshed ${refreshedEntries.length} verified networks'),
              ],
            ),
            backgroundColor: Colors.blue[600],
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        developer.log('✅ MANUAL REFRESH: Updated to ${refreshedEntries.length} entries');
      }
    } catch (e) {
      developer.log('❌ MANUAL REFRESH ERROR: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white, size: 16),
                SizedBox(width: 8),
                Text('Failed to refresh - check connection'),
              ],
            ),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  /// Toggle map expansion between normal and expanded size
  void _toggleMapExpansion() {
    setState(() {
      _isMapExpanded = !_isMapExpanded;
    });
    
    // Provide haptic feedback
    HapticFeedback.lightImpact();
    
    // Show a brief feedback message
    final message = _isMapExpanded ? 'Map expanded' : 'Map collapsed';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              _isMapExpanded ? Icons.unfold_more : Icons.unfold_less, 
              color: Colors.white, 
              size: 16,
            ),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: AppColors.primary,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showAccessPointDetails(NetworkModel network) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AccessPointDetailsSheet(
        network: network,
        onAction: (action) => _handleAccessPointAction(network, action),
      ),
    );
  }

  Future<void> _handleAccessPointAction(NetworkModel network, AccessPointAction action) async {
    try {
      switch (action) {
        case AccessPointAction.block:
          await _accessPointService.blockAccessPoint(network);
          break;
        case AccessPointAction.trust:
          await _accessPointService.trustAccessPoint(network);
          break;
        case AccessPointAction.flag:
          await _accessPointService.flagAccessPoint(network);
          break;
        case AccessPointAction.unblock:
          await _accessPointService.unblockAccessPoint(network);
          break;
        case AccessPointAction.untrust:
          await _accessPointService.untrustAccessPoint(network);
          break;
        case AccessPointAction.unflag:
          await _accessPointService.unflagAccessPoint(network);
          break;
      }

      // Refresh the network provider to update the UI
      if (mounted) {
        context.read<NetworkProvider>().refreshNetworks();
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Access point ${action.name}ed successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      // Show error message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to ${action.name} access point: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }


  Future<void> _centerOnCurrentLocation() async {
    if (_isLocating) return;

    setState(() {
      _isLocating = true;
    });

    try {
      final settingsProvider = context.read<SettingsProvider>();
      final mapStateProvider = context.read<MapStateProvider>();
      final networkProvider = context.read<NetworkProvider>();
      
      // Check location settings and permissions
      final isLocationEnabled = settingsProvider.locationEnabled;
      final hasPermission = settingsProvider.locationPermissionStatus == PermissionStatus.granted;
      
      // Determine centering strategy based on settings and cache
      final fallbackLocation = mapStateProvider.getLocationForCentering(isLocationEnabled, hasPermission);
      
      if (isLocationEnabled && hasPermission) {
        // Fetch live location and nearby networks
        await _fetchAndCenterLiveLocation(mapStateProvider);
        // Trigger network scan to show nearby networks on map
        await _refreshNearbyNetworks(networkProvider);
      } else if (fallbackLocation != null) {
        // Use cached location
        await _centerOnCachedLocation(fallbackLocation, mapStateProvider);
        // Show cached networks if available
        await _refreshNearbyNetworks(networkProvider);
      } else {
        // No location available - show appropriate message
        _showLocationNotAvailableDialog();
      }
    } catch (e) {
      developer.log('Location centering failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
            behavior: SnackBarBehavior.floating,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: _centerOnCurrentLocation,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLocating = false;
        });
      }
    }
  }

  /// Refresh nearby networks and show them on the map
  Future<void> _refreshNearbyNetworks(NetworkProvider networkProvider) async {
    try {
      // Trigger network scan to get fresh data
      await networkProvider.startNetworkScan(forceRescan: true, isManualScan: false);
      
      // Show feedback that networks are being overlaid
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.wifi_find, color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Showing ${networkProvider.networks.length} nearby networks'),
              ],
            ),
            backgroundColor: AppColors.primary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      developer.log('Failed to refresh nearby networks: $e');
    }
  }
  
  /// Fetch live location and center map
  Future<void> _fetchAndCenterLiveLocation(MapStateProvider mapStateProvider) async {
    // Double-check location services are enabled
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showLocationSettingsDialog();
      return;
    }

    // Get current position with timeout and error handling
    Position? position;
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 15),
        ),
      ).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw Exception('Location request timed out'),
      );
    } catch (e) {
      developer.log('Location fetch error: $e');
      throw Exception('Unable to get your current location. Please try again.');
    }

    final currentLatLng = LatLng(position.latitude, position.longitude);
    
    // Validate coordinates are reasonable (within CALABARZON region or nearby)
    if (!_isLocationValid(currentLatLng)) {
      throw Exception('Location seems inaccurate. Please check your GPS signal.');
    }
    
    if (!mounted) return;

    // Update state and cache the location
    setState(() {
      _currentLocation = currentLatLng;
    });
    
    await mapStateProvider.updateLastKnownLocation(currentLatLng);

    // Animate to current location with enhanced zoom for better UX
    await _safeMapMove(currentLatLng, 16.0); // Increased zoom level for better location focus

    if (mounted) {
      // Get location name asynchronously to avoid blocking UI
      String locationName = 'your current location';
      try {
        final name = _geocodingService.getCityName(
          position.latitude, 
          position.longitude,
        );
        locationName = name ?? locationName;
      } catch (e) {
        developer.log('Geocoding error: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.location_on, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Centered on $locationName')),
            ],
          ),
          backgroundColor: AppColors.primary,
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  /// Center map on cached location
  Future<void> _centerOnCachedLocation(LatLng cachedLocation, MapStateProvider mapStateProvider) async {
    if (!mounted) return;
    
    setState(() {
      _currentLocation = cachedLocation;
    });

    // Animate to cached location with enhanced zoom
    await _safeMapMove(cachedLocation, 16.0); // Consistent zoom level for location centering

    if (mounted) {
      final cacheAge = mapStateProvider.getLocationCacheAgeMinutes();
      final ageText = cacheAge != null ? ' (${cacheAge}m ago)' : '';
      
      String locationName = 'last known location';
      try {
        final name = _geocodingService.getCityName(
          cachedLocation.latitude, 
          cachedLocation.longitude,
        );
        locationName = name ?? locationName;
      } catch (e) {
        developer.log('Geocoding error: $e');
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.history, color: Colors.white, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text('Centered on $locationName$ageText')),
            ],
          ),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  bool _isLocationValid(LatLng location) {
    // Check if location is within reasonable bounds (Philippines + buffer)
    const double minLat = 4.0;   // Southern Philippines
    const double maxLat = 21.0;  // Northern Philippines
    const double minLng = 116.0; // Western Philippines
    const double maxLng = 127.0; // Eastern Philippines
    
    return location.latitude >= minLat && 
           location.latitude <= maxLat &&
           location.longitude >= minLng && 
           location.longitude <= maxLng;
  }


  void _showLocationNotAvailableDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_disabled, color: Colors.orange),
            SizedBox(width: 8),
            Text('Location Not Available'),
          ],
        ),
        content: const Text(
          'Location access is disabled. Enable it in Settings to update your position, or we can use your last known location if available.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // CRITICAL FIX: Open settings drawer instead of navigating to non-existent tab
              final scaffoldKey = Scaffold.of(context);
              scaffoldKey.openEndDrawer();
            },
            child: const Text('Go to Settings'),
          ),
        ],
      ),
    );
  }

  void _showLocationSettingsDialog() {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.location_off, color: Colors.orange),
            SizedBox(width: 8),
            Text('Location Services Disabled'),
          ],
        ),
        content: const Text(
          'Location services are turned off. Please enable them in your device settings to use this feature.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Geolocator.openLocationSettings();
            },
            child: const Text('Open Settings'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    
    // Removed provider listeners since auto-updates are disabled
    // Manual refresh only
    
    // Properly dispose of the MapController if initialized
    try {
      _mapController.dispose();
    } catch (e) {
      developer.log('Warning: MapController dispose error: $e');
    }
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _whitelistedNetworks.isEmpty) {
      developer.log('🔄 App resumed and whitelist empty - attempting reload...');
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _loadWhitelistedNetworks();
        }
      });
    }
  }
}

// Access Point Details Bottom Sheet
class AccessPointDetailsSheet extends StatelessWidget {
  final NetworkModel network;
  final Function(AccessPointAction) onAction;

  const AccessPointDetailsSheet({
    super.key,
    required this.network,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  _getStatusIcon(network.status),
                  color: _getStatusColor(network.status),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        network.name,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        network.statusDisplayName,
                        style: TextStyle(
                          color: _getStatusColor(network.status),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),

            const SizedBox(height: 24),

            // Details
            _buildDetailRow('Location', network.displayLocation),
            _buildDetailRow('MAC Address', network.macAddress),
            _buildDetailRow('Security', network.securityTypeString),
            _buildDetailRow('Signal Strength', '${network.signalStrength}% (${network.signalStrengthString})'),
            _buildDetailRow('Last Seen', _formatDateTime(network.lastSeen)),
            
            if (network.address != null)
              _buildDetailRow('Address', network.address!),
            
            if (network.isUserManaged && network.lastActionDate != null)
              _buildDetailRow('Last Action', _formatDateTime(network.lastActionDate!)),

            const SizedBox(height: 24),

            // Action buttons
            const Text(
              'Actions',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _buildActionButtons(),
            ),

            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildActionButtons() {
    final buttons = <Widget>[];

    switch (network.status) {
      case NetworkStatus.blocked:
        buttons.add(_buildActionButton(
          'Unblock',
          Icons.check_circle,
          Colors.green,
          () => onAction(AccessPointAction.unblock),
        ));
        break;
        
      case NetworkStatus.trusted:
        buttons.add(_buildActionButton(
          'Untrust',
          Icons.remove_circle,
          Colors.orange,
          () => onAction(AccessPointAction.untrust),
        ));
        buttons.add(_buildActionButton(
          'Block',
          Icons.block,
          Colors.red,
          () => onAction(AccessPointAction.block),
        ));
        break;
        
      case NetworkStatus.flagged:
        buttons.add(_buildActionButton(
          'Unflag',
          Icons.outlined_flag,
          Colors.grey,
          () => onAction(AccessPointAction.unflag),
        ));
        buttons.add(_buildActionButton(
          'Block',
          Icons.block,
          Colors.red,
          () => onAction(AccessPointAction.block),
        ));
        break;
        
      default:
        buttons.add(_buildActionButton(
          'Trust',
          Icons.shield,
          Colors.blue,
          () => onAction(AccessPointAction.trust),
        ));
        buttons.add(_buildActionButton(
          'Block',
          Icons.block,
          Colors.red,
          () => onAction(AccessPointAction.block),
        ));
        buttons.add(_buildActionButton(
          'Flag',
          Icons.flag,
          Colors.purple,
          () => onAction(AccessPointAction.flag),
        ));
        break;
    }

    return buttons;
  }

  Widget _buildActionButton(String label, IconData icon, Color color, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      ),
    );
  }

  Color _getStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return Colors.green;
      case NetworkStatus.trusted:
        return Colors.blue;
      case NetworkStatus.suspicious:
        return Colors.orange;
      case NetworkStatus.blocked:
        return Colors.red;
      case NetworkStatus.flagged:
        return Colors.purple;
      case NetworkStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return Icons.verified;
      case NetworkStatus.trusted:
        return Icons.shield;
      case NetworkStatus.suspicious:
        return Icons.warning;
      case NetworkStatus.blocked:
        return Icons.block;
      case NetworkStatus.flagged:
        return Icons.flag;
      case NetworkStatus.unknown:
        return Icons.wifi;
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}

// Cluster Details Bottom Sheet
class ClusterDetailsSheet extends StatelessWidget {
  final List<NetworkModel> networks;
  final LatLng position;
  final Function(NetworkModel) onNetworkSelected;

  const ClusterDetailsSheet({
    super.key,
    required this.networks,
    required this.position,
    required this.onNetworkSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    networks.length.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${networks.length} Networks at this location',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Tap a network to view details',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          
          // Network list
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              itemCount: networks.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final network = networks[index];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _getStatusColor(network.status),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: Icon(
                      _getStatusIcon(network.status),
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  title: Text(
                    network.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.signal_cellular_4_bar,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            network.signalStrengthString,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            Icons.security,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              network.securityTypeString,
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey[600],
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (network.isConnected)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Colors.green,
                            borderRadius: BorderRadius.all(Radius.circular(8)),
                          ),
                          child: const Text(
                            'Connected',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right),
                    ],
                  ),
                  onTap: () => onNetworkSelected(network),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return Colors.green;
      case NetworkStatus.trusted:
        return Colors.blue;
      case NetworkStatus.suspicious:
        return Colors.orange;
      case NetworkStatus.blocked:
        return Colors.red;
      case NetworkStatus.flagged:
        return Colors.purple;
      case NetworkStatus.unknown:
        return Colors.grey;
    }
  }

  IconData _getStatusIcon(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return Icons.verified;
      case NetworkStatus.trusted:
        return Icons.shield;
      case NetworkStatus.suspicious:
        return Icons.warning;
      case NetworkStatus.blocked:
        return Icons.block;
      case NetworkStatus.flagged:
        return Icons.flag;
      case NetworkStatus.unknown:
        return Icons.wifi;
    }
  }
}