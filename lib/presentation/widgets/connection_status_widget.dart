import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/services/wifi_connection_manager.dart';

class ConnectionStatusWidget extends StatelessWidget {
  final String networkId;
  final WiFiConnectionManager connectionManager;

  const ConnectionStatusWidget({
    super.key,
    required this.networkId,
    required this.connectionManager,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<ConnectionUpdate>(
      stream: connectionManager.connectionUpdates,
      builder: (context, snapshot) {
        final connectionState = connectionManager.getConnectionState(networkId);
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: _getStateColor(connectionState).withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _getStateColor(connectionState).withValues(alpha: 0.3),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (connectionState == WiFiConnectionState.connecting ||
                  connectionState == WiFiConnectionState.disconnecting) ...[
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_getStateColor(connectionState)),
                  ),
                ),
                const SizedBox(width: 6),
              ] else ...[
                Icon(
                  _getStateIcon(connectionState),
                  size: 12,
                  color: _getStateColor(connectionState),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                _getStateText(connectionState),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: _getStateColor(connectionState),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Color _getStateColor(WiFiConnectionState state) {
    switch (state) {
      case WiFiConnectionState.connected:
        return Colors.green;
      case WiFiConnectionState.connecting:
        return AppColors.primary;
      case WiFiConnectionState.disconnecting:
        return Colors.orange;
      case WiFiConnectionState.failed:
        return Colors.red;
      case WiFiConnectionState.disconnected:
        return Colors.grey;
    }
  }

  IconData _getStateIcon(WiFiConnectionState state) {
    switch (state) {
      case WiFiConnectionState.connected:
        return Icons.wifi;
      case WiFiConnectionState.connecting:
        return Icons.wifi_find;
      case WiFiConnectionState.disconnecting:
        return Icons.wifi_off;
      case WiFiConnectionState.failed:
        return Icons.wifi_off;
      case WiFiConnectionState.disconnected:
        return Icons.wifi_off;
    }
  }

  String _getStateText(WiFiConnectionState state) {
    switch (state) {
      case WiFiConnectionState.connected:
        return 'Connected';
      case WiFiConnectionState.connecting:
        return 'Connecting...';
      case WiFiConnectionState.disconnecting:
        return 'Disconnecting...';
      case WiFiConnectionState.failed:
        return 'Failed';
      case WiFiConnectionState.disconnected:
        return 'Disconnected';
    }
  }
}