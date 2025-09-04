import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/education_content_model.dart';
import 'dart:developer' as developer;

class EducationContentService {
  static final EducationContentService _instance = EducationContentService._internal();
  factory EducationContentService() => _instance;
  EducationContentService._internal();

  FirebaseFirestore? _firestore;

  /// Lazy getter for Firestore instance
  FirebaseFirestore get firestore {
    if (_firestore == null) {
      try {
        _firestore = FirebaseFirestore.instance;
      } catch (e) {
        developer.log('⚠️ Firebase not initialized yet for education content service');
        rethrow;
      }
    }
    return _firestore!;
  }

  /// Get featured/published educational articles from Firestore
  /// This replaces the hardcoded learning modules with dynamic content from web admin
  Future<List<EducationContentModel>> getFeaturedArticles({int limit = 5}) async {
    try {
      developer.log('📚 Fetching featured articles from Firestore...');
      
      // First try to get pinned articles, then fill with recent ones
      QuerySnapshot snapshot;
      
      try {
        // Try to get pinned articles first
        snapshot = await firestore
            .collection('educational_content')
            .where('isPublished', isEqualTo: true)
            .where('isPinned', isEqualTo: true)
            .orderBy('priority', descending: false)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
            
        developer.log('📌 Found ${snapshot.docs.length} pinned articles');
      } catch (e) {
        developer.log('⚠️ Could not query by isPinned, trying basic query: $e');
        // Fallback to basic query if isPinned field doesn't exist or index is missing
        snapshot = await firestore
            .collection('educational_content')
            .where('isPublished', isEqualTo: true)
            .orderBy('createdAt', descending: true)
            .limit(limit)
            .get();
      }

      final List<EducationContentModel> articles = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        // Convert Firestore document to EducationContentModel
        final article = EducationContentModel(
          id: doc.id,
          title: data['title'] ?? 'Untitled',
          description: data['summary'] ?? data['content'] ?? '',
          type: _getContentTypeFromFirestore(data['contentType']),
          difficulty: _getDifficultyFromFirestore(data['difficulty']),
          estimatedMinutes: data['estimatedReadTime'] ?? 5,
          imageUrl: _getCategoryImageUrl(data['category']),
          tags: List<String>.from(data['tags'] ?? []),
          viewCount: data['views'] ?? 0,
          publishedDate: (data['publishedAt'] as Timestamp?)?.toDate() ?? 
                        (data['createdAt'] as Timestamp?)?.toDate() ?? 
                        DateTime.now(),
          category: data['category'],
          author: data['createdBy'] ?? data['author'] ?? 'DICT Admin',
          isPinned: data['isPinned'] ?? false,
        );
        
        articles.add(article);
      }

      developer.log('✅ Retrieved ${articles.length} featured articles');
      return articles;
      
    } catch (error) {
      developer.log('❌ Error fetching featured articles: $error');
      // Return fallback content to maintain functionality
      return _getFallbackArticles();
    }
  }

  /// Get articles by category
  Future<List<EducationContentModel>> getArticlesByCategory(String category, {int limit = 20}) async {
    try {
      final QuerySnapshot snapshot = await firestore
          .collection('educational_content')
          .where('category', isEqualTo: category)
          .where('isPublished', isEqualTo: true)
          .orderBy('priority')
          .limit(limit)
          .get();

      final List<EducationContentModel> articles = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        
        final article = EducationContentModel(
          id: doc.id,
          title: data['title'] ?? 'Untitled',
          description: data['summary'] ?? data['content'] ?? '',
          type: _getContentTypeFromFirestore(data['contentType']),
          difficulty: _getDifficultyFromFirestore(data['difficulty']),
          estimatedMinutes: data['estimatedReadTime'] ?? 5,
          imageUrl: _getCategoryImageUrl(data['category']),
          tags: List<String>.from(data['tags'] ?? []),
          viewCount: data['views'] ?? 0,
          publishedDate: (data['publishedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          category: data['category'],
          author: data['createdBy'] ?? data['author'] ?? 'DICT Admin',
          isPinned: data['isPinned'] ?? false,
        );
        
        articles.add(article);
      }

      return articles;
    } catch (error) {
      developer.log('❌ Error fetching articles by category: $error');
      return [];
    }
  }

  /// Get full article content for reading
  Future<String?> getArticleContent(String articleId) async {
    try {
      developer.log('📖 Fetching full content for article: $articleId');
      
      final DocumentSnapshot doc = await firestore
          .collection('educational_content')
          .doc(articleId)
          .get();

      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        
        developer.log('📄 Document data keys: ${data.keys.toList()}');
        
        // Increment view count
        _incrementViewCount(articleId);
        
        // Try multiple possible field names for content
        String? content = data['content'] ?? 
                         data['description'] ?? 
                         data['summary'] ?? 
                         data['body'] ?? 
                         data['text'] ?? 
                         '';
                         
        developer.log('📝 Content length: ${content?.length ?? 0} characters');
        developer.log('📝 Content preview: ${content?.substring(0, content.length > 100 ? 100 : content.length) ?? 'No content'}...');
        
        return (content != null && content.isNotEmpty) ? content : null;
      }
      
      developer.log('❌ Document does not exist: $articleId');
      return null;
    } catch (error) {
      developer.log('❌ Error fetching article content: $error');
      return null;
    }
  }

  /// Get mixed category content - ensures variety
  Future<List<EducationContentModel>> getMixedCategoryContent({int limit = 2}) async {
    try {
      developer.log('🎯 Fetching mixed category content...');
      developer.log('🔍 Firebase project: ${firestore.app.options.projectId}');
      
      // Get documents without any filters first
      QuerySnapshot snapshot = await firestore
          .collection('educational_content')
          .limit(limit)
          .get();
          
      developer.log('📊 Found ${snapshot.docs.length} total documents for featured articles');
      
      if (snapshot.docs.isEmpty) {
        developer.log('❌ Collection is completely empty!');
        return _getFallbackArticles();
      }
      
      final List<EducationContentModel> articles = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        developer.log('📄 Processing document ${doc.id}: ${data.keys.toList()}');
        
        // Enhanced data extraction with better fallbacks
        final title = data['title'] ?? data['name'] ?? 'Untitled Article';
        final description = data['summary'] ?? data['description'] ?? data['content'] ?? 'No description available';
        final category = data['category'] ?? 'general_security';
        
        final article = EducationContentModel(
          id: doc.id,
          title: title,
          description: description,
          type: _getContentTypeFromFirestore(data['contentType'] ?? data['type']),
          difficulty: _getDifficultyFromFirestore(data['difficulty']),
          estimatedMinutes: (data['estimatedReadTime'] ?? data['readTime'] ?? 5).toInt(),
          imageUrl: _getCategoryImageUrl(category),
          tags: _extractTags(data),
          viewCount: (data['views'] ?? data['viewCount'] ?? 0).toInt(),
          publishedDate: _extractDate(data),
          category: category,
          author: data['createdBy'] ?? data['author'] ?? 'DICT Admin',
          isPinned: data['isPinned'] == true,
        );
        
        articles.add(article);
        developer.log('✅ Added article: ${article.title} (${article.category})');
        
        if (articles.length >= limit) break;
      }
      
      developer.log('✅ Retrieved ${articles.length} articles from Firestore');
      
      if (articles.isEmpty) {
        developer.log('❌ No articles found, using fallback content');
        return _getFallbackArticles();
      }
      
      return articles;
      
    } catch (error) {
      developer.log('❌ Error fetching mixed category content: $error');
      developer.log('❌ Error type: ${error.runtimeType}');
      developer.log('❌ Using fallback content...');
      return _getFallbackArticles();
    }
  }
  
  List<String> _extractTags(Map<String, dynamic> data) {
    final tags = data['tags'];
    if (tags is List) {
      return tags.map((tag) => tag.toString()).toList();
    } else if (tags is String) {
      return tags.split(',').map((tag) => tag.trim()).toList();
    }
    return [];
  }
  
  DateTime _extractDate(Map<String, dynamic> data) {
    final publishedAt = data['publishedAt'];
    final createdAt = data['createdAt'];
    final updatedAt = data['updatedAt'];
    
    if (publishedAt is Timestamp) return publishedAt.toDate();
    if (createdAt is Timestamp) return createdAt.toDate();
    if (updatedAt is Timestamp) return updatedAt.toDate();
    
    // Try string dates
    if (publishedAt is String) {
      try {
        return DateTime.parse(publishedAt);
      } catch (e) {
        developer.log('⚠️ Could not parse publishedAt date: $publishedAt');
      }
    }
    
    return DateTime.now().subtract(const Duration(days: 1));
  }

  /// Get all articles for "View All" screen
  Future<List<EducationContentModel>> getAllArticles({int limit = 50}) async {
    try {
      developer.log('📚 Fetching all articles for View All screen...');
      developer.log('🔍 Firebase project: ${firestore.app.options.projectId}');
      
      // Get ALL documents first, without any filters
      QuerySnapshot snapshot = await firestore
          .collection('educational_content')
          .limit(limit)
          .get();
          
      developer.log('📊 Found ${snapshot.docs.length} total documents in collection');
      
      if (snapshot.docs.isEmpty) {
        developer.log('❌ Collection is completely empty!');
        return _getFallbackArticles();
      }

      final List<EducationContentModel> articles = [];
      
      for (var doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        developer.log('📄 Processing document ${doc.id}: ${data.keys.toList()}');
        
        // Enhanced data extraction with better fallbacks
        final title = data['title'] ?? data['name'] ?? 'Untitled Article';
        final description = data['summary'] ?? data['description'] ?? data['content'] ?? 'No description available';
        final category = data['category'] ?? 'general_security';
        
        final article = EducationContentModel(
          id: doc.id,
          title: title,
          description: description,
          type: _getContentTypeFromFirestore(data['contentType'] ?? data['type']),
          difficulty: _getDifficultyFromFirestore(data['difficulty']),
          estimatedMinutes: (data['estimatedReadTime'] ?? data['readTime'] ?? 5).toInt(),
          imageUrl: _getCategoryImageUrl(category),
          tags: _extractTags(data),
          viewCount: (data['views'] ?? data['viewCount'] ?? 0).toInt(),
          publishedDate: _extractDate(data),
          category: category,
          author: data['createdBy'] ?? data['author'] ?? 'DICT Admin',
          isPinned: data['isPinned'] == true,
        );
        
        articles.add(article);
        developer.log('✅ Added article for View All: ${article.title} (${article.category})');
      }

      developer.log('✅ Retrieved ${articles.length} articles for View All screen');
      
      if (articles.isEmpty) {
        developer.log('❌ No articles found for View All, using fallback content');
        return _getFallbackArticles();
      }
      
      return articles;
      
    } catch (error) {
      developer.log('❌ Error fetching all articles: $error');
      developer.log('❌ Error type: ${error.runtimeType}');
      developer.log('❌ Using fallback content for View All...');
      return _getFallbackArticles();
    }
  }

  /// Increment view count for analytics
  void _incrementViewCount(String articleId) {
    firestore.collection('educational_content')
        .doc(articleId)
        .update({
      'views': FieldValue.increment(1),
      'lastViewed': FieldValue.serverTimestamp(),
    }).catchError((error) {
      developer.log('❌ Error incrementing view count: $error');
    });
  }

  /// Convert Firestore contentType to mobile ContentType enum
  ContentType _getContentTypeFromFirestore(String? contentType) {
    switch (contentType) {
      case 'guide':
        return ContentType.article;
      case 'tip':
        return ContentType.video; // Use video icon for tips
      case 'warning':
        return ContentType.infographic; // Use infographic icon for warnings
      case 'checklist':
        return ContentType.quiz; // Use quiz icon for checklists
      default:
        return ContentType.article;
    }
  }

  /// Convert Firestore difficulty to mobile DifficultyLevel enum
  DifficultyLevel _getDifficultyFromFirestore(String? difficulty) {
    switch (difficulty) {
      case 'beginner':
        return DifficultyLevel.beginner;
      case 'intermediate':
        return DifficultyLevel.intermediate;
      case 'advanced':
        return DifficultyLevel.advanced;
      default:
        return DifficultyLevel.beginner;
    }
  }

  /// Get appropriate image for category
  String _getCategoryImageUrl(String? category) {
    switch (category) {
      case 'evil_twins':
        return 'assets/images/image2.png';
      case 'wifi_security':
      case 'public_safety':
        return 'assets/images/image1.png';
      default:
        return 'assets/images/image1.png';
    }
  }

  /// Fallback articles when Firestore is unavailable
  List<EducationContentModel> _getFallbackArticles() {
    return [
      EducationContentModel(
        id: 'fallback_1',
        title: 'Understanding WiFi Security',
        description: 'Learn the basics of securing your wireless connections',
        type: ContentType.article,
        difficulty: DifficultyLevel.beginner,
        estimatedMinutes: 5,
        imageUrl: 'assets/images/image1.png',
        tags: ['security', 'wifi'],
        viewCount: 0,
        publishedDate: DateTime.now(),
        category: 'wifi_security',
        author: 'DICT Admin',
        isPinned: false,
      ),
      EducationContentModel(
        id: 'fallback_2',
        title: 'Spotting Evil Twin Attacks',
        description: 'How to identify and avoid malicious WiFi networks',
        type: ContentType.article,
        difficulty: DifficultyLevel.intermediate,
        estimatedMinutes: 8,
        imageUrl: 'assets/images/image2.png',
        tags: ['evil-twin', 'security'],
        viewCount: 0,
        publishedDate: DateTime.now(),
        category: 'evil_twins',
        author: 'DICT Admin',
        isPinned: true,
      ),
    ];
  }
}