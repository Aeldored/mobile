import 'dart:developer' as developer;
import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../data/models/network_model.dart';

class WiFiPasswordDialog extends StatefulWidget {
  final NetworkModel network;

  const WiFiPasswordDialog({
    super.key,
    required this.network,
  });

  @override
  State<WiFiPasswordDialog> createState() => _WiFiPasswordDialogState();

  /// Static method to show the dialog safely
  static Future<String?> show(BuildContext context, NetworkModel network) async {
    if (!context.mounted) {
      developer.log('Context not mounted, cannot show password dialog');
      return null;
    }

    try {
      final result = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (context) => WiFiPasswordDialog(network: network),
      );
      developer.log('Password dialog result: ${result != null ? "password entered" : "cancelled"}');
      return result;
    } catch (e) {
      developer.log('Error showing password dialog: $e');
      return null;
    }
  }
}

class _WiFiPasswordDialogState extends State<WiFiPasswordDialog> {
  final TextEditingController _passwordController = TextEditingController();
  bool _obscureText = true;
  bool _isConnecting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscureText = !_obscureText;
    });
  }

  void _handleConnect() {
    final password = _passwordController.text.trim();
    
    if (password.isEmpty) {
      setState(() {
        _errorMessage = 'Password cannot be empty';
      });
      return;
    }

    if (password.length < 8 && widget.network.securityType != SecurityType.wep) {
      setState(() {
        _errorMessage = 'Password must be at least 8 characters for WPA/WPA2/WPA3 networks';
      });
      return;
    }

    // Clear any previous error
    setState(() {
      _errorMessage = null;
      _isConnecting = true;
    });

    // Return the password to the caller
    if (mounted) {
      Navigator.of(context).pop(password);
    }
  }

  void _handleCancel() {
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isConnecting,
      child: AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Row(
          children: [
            Icon(
              _getSecurityIcon(),
              color: _getSecurityColor(),
              size: 24,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Connect to ${widget.network.name}',
                style: const TextStyle(fontSize: 18),
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
              // Network security info
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _getSecurityColor().withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _getSecurityColor().withValues(alpha: 0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      _getSecurityIcon(),
                      color: _getSecurityColor(),
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'This network is secured with ${widget.network.securityTypeString}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getSecurityColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Network status indicator
              if (widget.network.status == NetworkStatus.verified) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.verified, color: Colors.green[700], size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'This is a verified DICT network',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ] else if (widget.network.status == NetworkStatus.suspicious) ...[
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning, color: Colors.red[700], size: 16),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Warning: This network may be suspicious',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              
              // Password input field
              TextField(
                controller: _passwordController,
                obscureText: _obscureText,
                enabled: !_isConnecting,
                autofocus: true,
                onSubmitted: (_) => _handleConnect(),
                decoration: InputDecoration(
                  labelText: 'Network Password',
                  hintText: 'Enter the Wi-Fi password',
                  border: const OutlineInputBorder(),
                  errorText: _errorMessage,
                  prefixIcon: Icon(
                    Icons.lock,
                    color: _getSecurityColor(),
                  ),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscureText ? Icons.visibility : Icons.visibility_off,
                    ),
                    onPressed: _isConnecting ? null : _togglePasswordVisibility,
                  ),
                ),
              ),
              
              const SizedBox(height: 12),
              
              // Password requirements hint
              if (widget.network.securityType != SecurityType.wep) ...[
                Text(
                  'Password must be at least 8 characters',
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[600],
                  ),
                ),
              ],
              
              // Network details
              const SizedBox(height: 16),
              Row(
                children: [
                  Icon(
                    Icons.signal_cellular_4_bar,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'Signal: ${widget.network.signalStrengthString}',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.location_on,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      widget.network.displayLocation,
                      style: TextStyle(
                        fontSize: 12,
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
        ),
        actions: [
          TextButton(
            onPressed: _isConnecting ? null : _handleCancel,
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: _isConnecting ? null : _handleConnect,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 36),
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
                : const Text('Connect'),
          ),
        ],
      ),
    );
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

  Color _getSecurityColor() {
    switch (widget.network.securityType) {
      case SecurityType.open:
        return Colors.orange;
      case SecurityType.wep:
        return Colors.red;
      case SecurityType.wpa2:
        return Colors.blue;
      case SecurityType.wpa3:
        return Colors.green;
    }
  }
}