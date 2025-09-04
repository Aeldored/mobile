import 'package:flutter/material.dart';
import '../../../data/models/education_content_model.dart';
import '../../../data/services/education_content_service.dart';
import '../../../core/theme/app_colors.dart';

class ArticleReaderScreen extends StatefulWidget {
  final EducationContentModel article;

  const ArticleReaderScreen({
    super.key,
    required this.article,
  });

  @override
  State<ArticleReaderScreen> createState() => _ArticleReaderScreenState();
}

class _ArticleReaderScreenState extends State<ArticleReaderScreen> {
  final EducationContentService _educationService = EducationContentService();
  String? _fullContent;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadFullContent();
  }

  Future<void> _loadFullContent() async {
    try {
      final content = await _educationService.getArticleContent(widget.article.id);
      if (mounted) {
        setState(() {
          // Use content from Firestore, fallback to article description, or provide helpful message
          _fullContent = content ?? 
                        (widget.article.description.isNotEmpty 
                            ? widget.article.description 
                            : _generateFallbackContent());
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _fullContent = widget.article.description.isNotEmpty 
              ? widget.article.description 
              : _generateFallbackContent();
          _isLoading = false;
        });
      }
    }
  }

  String _generateFallbackContent() {
    return '''This article about "${widget.article.title}" is part of our educational content series.

${widget.article.description}

Key Topics:
${widget.article.tags.map((tag) => '• $tag').join('\n')}

Reading Time: ${widget.article.estimatedMinutes} minutes
Difficulty Level: ${widget.article.difficultyString}
Category: ${widget.article.categoryDisplayName}

For more detailed information about this topic, please check back later as we continue to expand our educational content library.

Stay safe online! 🔐''';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Article'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Show share dialog
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Share feature coming soon!'),
                  backgroundColor: AppColors.primary,
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    widget.article.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      height: 1.3,
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Metadata row
                  Row(
                    children: [
                      // Difficulty badge
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getDifficultyColor().withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          widget.article.difficulty.name.toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: _getDifficultyColor(),
                          ),
                        ),
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Reading time
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.article.estimatedMinutes} min read',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      
                      const SizedBox(width: 12),
                      
                      // Views
                      Row(
                        children: [
                          Icon(
                            Icons.visibility,
                            size: 16,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '${widget.article.viewCount}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Content
                  Text(
                    _fullContent ?? 'Content could not be loaded.',
                    style: const TextStyle(
                      fontSize: 16,
                      height: 1.6,
                      color: Colors.black87,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Tags section
                  if (widget.article.tags.isNotEmpty) ...[
                    const Text(
                      'Tags',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: widget.article.tags.map((tag) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Text(
                            '#$tag',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                  
                  const SizedBox(height: 48),
                ],
              ),
            ),
    );
  }

  Color _getDifficultyColor() {
    switch (widget.article.difficulty) {
      case DifficultyLevel.beginner:
        return Colors.green[600]!;
      case DifficultyLevel.intermediate:
        return Colors.orange[600]!;
      case DifficultyLevel.advanced:
        return Colors.red[600]!;
    }
  }
}