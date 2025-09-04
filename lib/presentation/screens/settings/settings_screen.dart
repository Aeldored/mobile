import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../core/theme/app_colors.dart';
import '../../../providers/settings_provider.dart';
import '../../../providers/network_provider.dart';
import '../../../providers/map_state_provider.dart';
import 'widgets/settings_section.dart';
import 'widgets/settings_item.dart';
import 'access_point_manager_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Header
          Container(
            width: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            padding: const EdgeInsets.all(16),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.settings,
                      color: Colors.white,
                      size: 24,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Settings',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Configure security settings and manage your data',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Security Settings
          SettingsSection(
            title: 'Security Settings',
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return SettingsItem(
                    icon: Icons.location_on,
                    iconColor: Colors.blue[600]!,
                    title: 'Location Services',
                    subtitle: 'Essential for WiFi network detection • ${settings.locationStatusText}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPermissionStatusIndicator(settings.locationPermissionStatus),
                        const SizedBox(width: 8),
                        Switch(
                          value: settings.locationEnabled,
                          onChanged: settings.isRequestingLocationPermission 
                              ? null // Disable while requesting
                              : (value) async {
                                  await settings.toggleLocation();
                                  // Show feedback based on result
                                  if (context.mounted) {
                                    final message = settings.locationEnabled 
                                        ? 'Location services enabled successfully'
                                        : 'Location permission required for Wi-Fi scanning';
                                    final color = settings.locationEnabled 
                                        ? AppColors.success : Colors.orange;
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: color,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),
              SettingsItem(
                icon: Icons.router,
                iconColor: Colors.orange[600]!,
                title: 'Access Point Manager',
                subtitle: 'Manage network whitelist, blacklist, and security flags',
                trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AccessPointManagerScreen(),
                  ),
                ),
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return SettingsItem(
                    icon: Icons.shield_outlined,
                    iconColor: Colors.red[600]!,
                    title: 'Auto-Block Suspicious Networks',
                    subtitle: 'Automatically prevent connections to detected threats',
                    trailing: Switch(
                      value: settings.autoBlockSuspicious,
                      onChanged: (value) => settings.toggleAutoBlock(),
                      activeColor: AppColors.primary,
                    ),
                  );
                },
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return SettingsItem(
                    icon: Icons.notifications_outlined,
                    iconColor: Colors.amber[700]!,
                    title: 'Security Alerts',
                    subtitle: 'Get notified of threats and network issues • ${settings.notificationStatusText}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildPermissionStatusIndicator(settings.notificationPermissionStatus),
                        const SizedBox(width: 8),
                        Switch(
                          value: settings.notificationsEnabled,
                          onChanged: settings.isRequestingNotificationPermission 
                              ? null // Disable while requesting
                              : (value) async {
                                  await settings.toggleNotifications();
                                  // Show feedback based on result
                                  if (context.mounted) {
                                    final message = settings.notificationsEnabled 
                                        ? 'Notifications enabled successfully'
                                        : 'Notification permission required for alerts';
                                    final color = settings.notificationsEnabled 
                                        ? AppColors.success : Colors.orange;
                                    
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(message),
                                        backgroundColor: color,
                                        duration: const Duration(seconds: 3),
                                      ),
                                    );
                                  }
                                },
                          activeColor: AppColors.primary,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          
          const SizedBox(height: 16),
          
          // Data & Privacy
          SettingsSection(
            title: 'Data & Privacy',
            children: [
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return SettingsItem(
                    icon: Icons.storage_outlined,
                    iconColor: Colors.purple[600]!,
                    title: 'Storage Usage',
                    trailing: Text(settings.storageUsedText, style: const TextStyle(color: AppColors.gray)),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: settings.storageUsagePercentage.clamp(0.0, 1.0),
                            backgroundColor: AppColors.lightGray,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.purple[600]!),
                            minHeight: 6,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
              Consumer<SettingsProvider>(
                builder: (context, settings, child) {
                  return SettingsItem(
                    icon: Icons.history_outlined,
                    iconColor: Colors.indigo[600]!,
                    title: 'Network History Retention',
                    subtitle: 'Configure data retention period for scanned networks',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('${settings.networkHistoryDays} days', style: TextStyle(color: Colors.grey[600])),
                        const SizedBox(width: 4),
                        const Icon(Icons.chevron_right, color: AppColors.gray),
                      ],
                    ),
                    onTap: () => _showHistoryDialog(context),
                  );
                },
              ),
              const Divider(height: 24, thickness: 0.5, indent: 16, endIndent: 16),
              SettingsItem(
                icon: Icons.delete_sweep_outlined,
                iconColor: Colors.red[600]!,
                title: 'Clear All Data',
                subtitle: 'Reset app to factory defaults',
                textColor: Colors.red[700]!,
                onTap: () => _showClearDataDialog(context),
              ),
            ],
          ),
          
          const SizedBox(height: 16),
          
          // Support & Information
          SettingsSection(
            title: 'Support & Information',
            children: [
              SettingsItem(
                icon: Icons.help_center_outlined,
                iconColor: Colors.blue[600]!,
                title: 'Help & FAQ',
                subtitle: 'Get help with using the app',
                trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
                onTap: () => _showHelpCenter(context),
              ),
              SettingsItem(
                icon: Icons.bug_report_outlined,
                iconColor: Colors.orange[600]!,
                title: 'Report a Problem',
                subtitle: 'Send feedback to DICT-CALABARZON',
                trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
                onTap: () => _showReportProblem(context),
              ),
              const Divider(height: 24, thickness: 0.5, indent: 16, endIndent: 16),
              SettingsItem(
                icon: Icons.description_outlined,
                iconColor: Colors.blue[600]!,
                title: 'Privacy Policy',
                subtitle: 'How we protect your data and privacy',
                trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
                onTap: () => _showPrivacyPolicy(context),
              ),
              SettingsItem(
                icon: Icons.article_outlined,
                iconColor: Colors.blue[600]!,
                title: 'Terms of Service',
                subtitle: 'Usage terms and conditions',
                trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
                onTap: () => _showTermsOfService(context),
              ),
              SettingsItem(
                icon: Icons.info_outline,
                iconColor: Colors.green[600]!,
                title: 'About DiSCon-X',
                subtitle: 'Version 1.2.5 • DICT-CALABARZON',
                trailing: const Icon(Icons.chevron_right, color: AppColors.gray),
                onTap: () => _showAboutDialog(context),
              ),
            ],
          ),
          
          // Footer
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
            child: Column(
              children: [
                Icon(
                  Icons.security,
                  size: 32,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 8),
                Text(
                  'DisConX Security Suite',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'DICT-CALABARZON',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Department of Information and Communications Technology',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  void _showHistoryDialog(BuildContext context) {
    final settingsProvider = context.read<SettingsProvider>();
    final currentDays = settingsProvider.networkHistoryDays;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Network History Duration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RadioListTile(
              title: const Text('7 days'),
              value: 7,
              groupValue: currentDays,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setNetworkHistoryDays(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Network history set to 7 days'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),
            RadioListTile(
              title: const Text('30 days'),
              value: 30,
              groupValue: currentDays,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setNetworkHistoryDays(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Network history set to 30 days'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),
            RadioListTile(
              title: const Text('90 days'),
              value: 90,
              groupValue: currentDays,
              onChanged: (value) {
                if (value != null) {
                  settingsProvider.setNetworkHistoryDays(value);
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Network history set to 90 days'),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
  }

  void _showClearDataDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'This will delete all your network history, saved preferences, '
          'and blocked networks. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              
              // Clear data through SettingsProvider
              final settingsProvider = context.read<SettingsProvider>();
              final networkProvider = context.read<NetworkProvider>();
              final mapStateProvider = context.read<MapStateProvider>();
              
              try {
                await settingsProvider.clearAllData();
                // Also clear network provider data
                await networkProvider.clearNetworkData();
                // Clear map state data
                await mapStateProvider.clearAllData();
                
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('All data cleared successfully'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 3),
                    ),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error clearing data: $e'),
                      backgroundColor: AppColors.danger,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
            ),
            child: const Text('Clear Data'),
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('About DiSCon-X'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'DiSCon-X v1.2.5',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'DICT Secure Connect is the official Wi-Fi security app '
              'developed by the Department of Information and Communications '
              'Technology - CALABARZON for detecting and preventing evil twin '
              'attacks on public Wi-Fi networks.',
            ),
            SizedBox(height: 16),
            Text(
              '© 2025 DICT-CALABARZON',
              style: TextStyle(fontSize: 12, color: AppColors.gray),
            ),
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
  
  Widget _buildPermissionStatusIndicator(PermissionStatus status) {
    IconData icon;
    Color color;
    String tooltip;
    
    switch (status) {
      case PermissionStatus.granted:
        icon = Icons.check_circle;
        color = AppColors.success;
        tooltip = 'Permission Granted';
        break;
      case PermissionStatus.denied:
        icon = Icons.cancel;
        color = Colors.orange;
        tooltip = 'Permission Denied';
        break;
      case PermissionStatus.permanentlyDenied:
        icon = Icons.block;
        color = AppColors.danger;
        tooltip = 'Permission Permanently Denied';
        break;
      case PermissionStatus.restricted:
        icon = Icons.warning;
        color = Colors.orange;
        tooltip = 'Permission Restricted';
        break;
      case PermissionStatus.limited:
        icon = Icons.info;
        color = Colors.blue;
        tooltip = 'Permission Limited';
        break;
      default:
        icon = Icons.help;
        color = AppColors.gray;
        tooltip = 'Permission Status Unknown';
    }
    
    return Tooltip(
      message: tooltip,
      child: Icon(
        icon,
        size: 16,
        color: color,
      ),
    );
  }
  
  void _showHelpCenter(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Help Center'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Frequently Asked Questions',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildHelpItem(
                'How does evil twin detection work?',
                'DiSConX compares detected networks against government whitelists and analyzes signal patterns to identify suspicious networks.',
              ),
              _buildHelpItem(
                'Why do I need location permissions?',
                'Location access is required to scan for nearby Wi-Fi networks and verify their legitimacy based on geographic data.',
              ),
              _buildHelpItem(
                'What should I do if I find a suspicious network?',
                'Flag the network in the app and avoid connecting to it. Report it to DICT-CALABARZON if necessary.',
              ),
              _buildHelpItem(
                'How often should I scan for networks?',
                'Enable background scanning for continuous protection, or manually scan when connecting to new networks.',
              ),
              const SizedBox(height: 16),
              const Text(
                'For technical support, contact:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              const Text('Email: support@dict-calabarzon.gov.ph'),
              const Text('Phone: +63 (049) 502-8755'),
            ],
          ),
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
  
  Widget _buildHelpItem(String question, String answer) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            question,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            answer,
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey[700],
            ),
          ),
        ],
      ),
    );
  }
  
  void _showReportProblem(BuildContext context) {
    final TextEditingController problemController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Report a Problem'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Please describe the issue you\'re experiencing:',
                style: TextStyle(fontSize: 14),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: problemController,
                maxLines: 4,
                decoration: const InputDecoration(
                  hintText: 'Describe the problem...',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Your Email (Optional)',
                  hintText: 'your.email@example.com',
                  border: OutlineInputBorder(),
                  contentPadding: EdgeInsets.all(12),
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Your report will be sent to DICT-CALABARZON technical support.',
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (problemController.text.trim().isNotEmpty) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Problem report submitted successfully'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }
  
  void _showPrivacyPolicy(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Privacy Policy'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DICT-CALABARZON Privacy Policy',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Effective Date: January 1, 2025',
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
              SizedBox(height: 16),
              Text(
                'Data Collection:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '• Network information (SSID, signal strength, security type)\n'
                '• Device location (when scanning for networks)\n'
                '• App usage analytics (anonymous)\n'
                '• Error reports and diagnostics',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'Data Usage:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '• Detect and prevent evil twin attacks\n'
                '• Improve network security algorithms\n'
                '• Provide government cybersecurity insights\n'
                '• Enhance user experience',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'Data Protection:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'All data is encrypted and stored securely. Personal information is never shared with third parties without consent.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
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
  
  void _showTermsOfService(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms of Service'),
        content: const SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'DiSConX Terms of Service',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Last Updated: January 1, 2025',
                style: TextStyle(fontSize: 12, color: AppColors.gray),
              ),
              SizedBox(height: 16),
              Text(
                'Acceptance of Terms:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'By using DiSConX, you agree to these terms and the privacy policy. This app is provided by DICT-CALABARZON for public cybersecurity.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'Permitted Use:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '• Personal cybersecurity protection\n'
                '• Educational purposes\n'
                '• Reporting security threats to authorities\n'
                '• Government network monitoring compliance',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'Prohibited Use:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                '• Unauthorized network penetration\n'
                '• Interference with legitimate networks\n'
                '• Distribution of false security reports\n'
                '• Commercial use without permission',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text(
                'Limitation of Liability:',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              Text(
                'DICT-CALABARZON provides this app "as is" and is not liable for any damages resulting from its use. Users are responsible for their network security decisions.',
                style: TextStyle(fontSize: 13),
              ),
            ],
          ),
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

}