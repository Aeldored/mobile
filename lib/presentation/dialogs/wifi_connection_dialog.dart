import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/network_model.dart';
import '../../data/models/security_assessment.dart';

/// Modern Wi-Fi connection dialog that properly handles Android limitations
/// Provides clear user guidance instead of misleading password prompts
class WiFiConnectionDialog extends StatefulWidget {
  final NetworkModel network;

  const WiFiConnectionDialog({
    super.key,
    required this.network,
  });

  @override
  State<WiFiConnectionDialog> createState() => _WiFiConnectionDialogState();

  /// Show the connection dialog with proper system integration
  static Future<bool> show(BuildContext context, NetworkModel network) async {
    if (!context.mounted) {
      developer.log('Context not mounted, cannot show connection dialog');
      return false;
    }

    try {
      final result = await showDialog<bool>(
        context: context,
        barrierDismissible: true,
        builder: (context) => WiFiConnectionDialog(network: network),
      );
      return result ?? false;
    } catch (e) {
      developer.log('Error showing connection dialog: $e');
      return false;
    }
  }
}

class _WiFiConnectionDialogState extends State<WiFiConnectionDialog> {
  bool _isConnecting = false;
  
  // Get Android API level for feature detection
  int get _androidApiLevel {
    // This would normally come from a platform channel
    // For now, assume modern Android (API 33+)
    return 33;
  }

  bool get _isModernAndroid => _androidApiLevel >= 29;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: Row(
        children: [
          Icon(
            _getNetworkIcon(),
            color: _getNetworkColor(),
            size: 24,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              widget.network.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Network status indicator
            _buildNetworkStatusCard(),
            
            const SizedBox(height: 16),
            
            // Security information
            _buildSecurityInfo(),
            
            const SizedBox(height: 16),
            
            // Connection method explanation
            _buildConnectionMethodInfo(),
            
            const SizedBox(height: 16),
            
            // Network details
            _buildNetworkDetails(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isConnecting ? null : () => Navigator.of(context).pop(false),
          style: TextButton.styleFrom(
            foregroundColor: Colors.grey[600],
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isConnecting ? null : _handleConnect,
          style: ElevatedButton.styleFrom(
            backgroundColor: _getActionButtonColor(),
            foregroundColor: Colors.white,
            minimumSize: const Size(120, 40),
          ),
          child: _isConnecting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(_getActionButtonText()),
        ),
      ],
    );
  }

  Widget _buildNetworkStatusCard() {
    Color statusColor;
    IconData statusIcon;
    String statusText;
    String statusDescription;

    switch (widget.network.status) {
      case NetworkStatus.verified:
        statusColor = Colors.green;
        statusIcon = Icons.verified_outlined;
        statusText = 'Verified Network';
        statusDescription = 'This network is verified by DICT and safe to use.';
        break;
      case NetworkStatus.suspicious:
        statusColor = Colors.red;
        statusIcon = Icons.warning_outlined;
        statusText = 'Suspicious Network';
        statusDescription = 'This network may be an evil twin attack. Exercise caution.';
        break;
      case NetworkStatus.blocked:
        statusColor = Colors.red;
        statusIcon = Icons.block_outlined;
        statusText = 'Blocked Network';
        statusDescription = 'This network has been flagged as unsafe and is blocked.';
        break;
      case NetworkStatus.unknown:
      default:
        statusColor = Colors.orange;
        statusIcon = Icons.help_outline;
        statusText = 'Unknown Network';
        statusDescription = 'This network has not been verified by DICT.';
        break;
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 18),
              const SizedBox(width: 8),
              Text(
                statusText,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: statusColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            statusDescription,
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildSecurityInfo() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(_getSecurityIcon(), color: Colors.blue[700], size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Security: ${widget.network.securityTypeString}',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConnectionMethodInfo() {
    if (_isModernAndroid) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings, color: AppColors.primary, size: 16),
                SizedBox(width: 8),
                Text(
                  'System Settings Connection',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            SizedBox(height: 4),
            Text(
              'For security, Android requires connections through system settings. '
              'You\'ll be guided to the Wi-Fi settings to connect manually.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    } else {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.wifi, color: Colors.green[700], size: 16),
                const SizedBox(width: 8),
                const Text(
                  'Direct Connection Available',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'DisConX can attempt to connect directly to this network.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildNetworkDetails() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Network Details',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(Icons.signal_cellular_4_bar, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Text(
              'Signal: ${widget.network.signalStrengthString}',
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
            const SizedBox(width: 16),
            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                widget.network.displayLocation,
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(Icons.router, size: 14, color: Colors.grey[600]),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'MAC: ${widget.network.macAddress}',
                style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _handleConnect() async {
    if (widget.network.status == NetworkStatus.blocked) {
      _showBlockedNetworkWarning();
      return;
    }

    if (widget.network.status == NetworkStatus.suspicious) {
      final shouldContinue = await _showSuspiciousNetworkWarning();
      if (!shouldContinue) return;
    }

    setState(() {
      _isConnecting = true;
    });

    try {
      await _openSystemWiFiSettings();
      // Give user time to connect manually
      await Future.delayed(const Duration(seconds: 2));
      
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      developer.log('Error opening Wi-Fi settings: $e');
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _openSystemWiFiSettings() async {
    try {
      // Use platform channel to open Wi-Fi settings
      const platform = MethodChannel('com.dict.disconx/wifi');
      await platform.invokeMethod('openWifiSettings', {
        'ssid': widget.network.name,
      });
    } catch (e) {
      developer.log('Failed to open Wi-Fi settings via platform channel: $e');
      // Fallback: Could use url_launcher to open settings
      // But that's not as precise as platform-specific implementation
    }
  }

  void _showBlockedNetworkWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.block, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Network Blocked'),
          ],
        ),
        content: const Text(
          'This network has been flagged as unsafe and cannot be connected to. '
          'If you believe this is an error, please contact your network administrator.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showSuspiciousNetworkWarning() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning, color: Colors.red, size: 24),
            SizedBox(width: 8),
            Text('Security Warning'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This network has been flagged as potentially suspicious.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'It may be an "evil twin" attack attempting to steal your data. '
              'Connecting could compromise your personal information.',
            ),
            SizedBox(height: 12),
            Text(
              'DICT recommends avoiding this connection.',
              style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Connect Anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  IconData _getNetworkIcon() {
    switch (widget.network.status) {
      case NetworkStatus.verified:
        return Icons.wifi_protected_setup;
      case NetworkStatus.suspicious:
        return Icons.wifi_off;
      case NetworkStatus.blocked:
        return Icons.wifi_off;
      default:
        return Icons.wifi;
    }
  }

  Color _getNetworkColor() {
    switch (widget.network.status) {
      case NetworkStatus.verified:
        return Colors.green;
      case NetworkStatus.suspicious:
        return Colors.red;
      case NetworkStatus.blocked:
        return Colors.red;
      default:
        return AppColors.primary;
    }
  }

  IconData _getSecurityIcon() {
    switch (widget.network.securityType) {
      case SecurityType.open:
        return Icons.lock_open;
      case SecurityType.wep:
        return Icons.lock_outline;
      case SecurityType.wpa2:
        return Icons.lock;
      case SecurityType.wpa3:
        return Icons.enhanced_encryption;
    }
  }

  Color _getActionButtonColor() {
    if (widget.network.status == NetworkStatus.blocked) {
      return Colors.grey;
    } else if (widget.network.status == NetworkStatus.suspicious) {
      return Colors.red;
    } else {
      return AppColors.primary;
    }
  }

  String _getActionButtonText() {
    if (widget.network.status == NetworkStatus.blocked) {
      return 'Blocked';
    } else if (_isModernAndroid) {
      return 'Open Wi-Fi Settings';
    } else {
      return 'Connect';
    }
  }
}