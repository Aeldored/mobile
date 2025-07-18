import 'package:flutter/material.dart';
import '../../../../data/models/education_content_model.dart';

class SecurityTipCard extends StatelessWidget {
  final SecurityTip tip;

  const SecurityTipCard({
    super.key,
    required this.tip,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => _showTipDetails(context),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tip.backgroundColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  tip.icon,
                  color: tip.backgroundColor.computeLuminance() > 0.5
                      ? Colors.black87
                      : Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                tip.title,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                tip.description,
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTipDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: tip.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                tip.icon,
                color: tip.backgroundColor.computeLuminance() > 0.5
                    ? Colors.black87
                    : Colors.white,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tip.title,
                style: const TextStyle(fontSize: 18),
              ),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tip.description,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _getDetailedDescription(),
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  String _getDetailedDescription() {
    switch (tip.id) {
      case '1':
        return 'A VPN (Virtual Private Network) encrypts your internet connection, '
            'making it much harder for hackers to intercept your data on public Wi-Fi. '
            'Always activate your VPN before connecting to any public network.';
      case '2':
        return 'Before connecting to any network, verify its legitimacy. '
            'Check with venue staff for the official network name and look for '
            'security certificates. Be wary of networks with generic names like '
            '"Free_WiFi" or misspellings of official networks.';
      case '3':
        return 'Use complex passwords with a mix of uppercase and lowercase letters, '
            'numbers, and special characters. Avoid using the same password across '
            'multiple networks and change them regularly. Consider using a password '
            'manager to generate and store secure passwords.';
      case '4':
        return 'Security threats evolve constantly. Stay informed about the latest '
            'Wi-Fi security risks and protection methods. Enable automatic security '
            'updates on your devices and follow cybersecurity news from trusted sources.';
      default:
        return tip.description;
    }
  }
}