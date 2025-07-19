import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../data/models/network_model.dart';
import '../../../../data/services/location_service.dart';
import '../../../../providers/network_provider.dart';

class NetworkMapWidget extends StatefulWidget {
  const NetworkMapWidget({super.key});

  @override
  State<NetworkMapWidget> createState() => _NetworkMapWidgetState();
}

class _NetworkMapWidgetState extends State<NetworkMapWidget> {
  final MapController _mapController = MapController();
  final LocationService _locationService = LocationService();
  LatLng _currentLocation = LatLng(
    AppConstants.defaultLatitude,
    AppConstants.defaultLongitude,
  );
  double _currentZoom = AppConstants.defaultMapZoom;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  void dispose() {
    _locationService.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    final position = await _locationService.getCurrentLocation();
    if (position != null && mounted) {
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });
      _mapController.move(_currentLocation, _currentZoom);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.35,
      child: Stack(
        children: [
          // OpenStreetMap using flutter_map
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentLocation,
              initialZoom: _currentZoom,
              minZoom: AppConstants.minMapZoom,
              maxZoom: AppConstants.maxMapZoom,
              onPositionChanged: (position, hasGesture) {
                if (hasGesture) {
                  setState(() {
                    _currentZoom = position.zoom;
                  });
                }
              },
            ),
            children: [
              // OpenStreetMap Tile Layer (Free!)
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.dict.disconx',
                maxNativeZoom: 19,
                maxZoom: 22,
                errorTileCallback: (tile, error, stackTrace) {
                  // Handle network errors gracefully
                  developer.log('Map tile error: $error');
                },
                fallbackUrl: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              ),
              
              // Network Markers
              Consumer<NetworkProvider>(
                builder: (context, provider, child) {
                  final networks = provider.getNetworksForMap();
                  return MarkerLayer(
                    markers: [
                      // Current location marker
                      Marker(
                        point: _currentLocation,
                        width: 80,
                        height: 80,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.blue.withValues(alpha: 0.2),
                              ),
                              child: Container(
                                margin: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white,
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.2),
                                      blurRadius: 4,
                                    ),
                                  ],
                                ),
                                child: Container(
                                  margin: const EdgeInsets.all(2),
                                  width: 12,
                                  height: 12,
                                  decoration: const BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(10),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 2,
                                  ),
                                ],
                              ),
                              child: const Text(
                                'You',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Network markers
                      ...networks.map((network) => _buildNetworkMarker(network)),
                    ],
                  );
                },
              ),
            ],
          ),
          
          // Map controls
          Positioned(
            top: 16,
            right: 16,
            child: Column(
              children: [
                _buildMapControl(
                  Icons.add,
                  () {
                    final newZoom = (_currentZoom + 1).clamp(
                      AppConstants.minMapZoom,
                      AppConstants.maxMapZoom,
                    );
                    _mapController.move(_currentLocation, newZoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapControl(
                  Icons.remove,
                  () {
                    final newZoom = (_currentZoom - 1).clamp(
                      AppConstants.minMapZoom,
                      AppConstants.maxMapZoom,
                    );
                    _mapController.move(_currentLocation, newZoom);
                  },
                ),
                const SizedBox(height: 8),
                _buildMapControl(
                  Icons.my_location,
                  () {
                    _getCurrentLocation();
                  },
                ),
              ],
            ),
          ),
          
          // Map legend
          Positioned(
            bottom: 16,
            left: 16,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildLegendItem(AppColors.success, 'Verified'),
                  const SizedBox(height: 4),
                  _buildLegendItem(AppColors.warning, 'Unknown'),
                  const SizedBox(height: 4),
                  _buildLegendItem(AppColors.danger, 'Suspicious'),
                ],
              ),
            ),
          ),
          
          // OpenStreetMap Attribution
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text(
                '© OpenStreetMap',
                style: TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Marker _buildNetworkMarker(NetworkModel network) {
    if (network.latitude == null || network.longitude == null) {
      return Marker(
        point: _currentLocation,
        width: 0,
        height: 0,
        child: const SizedBox.shrink(),
      );
    }

    Color markerColor;
    IconData markerIcon;
    
    switch (network.status) {
      case NetworkStatus.verified:
        markerColor = AppColors.success;
        markerIcon = Icons.check_circle;
        break;
      case NetworkStatus.suspicious:
        markerColor = AppColors.danger;
        markerIcon = Icons.warning;
        break;
      case NetworkStatus.unknown:
        markerColor = AppColors.warning;
        markerIcon = Icons.help;
        break;
      case NetworkStatus.blocked:
        markerColor = Colors.red;
        markerIcon = Icons.block;
        break;
      case NetworkStatus.trusted:
        markerColor = Colors.blue;
        markerIcon = Icons.shield;
        break;
      case NetworkStatus.flagged:
        markerColor = Colors.purple;
        markerIcon = Icons.flag;
        break;
    }

    return Marker(
      point: LatLng(network.latitude!, network.longitude!),
      width: 40,
      height: 40,
      child: GestureDetector(
        onTap: () => _showNetworkInfo(context, network),
        child: Container(
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Icon(
            markerIcon,
            color: Colors.white,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildMapControl(IconData icon, VoidCallback onTap) {
    return Material(
      elevation: 2,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          width: 36,
          height: 36,
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 20,
            color: Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(fontSize: 12),
        ),
      ],
    );
  }

  void _showNetworkInfo(BuildContext context, NetworkModel network) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.wifi,
              color: _getStatusColor(network.status),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                network.name,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow('Status', _getStatusString(network.status)),
            if (network.description != null)
              _buildInfoRow('Location', network.description!),
            _buildInfoRow('Security', network.securityTypeString),
            _buildInfoRow('Signal', network.signalStrengthString),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return AppColors.success;
      case NetworkStatus.suspicious:
        return AppColors.danger;
      case NetworkStatus.unknown:
        return AppColors.warning;
      case NetworkStatus.blocked:
        return Colors.red;
      case NetworkStatus.trusted:
        return Colors.blue;
      case NetworkStatus.flagged:
        return Colors.purple;
    }
  }

  String _getStatusString(NetworkStatus status) {
    switch (status) {
      case NetworkStatus.verified:
        return 'Verified';
      case NetworkStatus.suspicious:
        return 'Suspicious';
      case NetworkStatus.unknown:
        return 'Unknown';
      case NetworkStatus.blocked:
        return 'Blocked';
      case NetworkStatus.trusted:
        return 'Trusted';
      case NetworkStatus.flagged:
        return 'Flagged';
    }
  }
}