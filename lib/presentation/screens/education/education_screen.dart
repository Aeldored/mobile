import 'package:flutter/material.dart';
import 'dart:async';
import '../../../core/theme/app_colors.dart';
import '../../../core/constants/ui_constants.dart';
import '../../../data/models/education_content_model.dart';
import 'widgets/learning_module_card.dart';
import 'quiz_screen.dart';
import 'learning_content_screen.dart';

class EducationScreen extends StatefulWidget {
  const EducationScreen({super.key});

  @override
  State<EducationScreen> createState() => _EducationScreenState();
}

class ResourceLink {
  final IconData icon;
  final String title;
  final String subtitle;
  final String url;
  final VoidCallback? onTap;

  ResourceLink({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.url,
    this.onTap,
  });
}

class _EducationScreenState extends State<EducationScreen> {
  int _currentCarouselIndex = 0;
  final PageController _carouselController = PageController(viewportFraction: 0.85);
  Timer? _carouselTimer;
  final List<SecurityTip> _securityTips = [
    SecurityTip(
      id: '1',
      title: 'Always Use VPN',
      description: 'When on public Wi-Fi',
      icon: Icons.lock,
      backgroundColor: const Color(0xFF1976D2), // Blue 700 for better contrast
    ),
    SecurityTip(
      id: '2',
      title: 'Verify Networks',
      description: 'Check before connecting',
      icon: Icons.shield,
      backgroundColor: const Color(0xFF388E3C), // Green 700
    ),
    SecurityTip(
      id: '3',
      title: 'Strong Passwords',
      description: 'For your Wi-Fi networks',
      icon: Icons.key,
      backgroundColor: const Color(0xFF7B1FA2), // Purple 700
    ),
    SecurityTip(
      id: '4',
      title: 'Stay Updated',
      description: 'On security threats',
      icon: Icons.notifications_active,
      backgroundColor: const Color(0xFFF57C00), // Orange 700 (better than yellow)
    ),
  ];

  final List<EducationContentModel> _learningModules = [
    EducationContentModel(
      id: '1',
      title: 'Understanding Evil Twin Attacks',
      description: 'Learn how attackers create fake Wi-Fi networks and how to spot them',
      type: ContentType.article,
      difficulty: DifficultyLevel.beginner,
      estimatedMinutes: 5,
      imageUrl: 'assets/images/image2.png',
      tags: ['security', 'evil-twin', 'wi-fi'],
      viewCount: 1200,
      publishedDate: DateTime.now().subtract(const Duration(days: 7)),
    ),
    EducationContentModel(
      id: '2',
      title: 'Public Wi-Fi Safety Guide',
      description: 'Essential tips for staying safe when using public Wi-Fi networks',
      type: ContentType.article,
      difficulty: DifficultyLevel.beginner,
      estimatedMinutes: 8,
      imageUrl: 'assets/images/image1.png',
      tags: ['safety', 'public-wifi', 'tips'],
      viewCount: 856,
      publishedDate: DateTime.now().subtract(const Duration(days: 14)),
    ),
  ];

  final List<EducationContentModel> _quizzes = [
    EducationContentModel(
      id: '3',
      title: 'Wi-Fi Security Quiz',
      description: 'Test your knowledge about Wi-Fi security best practices',
      type: ContentType.quiz,
      difficulty: DifficultyLevel.intermediate,
      estimatedMinutes: 10,
      tags: ['quiz', 'security', 'test'],
      viewCount: 543,
      publishedDate: DateTime.now().subtract(const Duration(days: 3)),
    ),
  ];

  // Configurable resource links - easy to modify
  final List<ResourceLink> _additionalResources = [
    ResourceLink(
      icon: Icons.link,
      title: 'DICT Cybersecurity Portal',
      subtitle: 'Official government resources',
      url: 'https://dict.gov.ph/cybersecurity/',
    ),
    ResourceLink(
      icon: Icons.video_library,
      title: 'Video Tutorials',
      subtitle: 'Watch step-by-step guides',
      url: 'https://www.youtube.com/c/DICTPhilippines',
    ),
    ResourceLink(
      icon: Icons.download,
      title: 'Download Security Checklist',
      subtitle: 'PDF guide for offline reference',
      url: 'https://dict.gov.ph/wp-content/uploads/2023/wifi-security-checklist.pdf',
    ),
    ResourceLink(
      icon: Icons.phone,
      title: 'Report Cyber Incidents',
      subtitle: 'DICT Cybersecurity Emergency Response',
      url: 'tel:+63285527800',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _startCarouselAutoPlay();
  }

  @override
  void dispose() {
    _carouselTimer?.cancel();
    _carouselController.dispose();
    super.dispose();
  }

  void _startCarouselAutoPlay() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 4), (timer) {
      if (_carouselController.hasClients) {
        final nextIndex = (_currentCarouselIndex + 1) % _securityTips.length;
        _carouselController.animateToPage(
          nextIndex,
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeInOut,
        );
      }
    });
  }

  void _pauseCarouselAutoPlay() {
    _carouselTimer?.cancel();
  }

  void _resumeCarouselAutoPlay() {
    _startCarouselAutoPlay();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
                // Security Tips Section
                const Text(
                  'Security Tips',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                _buildSecurityTipsCarousel(),
                
                const SizedBox(height: 16),
                
                // Learning Modules Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Learning Modules',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _learningModules.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    return LearningModuleCard(
                      module: _learningModules[index],
                      onStart: () => _startModule(_learningModules[index]),
                    );
                  },
                ),
                
                const SizedBox(height: 16),
                
                // Test Your Knowledge Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Test Your Knowledge',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Quiz Card
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _quizzes.first.title,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _quizzes.first.description,
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 12),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            return Wrap(
                              spacing: 12,
                              runSpacing: 8,
                              children: [
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.blue[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.quiz,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '10 questions',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: Colors.green[100],
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.workspace_premium,
                                    color: AppColors.success,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Get certified',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 14,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                        },
                      ),
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: () => _startQuiz(_quizzes.first),
                            child: const Text('Start Quiz'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Additional Resources
                const Text(
                  'Additional Resources',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Generate resource links from configurable data
                ..._additionalResources.map((resource) => _buildResourceLink(
                  icon: resource.icon,
                  title: resource.title,
                  subtitle: resource.subtitle,
                  onTap: resource.onTap ?? () => _openResourceUrl(resource.url),
                )),
        ],
      ),
    );
  }

  Widget _buildResourceLink({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
          ),
        ),
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
          maxLines: 1,
        ),
        subtitle: Text(
          subtitle,
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _buildSecurityTipsCarousel() {
    return Column(
      children: [
        SizedBox(
          height: 180,
          child: PageView.builder(
            itemCount: _securityTips.length,
            padEnds: false,
            controller: _carouselController,
            onPageChanged: (index) {
              setState(() {
                _currentCarouselIndex = index;
              });
            },
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.symmetric(horizontal: UIConstants.spaceSM),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      _securityTips[index].backgroundColor,
                      _securityTips[index].backgroundColor.withValues(alpha: 0.8),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(UIConstants.radiusXL),
                  boxShadow: [
                    BoxShadow(
                      color: _securityTips[index].backgroundColor.withValues(alpha: 0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                    ...UIConstants.shadowLG,
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      _pauseCarouselAutoPlay();
                      _showTipDetails(_securityTips[index]);
                      Future.delayed(const Duration(seconds: 2), () {
                        _resumeCarouselAutoPlay();
                      });
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.1),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _securityTips[index].icon,
                              size: 32,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            _securityTips[index].title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _securityTips[index].description,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                              shadows: [
                                Shadow(
                                  offset: Offset(0, 1),
                                  blurRadius: 2,
                                  color: Colors.black26,
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(
            _securityTips.length,
            (index) => Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                color: index == _currentCarouselIndex ? AppColors.primary : Colors.grey[300],
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showTipDetails(SecurityTip tip) {
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
                color: Colors.white,
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
                _getDetailedTipDescription(tip.id),
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

  String _getDetailedTipDescription(String tipId) {
    switch (tipId) {
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
        return 'Learn more about this security tip to protect your Wi-Fi connections.';
    }
  }

  void _startModule(EducationContentModel module) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LearningContentScreen(module: module),
      ),
    );
  }

  void _startQuiz(EducationContentModel quiz) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QuizScreen()),
    );
  }

  void _openResourceUrl(String url) {
    // For demo purposes, show the URL in a snackbar
    // In production, use url_launcher package to open URLs
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Opening: $url'),
        backgroundColor: AppColors.primary,
        action: SnackBarAction(
          label: 'Copy',
          textColor: Colors.white,
          onPressed: () {
            // In production, copy URL to clipboard
          },
        ),
      ),
    );
  }
}