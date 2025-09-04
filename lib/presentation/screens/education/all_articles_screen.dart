import 'package:flutter/material.dart';
import 'dart:developer' as developer;
import '../../../core/theme/app_colors.dart';
import '../../../data/models/education_content_model.dart';
import '../../../data/services/education_content_service.dart';
import 'widgets/enhanced_learning_module_card.dart';
import 'article_reader_screen.dart';

class AllArticlesScreen extends StatefulWidget {
  const AllArticlesScreen({super.key});

  @override
  State<AllArticlesScreen> createState() => _AllArticlesScreenState();
}

class _AllArticlesScreenState extends State<AllArticlesScreen>
    with TickerProviderStateMixin {
  final EducationContentService _educationService = EducationContentService();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  List<EducationContentModel> _allArticles = [];
  List<EducationContentModel> _filteredArticles = [];
  bool _isLoading = true;
  String _selectedCategory = 'all';
  String _searchQuery = '';
  bool _isSearchVisible = true;
  bool _isResultsHeaderVisible = true; // Add state for results header visibility
  late TabController _tabController;

  final List<String> _categories = [
    'all',
    'evil_twins',
    'wifi_security',
    'public_safety',
    'phishing',
    'device_security',
    'government_guidelines'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _categories.length, vsync: this);
    _scrollController.addListener(_handleScroll);
    _loadAllArticles();
  }

  void _handleScroll() {
    const double searchThreshold = 100.0;
    const double resultsHeaderThreshold = 50.0;
    
    final bool shouldHideSearch = _scrollController.offset > searchThreshold;
    final bool shouldHideResultsHeader = _scrollController.offset > resultsHeaderThreshold;
    
    if (shouldHideSearch != !_isSearchVisible || shouldHideResultsHeader != !_isResultsHeaderVisible) {
      setState(() {
        _isSearchVisible = !shouldHideSearch;
        _isResultsHeaderVisible = !shouldHideResultsHeader;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadAllArticles() async {
    try {
      developer.log('🔄 Loading all articles...');
      final articles = await _educationService.getAllArticles(limit: 100);
      developer.log('📊 Loaded ${articles.length} articles for View All screen');
      
      // Debug: log first few article titles
      for (int i = 0; i < articles.length && i < 5; i++) {
        developer.log('📄 Article ${i + 1}: ${articles[i].title} (ID: ${articles[i].id})');
      }
      
      if (mounted) {
        setState(() {
          _allArticles = articles;
          _filteredArticles = articles;
          _isLoading = false;
        });
      }
    } catch (e) {
      developer.log('❌ Error loading articles: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _filterArticles() {
    setState(() {
      _filteredArticles = _allArticles.where((article) {
        final matchesCategory = _selectedCategory == 'all' || 
                               article.category == _selectedCategory;
        
        final matchesSearch = _searchQuery.isEmpty ||
                             article.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                             article.description.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                             article.tags.any((tag) => tag.toLowerCase().contains(_searchQuery.toLowerCase()));
        
        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  void _onCategoryChanged(int index) {
    setState(() {
      _selectedCategory = _categories[index];
    });
    _filterArticles();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query;
    });
    _filterArticles();
  }

  Future<void> _refreshArticles() async {
    setState(() {
      _isLoading = true;
    });
    await _loadAllArticles();
  }

  void _navigateToArticle(EducationContentModel article) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ArticleReaderScreen(article: article),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Educational Articles'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: _showAboutDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Subtitle header
          Container(
            width: double.infinity,
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: const Text(
              'Browse all educational articles and resources',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          
          // Search and filter bar with animation
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchVisible ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isSearchVisible ? 1.0 : 0.0,
              child: _buildSearchAndFilterBar(),
            ),
          ),
          
          // Category tabs with gradient background and subtle shadow
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white,
                  Colors.white.withValues(alpha: 0.95),
                  Colors.grey[50]!.withValues(alpha: 0.8),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withValues(alpha: 0.15),
                  offset: const Offset(0, 1),
                  blurRadius: 3,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              onTap: _onCategoryChanged,
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              dividerColor: Colors.transparent, // Remove divider line
              labelStyle: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              unselectedLabelStyle: const TextStyle(
                fontWeight: FontWeight.w400,
                fontSize: 13,
              ),
              tabs: _categories.map((category) {
                return Tab(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_getCategoryIcon(category)),
                      const SizedBox(width: 6),
                      Text(_getCategoryDisplayName(category)),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
          
          // Content area
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _refreshArticles,
                    child: _filteredArticles.isEmpty
                        ? _buildEmptyState()
                        : _buildArticlesList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Search bar
          TextField(
            controller: _searchController,
            onChanged: _onSearchChanged,
            decoration: InputDecoration(
              hintText: 'Search articles, tags...',
              prefixIcon: const Icon(Icons.search, color: AppColors.gray),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.gray),
                      onPressed: () {
                        _searchController.clear();
                        _onSearchChanged('');
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey[300]!),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppColors.primary),
              ),
              filled: true,
              fillColor: Colors.grey[50],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.article_outlined,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 24),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'No articles found for "$_searchQuery"'
                  : 'No articles available',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              _searchQuery.isNotEmpty 
                  ? 'Try adjusting your search or category filter'
                  : 'Check back later for new educational content',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
              textAlign: TextAlign.center,
            ),
            if (_searchQuery.isNotEmpty || _selectedCategory != 'all') ...[
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                    _selectedCategory = 'all';
                    _tabController.animateTo(0);
                  });
                  _filterArticles();
                },
                icon: const Icon(Icons.clear),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildArticlesList() {
    return Column(
      children: [
        // Results header with scroll-to-hide animation
        AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          height: _isResultsHeaderVisible ? null : 0,
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 300),
            opacity: _isResultsHeaderVisible ? 1.0 : 0.0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Text(
                    '${_filteredArticles.length} article${_filteredArticles.length == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  if (_searchQuery.isNotEmpty || _selectedCategory != 'all') ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        'filtered',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                  ),
                ),
              ],
              const Spacer(),
              // Sort button (future enhancement)
              IconButton(
                onPressed: () {
                  // Future: Add sorting options
                },
                icon: Icon(
                  Icons.sort,
                  color: Colors.grey[600],
                  size: 20,
                ),
                tooltip: 'Sort options (coming soon)',
              ),
                ],
              ),
            ),
          ),
        ),
        
        // Articles list
        Expanded(
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            itemCount: _filteredArticles.length,
            separatorBuilder: (context, index) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              return EnhancedLearningModuleCard(
                module: _filteredArticles[index],
                onStart: () => _navigateToArticle(_filteredArticles[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  String _getCategoryIcon(String category) {
    switch (category) {
      case 'all':
        return '📚';
      case 'evil_twins':
        return '🎭';
      case 'wifi_security':
        return '🔒';
      case 'public_safety':
        return '🛡️';
      case 'phishing':
        return '🎣';
      case 'device_security':
        return '📱';
      case 'government_guidelines':
        return '🏛️';
      default:
        return '📖';
    }
  }

  String _getCategoryDisplayName(String category) {
    switch (category) {
      case 'all':
        return 'All';
      case 'evil_twins':
        return 'Evil Twins';
      case 'wifi_security':
        return 'WiFi Security';
      case 'public_safety':
        return 'Public Safety';
      case 'phishing':
        return 'Phishing';
      case 'device_security':
        return 'Device Security';
      case 'government_guidelines':
        return 'Guidelines';
      default:
        return 'General';
    }
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.article, color: AppColors.primary),
            SizedBox(width: 8),
            Expanded(
              child: Text('About Educational Articles'),
            ),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Browse our comprehensive collection of educational articles about Wi-Fi security and cyber safety.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              
              const Text('Features:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('• Search across titles, descriptions, and tags'),
              const Text('• Filter by category and difficulty level'),
              const Text('• Comprehensive cybersecurity topics'),
              const Text('• Government guidelines and best practices'),
              const Text('• Regular content updates'),
              
              const SizedBox(height: 16),
              
              const Text('Categories:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('🎭', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Evil Twins: Rogue access points')),
                ],
              ),
              Row(
                children: [
                  const Text('🔒', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Wi-Fi Security: Network protection')),
                ],
              ),
              Row(
                children: [
                  const Text('🛡️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Public Safety: Safe browsing practices')),
                ],
              ),
              Row(
                children: [
                  const Text('🎣', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Phishing: Email and web threats')),
                ],
              ),
              Row(
                children: [
                  const Text('📱', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Device Security: Mobile protection')),
                ],
              ),
              Row(
                children: [
                  const Text('🏛️', style: TextStyle(fontSize: 16)),
                  const SizedBox(width: 4),
                  Expanded(child: Text('Guidelines: Government policies')),
                ],
              ),
              
              const SizedBox(height: 16),
              
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.tips_and_updates, color: AppColors.primary, size: 16),
                        SizedBox(width: 4),
                        Text('Tips:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text('• Use search to find specific topics'),
                    Text('• Filter by category for focused learning'),
                    Text('• Pull down to refresh for new content'),
                    Text('• Save favorites for quick access'),
                  ],
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
}