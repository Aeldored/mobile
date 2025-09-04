import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/quiz_history_model.dart';
import '../../../data/services/quiz_history_service.dart';

class QuizHistoryScreen extends StatefulWidget {
  final QuizHistoryService historyService;

  const QuizHistoryScreen({
    super.key,
    required this.historyService,
  });

  @override
  State<QuizHistoryScreen> createState() => _QuizHistoryScreenState();
}

class _QuizHistoryScreenState extends State<QuizHistoryScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  String _searchQuery = '';
  String? _filterPerformance;
  int _selectedTimeRange = 30; // Last 30 days
  bool _isSearchVisible = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _scrollController.addListener(_handleScroll);
  }

  void _handleScroll() {
    const double threshold = 100.0;
    final bool shouldHide = _scrollController.offset > threshold;
    
    if (shouldHide != !_isSearchVisible) {
      setState(() {
        _isSearchVisible = !shouldHide;
      });
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Quiz History'),
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
              'Track your learning progress and performance',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ),
          
          // Search and filter bar
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _isSearchVisible ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _isSearchVisible ? 1.0 : 0.0,
              child: _buildSearchAndFilterBar(),
            ),
          ),
          
          // Tabs with gradient background and subtle shadow
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
              labelColor: AppColors.primary,
              unselectedLabelColor: Colors.grey[600],
              indicatorColor: AppColors.primary,
              dividerColor: Colors.transparent, // Remove divider line
              tabs: const [
                Tab(text: 'Recent', icon: Icon(Icons.history, size: 20)),
                Tab(text: 'Statistics', icon: Icon(Icons.analytics, size: 20)),
                Tab(text: 'Analysis', icon: Icon(Icons.insights, size: 20)),
              ],
            ),
          ),
          
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildRecentTab(),
                _buildStatisticsTab(),
                _buildAnalysisTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showHistorySettings,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        child: const Icon(Icons.settings),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
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
            onChanged: (value) => setState(() => _searchQuery = value),
            decoration: InputDecoration(
              hintText: 'Search quiz sessions...',
              prefixIcon: const Icon(Icons.search, color: AppColors.gray),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: AppColors.gray),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
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
          
          const SizedBox(height: 12),
          
          // Filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Last 7 days', _selectedTimeRange == 7, () => setState(() => _selectedTimeRange = 7)),
                const SizedBox(width: 8),
                _buildFilterChip('Last 30 days', _selectedTimeRange == 30, () => setState(() => _selectedTimeRange = 30)),
                const SizedBox(width: 8),
                _buildFilterChip('Last 90 days', _selectedTimeRange == 90, () => setState(() => _selectedTimeRange = 90)),
                const SizedBox(width: 8),
                _buildFilterChip('Excellent', _filterPerformance == 'Excellent', () => setState(() => _filterPerformance = _filterPerformance == 'Excellent' ? null : 'Excellent')),
                const SizedBox(width: 8),
                _buildFilterChip('Good', _filterPerformance == 'Good', () => setState(() => _filterPerformance = _filterPerformance == 'Good' ? null : 'Good')),
                const SizedBox(width: 8),
                _buildFilterChip('Needs Work', _filterPerformance == 'Needs Work', () => setState(() => _filterPerformance = _filterPerformance == 'Needs Work' ? null : 'Needs Work')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isSelected, VoidCallback onTap) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (_) => onTap(),
      selectedColor: AppColors.primary.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primary,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.primary : Colors.grey[700],
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
    );
  }

  Widget _buildRecentTab() {
    final filteredSessions = _getFilteredSessions();
    
    if (filteredSessions.isEmpty) {
      return _buildEmptyState();
    }

    return RefreshIndicator(
      onRefresh: () async {
        setState(() {});
      },
      child: ListView.separated(
        controller: _scrollController,
        padding: const EdgeInsets.all(16),
        itemCount: filteredSessions.length,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final session = filteredSessions[index];
          return _buildSessionCard(session);
        },
      ),
    );
  }

  Widget _buildStatisticsTab() {
    final stats = widget.historyService.getStats();
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overview cards
          Row(
            children: [
              Expanded(child: _buildStatCard('Total Quizzes', '${stats.totalQuizzesTaken}', Icons.quiz, Colors.blue)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Best Score', stats.formattedBestScore, Icons.star, Colors.amber)),
            ],
          ),
          
          const SizedBox(height: 12),
          
          Row(
            children: [
              Expanded(child: _buildStatCard('Average Score', stats.formattedAverageScore, Icons.trending_up, Colors.green)),
              const SizedBox(width: 12),
              Expanded(child: _buildStatCard('Accuracy Rate', stats.accuracyRate, Icons.check_circle, Colors.blue)),
            ],
          ),
          
          const SizedBox(height: 24),
          
          // Detailed statistics
          _buildDetailedStatistics(stats),
        ],
      ),
    );
  }

  Widget _buildAnalysisTab() {
    final stats = widget.historyService.getStats();
    final sessions = widget.historyService.sessions;
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Progress trends
          _buildProgressTrends(sessions),
          
          const SizedBox(height: 24),
          
          // Strengths and areas for improvement
          _buildPerformanceAnalysis(stats),
          
          const SizedBox(height: 24),
          
          // Study recommendations
          _buildStudyRecommendations(stats),
        ],
      ),
    );
  }

  Widget _buildSessionCard(QuizSession session) {
    Color scoreColor;
    IconData scoreIcon;
    
    if (session.percentage >= 80) {
      scoreColor = Colors.green;
      scoreIcon = Icons.check_circle;
    } else if (session.percentage >= 60) {
      scoreColor = Colors.orange;
      scoreIcon = Icons.info;
    } else {
      scoreColor = Colors.red;
      scoreIcon = Icons.warning;
    }

    return Card(
      elevation: 2,
      child: InkWell(
        onTap: () => _showSessionDetails(session),
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: scoreColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(scoreIcon, color: scoreColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Wi-Fi Security Quiz',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                        Text(
                          DateFormat('MMM dd, yyyy • HH:mm').format(session.completedAt),
                          style: TextStyle(color: Colors.grey[600], fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${session.percentage.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: scoreColor,
                        ),
                      ),
                      Text(
                        session.performanceLevel,
                        style: TextStyle(
                          color: scoreColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Statistics
              Row(
                children: [
                  _buildMiniStat(Icons.check, '${session.correctAnswers}', 'Correct'),
                  const SizedBox(width: 24),
                  _buildMiniStat(Icons.close, '${session.incorrectAnswers}', 'Incorrect'),
                  const SizedBox(width: 24),
                  _buildMiniStat(Icons.timer, '${session.timeTaken.inMinutes}m ${session.timeTaken.inSeconds % 60}s', 'Time'),
                  const Spacer(),
                  Text(
                    '${session.score}/${session.totalQuestions}',
                    style: TextStyle(
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(IconData icon, String value, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 4),
        Column(
          children: [
            Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
            Text(label, style: TextStyle(color: Colors.grey[600], fontSize: 10)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12), textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailedStatistics(QuizStats stats) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Detailed Statistics', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _buildStatRow('Total Time Played', stats.formattedTotalTime),
                const Divider(),
                _buildStatRow('Average Time Per Quiz', stats.formattedAverageTime),
                const Divider(),
                _buildStatRow('Current Streak', '${stats.currentStreak} quiz${stats.currentStreak != 1 ? 'es' : ''}'),
                const Divider(),
                _buildStatRow('Longest Streak', '${stats.longestStreak} quiz${stats.longestStreak != 1 ? 'es' : ''}'),
                const Divider(),
                _buildStatRow('Worst Score', stats.formattedWorstScore),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[700])),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildProgressTrends(List<QuizSession> sessions) {
    if (sessions.length < 2) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Take more quizzes to see progress trends'),
        ),
      );
    }

    final recentSessions = sessions.take(10).toList().reversed.toList();
    final isImproving = _calculateTrend(recentSessions);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Progress Trends', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            
            Row(
              children: [
                Icon(
                  isImproving ? Icons.trending_up : Icons.trending_down,
                  color: isImproving ? Colors.green : Colors.orange,
                  size: 32,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isImproving 
                        ? 'Great job! Your scores are improving over time.'
                        : 'Consider reviewing the material to improve your scores.',
                    style: TextStyle(
                      color: isImproving ? Colors.green[700] : Colors.orange[700],
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceAnalysis(QuizStats stats) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Performance Analysis', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            
            ...stats.performanceLevels.entries.map((entry) {
              final percentage = entry.value / stats.totalQuizzesTaken * 100;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: Text(entry.key),
                    ),
                    Expanded(
                      flex: 3,
                      child: LinearProgressIndicator(
                        value: percentage / 100,
                        backgroundColor: Colors.grey[300],
                        valueColor: AlwaysStoppedAnimation<Color>(
                          entry.key == 'Excellent' ? Colors.green :
                          entry.key == 'Good' ? Colors.blue : Colors.orange,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('${percentage.toStringAsFixed(0)}%'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildStudyRecommendations(QuizStats stats) {
    List<String> recommendations = [];
    
    if (stats.averageScore < 60) {
      recommendations.add('Review basic Wi-Fi security concepts');
      recommendations.add('Focus on understanding different encryption types');
    } else if (stats.averageScore < 80) {
      recommendations.add('Study advanced security topics');
      recommendations.add('Practice identifying security threats');
    } else {
      recommendations.add('Explore emerging cybersecurity trends');
      recommendations.add('Share your knowledge with others');
    }

    if (stats.currentStreak == 0) {
      recommendations.add('Take quizzes regularly to build knowledge retention');
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.amber[700]),
                const SizedBox(width: 8),
                Text('Study Recommendations', style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 16),
            
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_outline, color: AppColors.primary, size: 16),
                  const SizedBox(width: 8),
                  Expanded(child: Text(rec)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.quiz_outlined, size: 64, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text('No quiz history yet', style: TextStyle(fontSize: 18, color: Colors.grey[600])),
          const SizedBox(height: 8),
          Text('Take your first quiz to start tracking your progress!', 
            style: TextStyle(color: Colors.grey[500]), textAlign: TextAlign.center),
        ],
      ),
    );
  }

  List<QuizSession> _getFilteredSessions() {
    var filtered = widget.historyService.getRecentSessions(_selectedTimeRange);
    
    // Filter by performance level
    if (_filterPerformance != null) {
      filtered = filtered.where((session) => session.performanceLevel == _filterPerformance).toList();
    }
    
    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      // For now, we can search by date or performance level
      filtered = filtered.where((session) {
        return session.performanceLevel.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               DateFormat('MMM dd, yyyy').format(session.completedAt).toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    return filtered;
  }

  bool _calculateTrend(List<QuizSession> sessions) {
    if (sessions.length < 3) return true;
    
    final recent = sessions.take(5).map((s) => s.percentage).toList();
    final older = sessions.skip(sessions.length > 8 ? sessions.length - 5 : sessions.length ~/ 2).map((s) => s.percentage).toList();
    
    final recentAvg = recent.reduce((a, b) => a + b) / recent.length;
    final olderAvg = older.reduce((a, b) => a + b) / older.length;
    
    return recentAvg > olderAvg;
  }

  void _showSessionDetails(QuizSession session) {
    showDialog(
      context: context,
      builder: (context) => SessionDetailsDialog(session: session),
    );
  }

  void _showHistorySettings() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _HistorySettingsBottomSheet(
        onShowExportOptions: () => _showExportOptions(context),
        onClearHistory: () async {
          final navigator = Navigator.of(context);
          final scaffoldMessenger = ScaffoldMessenger.of(context);
          
          try {
            navigator.pop();
            await widget.historyService.clearHistory();
            setState(() {});
            
            scaffoldMessenger.showSnackBar(
              const SnackBar(
                content: Text('Quiz history cleared successfully'),
                backgroundColor: AppColors.success,
              ),
            );
          } catch (e) {
            scaffoldMessenger.showSnackBar(
              SnackBar(
                content: Text('Failed to clear history: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
      ),
    );
  }

  void _showExportOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            
            Text('Export Format', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            
            ListTile(
              leading: const Icon(Icons.summarize, color: AppColors.primary),
              title: const Text('Summary Report'),
              subtitle: const Text('Human-readable summary with insights and recommendations'),
              onTap: () {
                Navigator.pop(context);
                widget.historyService.sessions.isNotEmpty
                    ? _exportHistory('summary')
                    : _showNoDataError();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.table_chart, color: Colors.green),
              title: const Text('CSV Spreadsheet'),
              subtitle: const Text('Open in Excel, Google Sheets, or other spreadsheet apps'),
              onTap: () {
                Navigator.pop(context);
                widget.historyService.sessions.isNotEmpty
                    ? _exportHistory('csv')
                    : _showNoDataError();
              },
            ),
            
            ListTile(
              leading: const Icon(Icons.code, color: Colors.blue),
              title: const Text('JSON Data'),
              subtitle: const Text('Raw data for developers and advanced users'),
              onTap: () {
                Navigator.pop(context);
                widget.historyService.sessions.isNotEmpty
                    ? _exportHistory('json')
                    : _showNoDataError();
              },
            ),
            
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  void _exportHistory(String format) async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    try {
      String exportData;
      String fileName;
      final timestamp = DateFormat('yyyy-MM-dd_HH-mm-ss').format(DateTime.now());
      
      switch (format.toLowerCase()) {
        case 'csv':
          exportData = widget.historyService.exportHistoryAsCsv();
          fileName = 'disconx_quiz_history_$timestamp.csv';
          break;
        case 'summary':
          exportData = widget.historyService.exportSummaryReport();
          fileName = 'disconx_quiz_summary_$timestamp.txt';
          break;
        default: // json
          exportData = widget.historyService.exportHistoryAsJson();
          fileName = 'disconx_quiz_history_$timestamp.json';
          break;
      }
      
      if (exportData.isEmpty || (format == 'json' && exportData == '{}')) {
        throw Exception('No quiz history data to export');
      }

      // Try file sharing first, fallback to dialog on error
      try {
        await _shareAsFile(exportData, fileName, format);
        scaffoldMessenger.showSnackBar(
          SnackBar(
            content: Text('Quiz history exported successfully as ${format.toUpperCase()}'),
            backgroundColor: AppColors.success,
          ),
        );
      } catch (shareError) {
        // Fallback to showing data in dialog
        _showExportDialog(exportData, fileName, format);
      }
      
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(
          content: Text('Failed to export history: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _shareAsFile(String data, String fileName, String format) async {
    // Get temporary directory and write file
    final tempDir = await getTemporaryDirectory();
    final file = File('${tempDir.path}/$fileName');
    await file.writeAsString(data);
    
    // Verify file was created
    if (!await file.exists()) {
      throw Exception('Failed to create export file');
    }
    
    // Share the file
    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'DisConX Quiz History Export (${format.toUpperCase()}) - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
      subject: 'DisConX Quiz History',
    );
  }

  void _showExportDialog(String data, String fileName, String format) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.file_download, color: AppColors.primary),
            const SizedBox(width: 8),
            Text('Export ${format.toUpperCase()}'),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'File sharing is not available. Here\'s your data:',
                style: TextStyle(color: Colors.grey[600]),
              ),
              const SizedBox(height: 8),
              Text(
                'Filename: $fileName',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: SingleChildScrollView(
                    child: SelectableText(
                      data,
                      style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: data));
              if (!mounted) return;
              Navigator.pop(context);
              if (!mounted) return;
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Data copied to clipboard'),
                  backgroundColor: AppColors.success,
                ),
              );
            },
            child: const Text('Copy to Clipboard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showNoDataError() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('No quiz history data to export'),
        backgroundColor: Colors.orange,
      ),
    );
  }

  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.quiz, color: AppColors.primary),
            SizedBox(width: 8),
            Text('About Quiz History'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Quiz History tracks your learning progress and performance over time.',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
              const SizedBox(height: 16),
              
              const Text('How it works:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('• Every quiz session is automatically saved'),
              const Text('• Track scores, time taken, and detailed results'),
              const Text('• View performance trends and analytics'),
              const Text('• Get personalized study recommendations'),
              
              const SizedBox(height: 16),
              
              const Text('Features:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Text('• Recent: View your latest quiz sessions'),
              const Text('• Statistics: Overall performance metrics'),
              const Text('• Analysis: Progress trends and recommendations'),
              const Text('• Search & Filter: Find specific sessions'),
              const Text('• Export: Save your history as JSON file'),
              
              const SizedBox(height: 16),
              
              const Text('Performance Levels:', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.star, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text('Excellent: 80-100%'),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.thumb_up, color: Colors.blue, size: 16),
                  SizedBox(width: 4),
                  Text('Good: 60-79%'),
                ],
              ),
              const Row(
                children: [
                  Icon(Icons.trending_up, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text('Needs Work: Below 60%'),
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
                        Icon(Icons.lightbulb, color: AppColors.primary, size: 16),
                        SizedBox(width: 4),
                        Text('Tips:', style: TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    SizedBox(height: 4),
                    Text('• Take quizzes regularly to build streaks'),
                    Text('• Review wrong answers for better learning'),
                    Text('• Use the analysis tab for study guidance'),
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

class SessionDetailsDialog extends StatelessWidget {
  final QuizSession session;

  const SessionDetailsDialog({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Quiz Session Details'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Date: ${DateFormat('MMM dd, yyyy • HH:mm:ss').format(session.completedAt)}'),
            Text('Score: ${session.score}/${session.totalQuestions} (${session.percentage.toStringAsFixed(1)}%)'),
            Text('Performance: ${session.performanceLevel}'),
            Text('Time Taken: ${session.timeTaken.inMinutes}m ${session.timeTaken.inSeconds % 60}s'),
            const SizedBox(height: 16),
            Text('Question Breakdown:', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            ...session.questionResults.asMap().entries.map((entry) {
              final index = entry.key;
              final result = entry.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    Icon(
                      result.isCorrect ? Icons.check_circle : Icons.cancel,
                      color: result.isCorrect ? Colors.green : Colors.red,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Text('Q${index + 1}'),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}

class _HistorySettingsBottomSheet extends StatelessWidget {
  final VoidCallback onClearHistory;
  final VoidCallback onShowExportOptions;

  const _HistorySettingsBottomSheet({
    required this.onClearHistory,
    required this.onShowExportOptions,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 16),
          
          Text('History Settings', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          
          ListTile(
            leading: const Icon(Icons.file_download, color: AppColors.primary),
            title: const Text('Export History'),
            subtitle: const Text('Choose export format'),
            onTap: () {
              Navigator.pop(context);
              onShowExportOptions();
            },
          ),
          
          ListTile(
            leading: Icon(Icons.delete, color: Colors.red[600]),
            title: Text('Clear History', style: TextStyle(color: Colors.red[700])),
            subtitle: const Text('Delete all quiz history data'),
            onTap: () => _showClearConfirmation(context),
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  void _showClearConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear Quiz History'),
        content: const Text('Are you sure you want to delete all quiz history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              onClearHistory();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Clear History'),
          ),
        ],
      ),
    );
  }
}