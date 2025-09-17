import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/app_colors.dart';
import '../../providers/settings_provider.dart';
import '../../providers/network_provider.dart';
import '../../providers/map_state_provider.dart';
import '../screens/settings/access_point_manager_screen.dart';

class SettingsDrawer extends StatelessWidget {
  const SettingsDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    return Drawer(
      child: Column(
        children: [
          // Drawer Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 48, 16, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, Color(0xFF1D4ED8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: const BoxDecoration(
                        image: DecorationImage(
                          image: AssetImage('assets/w_logo_png.png'),
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'DisConX',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Settings',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    // Close button
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white,
                          size: 20,
                        ),
                        tooltip: 'Close settings',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Scrollable Content
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Security Settings Section
                  _buildSectionTitle('Security Settings'),
                  _buildSecuritySettings(context),
                  
                  _buildSectionSeparator(),
                  
                  // Data Management Section
                  _buildSectionTitle('Data Management'),
                  _buildDataManagement(context),
                  
                  _buildSectionSeparator(),
                  
                  // About Section (Compact)
                  _buildSectionTitle('About'),
                  _buildAboutSection(context),
                  
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildSectionSeparator() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      height: 1,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.transparent,
            AppColors.lightGray,
            Colors.transparent,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
    );
  }


  Widget _buildSecuritySettings(BuildContext context) {
    return Column(
      children: [
        // Location Services Setting
        Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.location_on, color: AppColors.primary, size: 22),
              title: Row(
                children: [
                  const Text('Location Services', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  _buildPermissionStatusIndicator(settings.locationPermissionStatus),
                ],
              ),
              trailing: Switch(
                value: settings.locationEnabled,
                onChanged: settings.isRequestingLocationPermission 
                    ? null 
                    : (value) async {
                        await settings.toggleLocation();
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
            );
          },
        ),
        
        // Access Point Manager
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.router, color: Colors.orange, size: 22),
          title: const Text('Access Point Manager', style: TextStyle(fontSize: 15)),
          trailing: const Icon(Icons.chevron_right, color: AppColors.gray, size: 18),
          onTap: () {
            Navigator.pop(context); // Close drawer
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AccessPointManagerScreen(),
              ),
            );
          },
        ),
        
        // Auto-Block Suspicious Networks
        Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.shield, color: AppColors.danger, size: 22),
              title: const Text('Auto-Block Suspicious', style: TextStyle(fontSize: 15)),
              trailing: Switch(
                value: settings.autoBlockSuspicious,
                onChanged: (value) async {
                  await settings.toggleAutoBlock();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          settings.autoBlockSuspicious 
                              ? 'Auto-block enabled - suspicious networks will be automatically blocked'
                              : 'Auto-block disabled - suspicious networks will only be flagged',
                        ),
                        backgroundColor: settings.autoBlockSuspicious 
                            ? AppColors.primary : Colors.orange,
                        duration: const Duration(seconds: 3),
                      ),
                    );
                  }
                },
                activeColor: AppColors.primary,
              ),
            );
          },
        ),
        
        // Alert Notifications
        Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.notifications, color: AppColors.warning, size: 22),
              title: Row(
                children: [
                  const Text('Alert Notifications', style: TextStyle(fontSize: 15)),
                  const SizedBox(width: 8),
                  _buildPermissionStatusIndicator(settings.notificationPermissionStatus),
                ],
              ),
              trailing: Switch(
                value: settings.notificationsEnabled,
                onChanged: settings.isRequestingNotificationPermission 
                    ? null 
                    : (value) async {
                        await settings.toggleNotifications();
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
            );
          },
        ),
      ],
    );
  }

  Widget _buildDataManagement(BuildContext context) {
    return Column(
      children: [
        // Storage Usage
        Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.bgGray,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppColors.lightGray),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.storage, color: Colors.purple, size: 20),
                      const SizedBox(width: 12),
                      const Text(
                        'Storage Used',
                        style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      ),
                      const Spacer(),
                      Text(
                        settings.storageUsedText,
                        style: const TextStyle(fontSize: 13, color: AppColors.gray),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: settings.storageUsagePercentage.clamp(0.0, 1.0),
                      backgroundColor: AppColors.lightGray,
                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                      minHeight: 6,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
        
        // Network History
        Consumer<SettingsProvider>(
          builder: (context, settings, child) {
            return ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              leading: const Icon(Icons.history, color: AppColors.primary, size: 22),
              title: const Text('Network History', style: TextStyle(fontSize: 15)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${settings.networkHistoryDays} days', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right, color: AppColors.gray, size: 18),
                ],
              ),
              onTap: () => _showHistoryDialog(context),
            );
          },
        ),
        
        // Clear All Data
        ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          leading: const Icon(Icons.delete_outline, color: AppColors.danger, size: 22),
          title: const Text('Clear All Data', style: TextStyle(color: AppColors.danger, fontSize: 15)),
          onTap: () => _showClearDataDialog(context),
        ),
      ],
    );
  }

  Widget _buildAboutSection(BuildContext context) {
    return Column(
      children: [
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: const Icon(Icons.help_outline, color: AppColors.gray, size: 20),
          title: const Text('Help Center', style: TextStyle(fontSize: 14)),
          onTap: () => _showHelpCenter(context),
        ),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: const Icon(Icons.bug_report_outlined, color: AppColors.gray, size: 20),
          title: const Text('Report a Problem', style: TextStyle(fontSize: 14)),
          onTap: () => _showReportProblem(context),
        ),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: const Icon(Icons.info_outline, color: AppColors.gray, size: 20),
          title: const Text('About DisConX', style: TextStyle(fontSize: 14)),
          trailing: const Text('v1.2.5', style: TextStyle(color: AppColors.gray, fontSize: 12)),
          onTap: () => _showAboutDialog(context),
        ),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: const Icon(Icons.description_outlined, color: AppColors.gray, size: 20),
          title: const Text('Privacy Policy', style: TextStyle(fontSize: 14)),
          onTap: () => _showPrivacyPolicy(context),
        ),
        ListTile(
          dense: true,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          leading: const Icon(Icons.article_outlined, color: AppColors.gray, size: 20),
          title: const Text('Terms of Service', style: TextStyle(fontSize: 14)),
          onTap: () => _showTermsOfService(context),
        ),
      ],
    );
  }

  Widget _buildPermissionStatusIndicator(PermissionStatus status) {
    IconData icon;
    Color color;
    
    switch (status) {
      case PermissionStatus.granted:
        icon = Icons.check_circle;
        color = AppColors.success;
        break;
      case PermissionStatus.denied:
        icon = Icons.cancel;
        color = Colors.orange;
        break;
      case PermissionStatus.permanentlyDenied:
        icon = Icons.block;
        color = AppColors.danger;
        break;
      case PermissionStatus.restricted:
        icon = Icons.warning;
        color = Colors.orange;
        break;
      case PermissionStatus.limited:
        icon = Icons.info;
        color = Colors.blue;
        break;
      default:
        icon = Icons.help;
        color = AppColors.gray;
    }
    
    return Icon(icon, size: 16, color: color);
  }

  // Dialog methods

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
              
              final settingsProvider = context.read<SettingsProvider>();
              final networkProvider = context.read<NetworkProvider>();
              final mapStateProvider = context.read<MapStateProvider>();
              
              try {
                await settingsProvider.clearAllData();
                await networkProvider.clearNetworkData();
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
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
            Text('DiSCon-X v1.2.5', style: TextStyle(fontWeight: FontWeight.bold)),
            SizedBox(height: 8),
            Text(
              'DICT Secure Connect is the official Wi-Fi security app '
              'developed by the Department of Information and Communications '
              'Technology - CALABARZON for detecting and preventing evil twin '
              'attacks on public Wi-Fi networks.',
            ),
            SizedBox(height: 16),
            Text('© 2025 DICT-CALABARZON', style: TextStyle(fontSize: 12, color: AppColors.gray)),
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
              const Text('Frequently Asked Questions', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              _buildHelpItem(
                'How does evil twin detection work?',
                'DisConX compares detected networks against government whitelists and analyzes signal patterns to identify suspicious networks.',
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
              const Text('For technical support, contact:', style: TextStyle(fontWeight: FontWeight.bold)),
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
          Text(question, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(height: 4),
          Text(answer, style: TextStyle(fontSize: 13, color: Colors.grey[700])),
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
              const Text('Please describe the issue you\'re experiencing:', style: TextStyle(fontSize: 14)),
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
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
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
              Text('DICT-CALABARZON Privacy Policy', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Effective Date: January 1, 2025', style: TextStyle(fontSize: 12, color: AppColors.gray)),
              SizedBox(height: 16),
              Text('Data Collection:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text(
                '• Network information (SSID, signal strength, security type)\n'
                '• Device location (when scanning for networks)\n'
                '• App usage analytics (anonymous)\n'
                '• Error reports and diagnostics',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('Data Usage:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text(
                '• Detect and prevent evil twin attacks\n'
                '• Improve network security algorithms\n'
                '• Provide government cybersecurity insights\n'
                '• Enhance user experience',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('Data Protection:', style: TextStyle(fontWeight: FontWeight.w600)),
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
              Text('DisConX Terms of Service', style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(height: 8),
              Text('Last Updated: January 1, 2025', style: TextStyle(fontSize: 12, color: AppColors.gray)),
              SizedBox(height: 16),
              Text('Acceptance of Terms:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text(
                'By using DisConX, you agree to these terms and the privacy policy. This app is provided by DICT-CALABARZON for public cybersecurity.',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('Permitted Use:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text(
                '• Personal cybersecurity protection\n'
                '• Educational purposes\n'
                '• Reporting security threats to authorities\n'
                '• Government network monitoring compliance',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('Prohibited Use:', style: TextStyle(fontWeight: FontWeight.w600)),
              SizedBox(height: 4),
              Text(
                '• Unauthorized network penetration\n'
                '• Interference with legitimate networks\n'
                '• Distribution of false security reports\n'
                '• Commercial use without permission',
                style: TextStyle(fontSize: 13),
              ),
              SizedBox(height: 12),
              Text('Limitation of Liability:', style: TextStyle(fontWeight: FontWeight.w600)),
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