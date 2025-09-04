import 'dart:convert';
import 'dart:developer' as developer;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../models/quiz_history_model.dart';

class QuizHistoryService {
  static const String _historyKey = 'quiz_history';
  static const String _maxEntriesKey = 'quiz_history_max_entries';
  static const int _defaultMaxEntries = 50;

  late SharedPreferences _prefs;
  List<QuizSession> _sessions = [];
  int _maxEntries = _defaultMaxEntries;

  List<QuizSession> get sessions => List.unmodifiable(_sessions);
  int get maxEntries => _maxEntries;

  /// Initialize the service
  Future<void> initialize() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      _maxEntries = _prefs.getInt(_maxEntriesKey) ?? _defaultMaxEntries;
      await _loadHistory();
      developer.log('📊 QuizHistoryService initialized with ${_sessions.length} sessions');
    } catch (e) {
      developer.log('❌ Error initializing QuizHistoryService: $e');
    }
  }

  /// Add a new quiz session
  Future<void> addSession(QuizSession session) async {
    try {
      // Add to the beginning of the list (newest first)
      _sessions.insert(0, session);

      // Maintain max entries limit
      if (_sessions.length > _maxEntries) {
        _sessions = _sessions.take(_maxEntries).toList();
      }

      await _saveHistory();
      developer.log('📝 Added quiz session: ${session.score}/${session.totalQuestions} (${session.percentage.toStringAsFixed(1)}%)');
    } catch (e) {
      developer.log('❌ Error adding quiz session: $e');
    }
  }

  /// Get quiz statistics
  QuizStats getStats() {
    if (_sessions.isEmpty) {
      return QuizStats(
        totalQuizzesTaken: 0,
        totalCorrectAnswers: 0,
        totalQuestions: 0,
        averageScore: 0.0,
        bestScore: 0.0,
        worstScore: 0.0,
        totalTimePlayed: Duration.zero,
        averageTimePerQuiz: Duration.zero,
        performanceLevels: {},
        recentScores: [],
        currentStreak: 0,
        longestStreak: 0,
      );
    }

    final totalQuizzes = _sessions.length;
    final totalCorrect = _sessions.fold<int>(0, (sum, session) => sum + session.correctAnswers);
    final totalQuestions = _sessions.fold<int>(0, (sum, session) => sum + session.totalQuestions);
    final totalTime = _sessions.fold<Duration>(Duration.zero, (sum, session) => sum + session.timeTaken);

    final scores = _sessions.map((s) => s.percentage).toList();
    final averageScore = scores.reduce((a, b) => a + b) / scores.length;
    final bestScore = scores.reduce((a, b) => a > b ? a : b);
    final worstScore = scores.reduce((a, b) => a < b ? a : b);

    // Performance levels count
    final performanceLevels = <String, int>{};
    for (final session in _sessions) {
      performanceLevels[session.performanceLevel] = 
          (performanceLevels[session.performanceLevel] ?? 0) + 1;
    }

    // Recent scores (last 10 sessions)
    final recentScores = _sessions.take(10).map((s) => s.percentage).toList();

    // Calculate streaks (80% or higher)
    final currentStreak = _calculateCurrentStreak();
    final longestStreak = _calculateLongestStreak();

    return QuizStats(
      totalQuizzesTaken: totalQuizzes,
      totalCorrectAnswers: totalCorrect,
      totalQuestions: totalQuestions,
      averageScore: averageScore,
      bestScore: bestScore,
      worstScore: worstScore,
      totalTimePlayed: totalTime,
      averageTimePerQuiz: Duration(milliseconds: totalTime.inMilliseconds ~/ totalQuizzes),
      performanceLevels: performanceLevels,
      lastQuizDate: _sessions.isNotEmpty ? _sessions.first.completedAt : null,
      firstQuizDate: _sessions.isNotEmpty ? _sessions.last.completedAt : null,
      recentScores: recentScores,
      currentStreak: currentStreak,
      longestStreak: longestStreak,
    );
  }

  /// Get sessions from the last N days
  List<QuizSession> getRecentSessions(int days) {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    return _sessions.where((session) => session.completedAt.isAfter(cutoff)).toList();
  }

  /// Get sessions for a specific date range
  List<QuizSession> getSessionsInRange(DateTime start, DateTime end) {
    return _sessions.where((session) {
      return session.completedAt.isAfter(start) && session.completedAt.isBefore(end);
    }).toList();
  }

  /// Get sessions by performance level
  List<QuizSession> getSessionsByPerformance(String level) {
    return _sessions.where((session) => session.performanceLevel == level).toList();
  }

  /// Clear all history
  Future<void> clearHistory() async {
    try {
      _sessions.clear();
      await _prefs.remove(_historyKey);
      developer.log('🗑️ Quiz history cleared');
    } catch (e) {
      developer.log('❌ Error clearing quiz history: $e');
    }
  }

  /// Set maximum number of entries to keep
  Future<void> setMaxEntries(int maxEntries) async {
    try {
      _maxEntries = maxEntries;
      await _prefs.setInt(_maxEntriesKey, _maxEntries);
      
      // Trim current history if needed
      if (_sessions.length > _maxEntries) {
        _sessions = _sessions.take(_maxEntries).toList();
        await _saveHistory();
      }
      
      developer.log('📊 Max quiz history entries set to $_maxEntries');
    } catch (e) {
      developer.log('❌ Error setting max entries: $e');
    }
  }

  /// Export history as JSON string
  String exportHistoryAsJson() {
    try {
      final stats = getStats();
      final data = {
        'exportDate': DateTime.now().toIso8601String(),
        'totalSessions': _sessions.length,
        'statistics': stats.toJson(),
        'sessions': _sessions.map((session) => session.toJson()).toList(),
      };
      return jsonEncode(data);
    } catch (e) {
      developer.log('❌ Error exporting quiz history: $e');
      rethrow; // Re-throw to allow UI to handle the error properly
    }
  }

  /// Export history as CSV string
  String exportHistoryAsCsv() {
    try {
      final buffer = StringBuffer();
      
      // CSV Header
      buffer.writeln('Date,Time,Score,Total Questions,Correct Answers,Incorrect Answers,Percentage,Performance Level,Time Taken (seconds),Time Taken (formatted)');
      
      // Data rows
      for (final session in _sessions) {
        final date = DateFormat('yyyy-MM-dd').format(session.completedAt);
        final time = DateFormat('HH:mm:ss').format(session.completedAt);
        final timeTakenFormatted = '${session.timeTaken.inMinutes}m ${session.timeTaken.inSeconds % 60}s';
        
        buffer.writeln([
          date,
          time,
          session.score,
          session.totalQuestions,
          session.correctAnswers,
          session.incorrectAnswers,
          session.percentage.toStringAsFixed(1),
          '"${session.performanceLevel}"',
          session.timeTaken.inSeconds,
          '"$timeTakenFormatted"'
        ].join(','));
      }
      
      return buffer.toString();
    } catch (e) {
      developer.log('❌ Error exporting quiz history as CSV: $e');
      rethrow;
    }
  }

  /// Export summary report as text
  String exportSummaryReport() {
    try {
      final stats = getStats();
      final buffer = StringBuffer();
      
      buffer.writeln('DISCONX QUIZ HISTORY SUMMARY REPORT');
      buffer.writeln('=' * 50);
      buffer.writeln('Generated: ${DateFormat('MMM dd, yyyy • HH:mm:ss').format(DateTime.now())}');
      buffer.writeln();
      
      // Overall Statistics
      buffer.writeln('OVERALL STATISTICS');
      buffer.writeln('-' * 30);
      buffer.writeln('Total Quizzes Taken: ${stats.totalQuizzesTaken}');
      buffer.writeln('Total Questions Answered: ${stats.totalQuestions}');
      buffer.writeln('Total Correct Answers: ${stats.totalCorrectAnswers}');
      buffer.writeln('Overall Accuracy: ${stats.accuracyRate}');
      buffer.writeln('Average Score: ${stats.formattedAverageScore}');
      buffer.writeln('Best Score: ${stats.formattedBestScore}');
      buffer.writeln('Worst Score: ${stats.formattedWorstScore}');
      buffer.writeln('Total Time Spent: ${stats.formattedTotalTime}');
      buffer.writeln('Average Time Per Quiz: ${stats.formattedAverageTime}');
      buffer.writeln('Current Streak: ${stats.currentStreak} quiz${stats.currentStreak != 1 ? 'es' : ''}');
      buffer.writeln('Longest Streak: ${stats.longestStreak} quiz${stats.longestStreak != 1 ? 'es' : ''}');
      buffer.writeln();
      
      // Performance Breakdown
      buffer.writeln('PERFORMANCE BREAKDOWN');
      buffer.writeln('-' * 30);
      for (final entry in stats.performanceLevels.entries) {
        final percentage = entry.value / stats.totalQuizzesTaken * 100;
        buffer.writeln('${entry.key}: ${entry.value} quizzes (${percentage.toStringAsFixed(1)}%)');
      }
      buffer.writeln();
      
      // Recent Performance Trend
      if (stats.recentScores.isNotEmpty) {
        buffer.writeln('RECENT PERFORMANCE (Last ${stats.recentScores.length} quizzes)');
        buffer.writeln('-' * 30);
        for (int i = 0; i < stats.recentScores.length; i++) {
          buffer.writeln('Quiz ${i + 1}: ${stats.recentScores[i].toStringAsFixed(1)}%');
        }
        buffer.writeln();
      }
      
      // Study Recommendations
      buffer.writeln('STUDY RECOMMENDATIONS');
      buffer.writeln('-' * 30);
      if (stats.averageScore < 60) {
        buffer.writeln('• Review basic Wi-Fi security concepts');
        buffer.writeln('• Focus on understanding different encryption types');
        buffer.writeln('• Take quizzes more frequently to improve retention');
      } else if (stats.averageScore < 80) {
        buffer.writeln('• Study advanced security topics');
        buffer.writeln('• Practice identifying security threats');
        buffer.writeln('• Review questions you got wrong');
      } else {
        buffer.writeln('• Excellent performance! Keep it up!');
        buffer.writeln('• Explore emerging cybersecurity trends');
        buffer.writeln('• Consider sharing your knowledge with others');
      }
      
      if (stats.currentStreak == 0) {
        buffer.writeln('• Take quizzes regularly to build knowledge retention');
      }
      
      return buffer.toString();
    } catch (e) {
      developer.log('❌ Error creating summary report: $e');
      rethrow;
    }
  }

  /// Calculate current streak of good performances (80%+)
  int _calculateCurrentStreak() {
    int streak = 0;
    for (final session in _sessions) {
      if (session.percentage >= 80.0) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  /// Calculate longest streak of good performances (80%+)
  int _calculateLongestStreak() {
    int longest = 0;
    int current = 0;
    
    for (final session in _sessions.reversed) {
      if (session.percentage >= 80.0) {
        current++;
        longest = current > longest ? current : longest;
      } else {
        current = 0;
      }
    }
    return longest;
  }

  /// Load history from storage
  Future<void> _loadHistory() async {
    try {
      final historyJson = _prefs.getString(_historyKey);
      if (historyJson != null) {
        final List<dynamic> historyList = jsonDecode(historyJson);
        _sessions = historyList.map((json) => QuizSession.fromJson(json)).toList();
        
        // Sort by completion date (newest first)
        _sessions.sort((a, b) => b.completedAt.compareTo(a.completedAt));
      }
    } catch (e) {
      developer.log('❌ Error loading quiz history: $e');
      _sessions = [];
    }
  }

  /// Save history to storage
  Future<void> _saveHistory() async {
    try {
      final historyJson = jsonEncode(_sessions.map((session) => session.toJson()).toList());
      await _prefs.setString(_historyKey, historyJson);
    } catch (e) {
      developer.log('❌ Error saving quiz history: $e');
    }
  }
}