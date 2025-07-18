import 'package:flutter/material.dart';
import '../../core/constants/ui_constants.dart';

/// Widget to display demo mode banner across the app
class DemoModeBanner extends StatelessWidget {
  final bool isVisible;
  final VoidCallback? onDismiss;
  final String? customMessage;

  const DemoModeBanner({
    super.key,
    this.isVisible = true,
    this.onDismiss,
    this.customMessage,
  });

  @override
  Widget build(BuildContext context) {
    if (!isVisible) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: UIConstants.spaceLG,
        vertical: UIConstants.spaceMD,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.orange[600]!,
            Colors.orange[500]!,
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        boxShadow: UIConstants.shadowSM,
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Icon(
              Icons.science,
              color: Colors.white,
              size: UIConstants.iconSM,
            ),
            const SizedBox(width: UIConstants.spaceSM),
            Expanded(
              child: Text(
                customMessage ?? 
                'Demo Mode - Simulated data for demonstration purposes',
                style: UIConstants.bodySmall.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onDismiss != null) ...[
              const SizedBox(width: UIConstants.spaceSM),
              GestureDetector(
                onTap: onDismiss,
                child: Container(
                  padding: const EdgeInsets.all(UIConstants.spaceXS),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(UIConstants.radiusXS),
                  ),
                  child: Icon(
                    Icons.close,
                    color: Colors.white,
                    size: UIConstants.iconXS,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// A specialized banner for Wi-Fi scanning demo mode with permission status
class WiFiDemoModeBanner extends StatelessWidget {
  final bool wifiScanningEnabled;
  final VoidCallback? onTap;

  const WiFiDemoModeBanner({
    super.key,
    required this.wifiScanningEnabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (wifiScanningEnabled) return const SizedBox.shrink();

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(UIConstants.spaceLG),
        padding: const EdgeInsets.all(UIConstants.spaceLG),
        decoration: BoxDecoration(
          color: Colors.orange[50],
          borderRadius: BorderRadius.circular(UIConstants.radiusLG),
          border: Border.all(
            color: Colors.orange[200]!,
            width: 1,
          ),
          boxShadow: UIConstants.shadowSM,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(UIConstants.spaceSM),
              decoration: BoxDecoration(
                color: Colors.orange[100],
                borderRadius: BorderRadius.circular(UIConstants.radiusRound),
              ),
              child: Icon(
                Icons.warning_amber,
                color: Colors.orange[600],
                size: UIConstants.iconMD,
              ),
            ),
            const SizedBox(width: UIConstants.spaceLG),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Limited Functionality',
                    style: UIConstants.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Colors.orange[800],
                    ),
                  ),
                  const SizedBox(height: UIConstants.spaceXS),
                  Text(
                    'Using simulated data. Grant location and Wi-Fi permissions for full functionality.',
                    style: UIConstants.bodySmall.copyWith(
                      color: Colors.orange[700],
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: UIConstants.spaceSM),
                  Text(
                    'Tap to enable permissions',
                    style: UIConstants.bodySmall.copyWith(
                      color: Colors.orange[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.settings,
              color: Colors.orange[600],
              size: UIConstants.iconMD,
            ),
          ],
        ),
      ),
    );
  }
}