import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/education_content_model.dart';
import '../main_screen.dart';

class LearningContentScreen extends StatefulWidget {
  final EducationContentModel module;

  const LearningContentScreen({
    super.key,
    required this.module,
  });

  @override
  State<LearningContentScreen> createState() => _LearningContentScreenState();
}

class _LearningContentScreenState extends State<LearningContentScreen> {
  final ScrollController _scrollController = ScrollController();
  double _readingProgress = 0.0;

  Future<bool> _onWillPop() async {
    // Navigate back to home instead of exiting the app
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainScreen.navigateToTab(context, 0);
    return false;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_updateReadingProgress);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_updateReadingProgress);
    _scrollController.dispose();
    super.dispose();
  }

  void _updateReadingProgress() {
    if (_scrollController.hasClients) {
      final maxScrollExtent = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.offset;
      
      if (maxScrollExtent > 0) {
        setState(() {
          _readingProgress = (currentScroll / maxScrollExtent).clamp(0.0, 1.0);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          // App Bar with progress
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                widget.module.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withValues(alpha: 0.8),
                        ],
                      ),
                    ),
                  ),
                  if (widget.module.imageUrl != null)
                    Positioned.fill(
                      child: Image.asset(
                        widget.module.imageUrl!,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            _getContentIcon(),
                            size: 64,
                            color: Colors.white.withValues(alpha: 0.7),
                          );
                        },
                      ),
                    ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.3),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(4),
              child: LinearProgressIndicator(
                value: _readingProgress,
                backgroundColor: Colors.white.withValues(alpha: 0.3),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                minHeight: 4,
              ),
            ),
          ),

          // Content
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Module info
                  Row(
                    children: [
                      _buildInfoChip(
                        Icons.access_time,
                        '${widget.module.estimatedMinutes} min read',
                        AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        Icons.trending_up,
                        widget.module.difficultyString,
                        _getDifficultyColor(),
                      ),
                      const SizedBox(width: 12),
                      _buildInfoChip(
                        Icons.remove_red_eye,
                        '${widget.module.viewCount} views',
                        Colors.grey[600]!,
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // Description
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
                    ),
                    child: Text(
                      widget.module.description,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[700],
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Main content
                  ..._buildContent(),

                  const SizedBox(height: 32),

                  // Completion action
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.green[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green[200]!),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 48,
                          color: Colors.green[600],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Great job! You\'ve completed this module.',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'You\'re now better equipped to protect yourself from Wi-Fi security threats.',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.green[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back),
                          label: const Text('Back to Learning'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green[600],
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }

  IconData _getContentIcon() {
    switch (widget.module.type) {
      case ContentType.article:
        return Icons.article;
      case ContentType.video:
        return Icons.play_circle_outline;
      case ContentType.quiz:
        return Icons.quiz;
      case ContentType.infographic:
        return Icons.image;
    }
  }

  Color _getDifficultyColor() {
    switch (widget.module.difficulty) {
      case DifficultyLevel.beginner:
        return Colors.green[600]!;
      case DifficultyLevel.intermediate:
        return Colors.orange[600]!;
      case DifficultyLevel.advanced:
        return Colors.red[600]!;
    }
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildContent() {
    switch (widget.module.id) {
      case '1':
        return _buildEvilTwinContent();
      case '2':
        return _buildPublicWiFiSafetyContent();
      default:
        return [
          Text(
            'Content coming soon...',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
            ),
          ),
        ];
    }
  }

  List<Widget> _buildEvilTwinContent() {
    return [
      _buildSectionTitle('What is an Evil Twin Attack?'),
      _buildContentText(
        'Imagine you\'re at a coffee shop and see "CoffeeShop_Free_WiFi" in your Wi-Fi list. '
        'You connect to it, thinking it\'s the café\'s network. But what if it\'s actually a fake network '
        'created by a hacker sitting nearby? This is called an "Evil Twin" attack.',
      ),

      _buildImage('assets/images/image2.png', 'Evil Twin Network Diagram'),

      _buildContentText(
        'The hacker creates a fake Wi-Fi hotspot that looks exactly like the real one. '
        'When you connect to their fake network instead of the real one, they can see '
        'everything you do online - your passwords, messages, and personal information.',
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('How Does it Work?'),
      
      _buildStepCard(
        1,
        'Setup',
        'The hacker sets up a fake Wi-Fi hotspot with a name similar to legitimate networks nearby.',
        Icons.wifi_tethering,
        Colors.red,
      ),

      _buildStepCard(
        2,
        'Deception',
        'They make their fake network appear stronger or more attractive than the real one.',
        Icons.signal_wifi_4_bar,
        Colors.orange,
      ),

      _buildStepCard(
        3,
        'Connection',
        'When you connect to their fake network, all your internet traffic goes through their device.',
        Icons.devices,
        Colors.blue,
      ),

      _buildStepCard(
        4,
        'Data Theft',
        'The hacker can now see and steal your passwords, personal information, and sensitive data.',
        Icons.security,
        Colors.red,
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('Real-World Example'),
      
      _buildExampleBox(
        'Sarah\'s Story',
        'Sarah went to a mall and connected to "Mall_Free_WiFi" to check her bank account. '
        'Unknown to her, this was a fake network created by someone in the food court. '
        'The hacker was able to steal her banking login and used it to transfer money from her account. '
        'The real mall Wi-Fi was actually called "MallGuest_WiFi".',
        Icons.person,
        Colors.red,
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('How to Protect Yourself'),

      _buildProtectionTip(
        'Always Verify Network Names',
        'Ask staff for the correct Wi-Fi network name. Don\'t assume networks with obvious names like "Free_WiFi" are legitimate.',
        Icons.verified_user,
        Colors.green,
      ),

      _buildProtectionTip(
        'Look for Security',
        'Legitimate business networks usually require passwords. Be suspicious of completely open networks in public places.',
        Icons.lock,
        Colors.blue,
      ),

      _buildProtectionTip(
        'Use Your Mobile Data',
        'When in doubt, use your phone\'s mobile data instead of public Wi-Fi for sensitive activities like banking.',
        Icons.phone_android,
        Colors.purple,
      ),

      _buildProtectionTip(
        'Enable VPN',
        'A VPN encrypts your internet connection, making it much harder for hackers to steal your information.',
        Icons.vpn_key,
        Colors.orange,
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('Warning Signs'),

      _buildWarningSign(
        'Multiple Similar Networks',
        'Seeing "Starbucks", "Starbucks_WiFi", and "Starbucks-Free" might indicate one is fake.',
      ),

      _buildWarningSign(
        'No Password Required',
        'If a business network doesn\'t ask for a password when you\'d expect it to.',
      ),

      _buildWarningSign(
        'Poor Connection Quality',
        'If websites load slowly or you get redirected to suspicious pages.',
      ),

      _buildWarningSign(
        'Unexpected Login Requests',
        'If you\'re asked to log in again to services you\'re already logged into.',
      ),
    ];
  }

  List<Widget> _buildPublicWiFiSafetyContent() {
    return [
      _buildSectionTitle('Why Public Wi-Fi Can Be Dangerous'),
      _buildContentText(
        'Public Wi-Fi networks are like busy highways where everyone can see what others are carrying. '
        'Unlike your home Wi-Fi that has security protection, public networks are often "open roads" '
        'where hackers can easily see your personal information.',
      ),

      _buildImage('assets/images/image1.png', 'Public Wi-Fi Security Risks'),

      const SizedBox(height: 24),
      _buildSectionTitle('Common Public Wi-Fi Risks'),

      _buildRiskCard(
        'Password Theft',
        'Hackers can see your passwords when you log into websites, email, or social media.',
        Icons.password,
        Colors.red,
      ),

      _buildRiskCard(
        'Personal Information Theft',
        'Your photos, messages, and personal files can be accessed by others on the same network.',
        Icons.folder_shared,
        Colors.orange,
      ),

      _buildRiskCard(
        'Banking Information',
        'Credit card numbers and banking details can be stolen if you access financial websites.',
        Icons.credit_card,
        Colors.red,
      ),

      _buildRiskCard(
        'Identity Theft',
        'Hackers can collect enough information to pretend to be you online or steal your identity.',
        Icons.person_off,
        Colors.purple,
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('Safe Public Wi-Fi Practices'),

      _buildSafetyRule(
        '1. Verify Before You Connect',
        'Always ask staff: "What\'s your Wi-Fi network name and password?" Don\'t guess or assume.',
        Icons.help_outline,
        Colors.blue,
      ),

      _buildSafetyRule(
        '2. Avoid Sensitive Activities',
        'Don\'t do banking, shopping, or access work files on public Wi-Fi. Wait until you\'re on a secure network.',
        Icons.remove_shopping_cart,
        Colors.orange,
      ),

      _buildSafetyRule(
        '3. Use HTTPS Websites',
        'Look for the lock icon 🔒 in your browser\'s address bar. This means the website is using encryption.',
        Icons.https,
        Colors.green,
      ),

      _buildSafetyRule(
        '4. Turn Off Auto-Connect',
        'Disable automatic Wi-Fi connection on your phone so it doesn\'t connect to unknown networks without your permission.',
        Icons.wifi_off,
        Colors.purple,
      ),

      _buildSafetyRule(
        '5. Use a VPN',
        'A VPN creates a secure tunnel for your internet connection, protecting your data even on public Wi-Fi.',
        Icons.vpn_lock,
        Colors.green,
      ),

      _buildSafetyRule(
        '6. Keep Software Updated',
        'Regular updates fix security holes that hackers might try to exploit.',
        Icons.system_update,
        Colors.blue,
      ),

      const SizedBox(height: 24),
      _buildSectionTitle('Quick Safety Checklist'),

      _buildChecklistSection([
        'Did I verify the network name with staff?',
        'Am I avoiding banking and shopping?',
        'Is my VPN turned on?',
        'Are my apps and phone updated?',
        'Will I log out of all accounts when done?',
      ]),

      const SizedBox(height: 24),
      _buildSectionTitle('Emergency: What If You Think You\'ve Been Hacked?'),

      _buildEmergencySteps([
        'Disconnect from Wi-Fi immediately',
        'Change passwords for all accounts you accessed',
        'Check bank and credit card statements',
        'Run antivirus scan on your device',
        'Contact your bank if you did any financial activities',
        'Consider freezing your credit if identity theft is suspected',
      ]),
    ];
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.primary,
        ),
      ),
    );
  }

  Widget _buildContentText(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 16,
          height: 1.6,
          color: Colors.grey[800],
        ),
      ),
    );
  }

  Widget _buildImage(String imagePath, String description) {
    return Container(
      width: double.infinity,
      height: 200,
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          imagePath,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[100],
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    description,
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
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

  Widget _buildStepCard(int step, String title, String description, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                step.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
          Icon(icon, color: color, size: 24),
        ],
      ),
    );
  }

  Widget _buildExampleBox(String title, String content, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[700],
              height: 1.5,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProtectionTip(String title, String description, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningSign(String title, String description) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber[50],
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.amber[200]!),
      ),
      child: Row(
        children: [
          Icon(Icons.warning, color: Colors.amber[700], size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.amber[800],
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.amber[700],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRiskCard(String title, String description, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSafetyRule(String title, String description, IconData icon, Color color) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: color,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[700],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChecklistSection(List<String> items) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.green[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.green[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.checklist, color: Colors.green[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Before Using Public Wi-Fi',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.green[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...items.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.check_box_outline_blank, color: Colors.green[600], size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    item,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.green[700],
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }

  Widget _buildEmergencySteps(List<String> steps) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.red[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.emergency, color: Colors.red[700], size: 20),
              const SizedBox(width: 8),
              Text(
                'Emergency Actions',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.red[700],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...steps.asMap().entries.map((entry) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: Colors.red[700],
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      (entry.key + 1).toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    entry.value,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.red[700],
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          )),
        ],
      ),
    );
  }
}