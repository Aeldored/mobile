
class QuizSession {
  final String id;
  final DateTime completedAt;
  final int score;
  final int totalQuestions;
  final int correctAnswers;
  final int incorrectAnswers;
  final Duration timeTaken;
  final double percentage;
  final String performanceLevel;
  final List<QuestionResult> questionResults;

  QuizSession({
    required this.id,
    required this.completedAt,
    required this.score,
    required this.totalQuestions,
    required this.correctAnswers,
    required this.incorrectAnswers,
    required this.timeTaken,
    required this.percentage,
    required this.performanceLevel,
    required this.questionResults,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'completedAt': completedAt.toIso8601String(),
      'score': score,
      'totalQuestions': totalQuestions,
      'correctAnswers': correctAnswers,
      'incorrectAnswers': incorrectAnswers,
      'timeTaken': timeTaken.inSeconds,
      'percentage': percentage,
      'performanceLevel': performanceLevel,
      'questionResults': questionResults.map((q) => q.toJson()).toList(),
    };
  }

  factory QuizSession.fromJson(Map<String, dynamic> json) {
    return QuizSession(
      id: json['id'] as String,
      completedAt: DateTime.parse(json['completedAt'] as String),
      score: json['score'] as int,
      totalQuestions: json['totalQuestions'] as int,
      correctAnswers: json['correctAnswers'] as int,
      incorrectAnswers: json['incorrectAnswers'] as int,
      timeTaken: Duration(seconds: json['timeTaken'] as int),
      percentage: (json['percentage'] as num).toDouble(),
      performanceLevel: json['performanceLevel'] as String,
      questionResults: (json['questionResults'] as List<dynamic>)
          .map((q) => QuestionResult.fromJson(q as Map<String, dynamic>))
          .toList(),
    );
  }
}

class QuestionResult {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final int selectedAnswerIndex;
  final bool isCorrect;
  final String explanation;

  QuestionResult({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.selectedAnswerIndex,
    required this.isCorrect,
    required this.explanation,
  });

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'selectedAnswerIndex': selectedAnswerIndex,
      'isCorrect': isCorrect,
      'explanation': explanation,
    };
  }

  factory QuestionResult.fromJson(Map<String, dynamic> json) {
    return QuestionResult(
      question: json['question'] as String,
      options: List<String>.from(json['options']),
      correctAnswerIndex: json['correctAnswerIndex'] as int,
      selectedAnswerIndex: json['selectedAnswerIndex'] as int,
      isCorrect: json['isCorrect'] as bool,
      explanation: json['explanation'] as String,
    );
  }
}

class QuizStats {
  final int totalQuizzesTaken;
  final int totalCorrectAnswers;
  final int totalQuestions;
  final double averageScore;
  final double bestScore;
  final double worstScore;
  final Duration totalTimePlayed;
  final Duration averageTimePerQuiz;
  final Map<String, int> performanceLevels;
  final DateTime? lastQuizDate;
  final DateTime? firstQuizDate;
  final List<double> recentScores;
  final int currentStreak;
  final int longestStreak;

  QuizStats({
    required this.totalQuizzesTaken,
    required this.totalCorrectAnswers,
    required this.totalQuestions,
    required this.averageScore,
    required this.bestScore,
    required this.worstScore,
    required this.totalTimePlayed,
    required this.averageTimePerQuiz,
    required this.performanceLevels,
    this.lastQuizDate,
    this.firstQuizDate,
    required this.recentScores,
    required this.currentStreak,
    required this.longestStreak,
  });

  String get formattedAverageScore => '${averageScore.toStringAsFixed(1)}%';
  String get formattedBestScore => '${bestScore.toStringAsFixed(1)}%';
  String get formattedWorstScore => '${worstScore.toStringAsFixed(1)}%';
  String get accuracyRate => totalQuestions > 0 
      ? '${(totalCorrectAnswers / totalQuestions * 100).toStringAsFixed(1)}%'
      : '0%';
  
  String get formattedTotalTime {
    final hours = totalTimePlayed.inHours;
    final minutes = totalTimePlayed.inMinutes % 60;
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    }
    return '${minutes}m';
  }

  String get formattedAverageTime {
    final minutes = averageTimePerQuiz.inMinutes;
    final seconds = averageTimePerQuiz.inSeconds % 60;
    return '${minutes}m ${seconds}s';
  }

  Map<String, dynamic> toJson() {
    return {
      'totalQuizzesTaken': totalQuizzesTaken,
      'totalCorrectAnswers': totalCorrectAnswers,
      'totalQuestions': totalQuestions,
      'averageScore': averageScore,
      'bestScore': bestScore,
      'worstScore': worstScore,
      'totalTimePlayed': totalTimePlayed.inSeconds,
      'averageTimePerQuiz': averageTimePerQuiz.inSeconds,
      'performanceLevels': performanceLevels,
      'lastQuizDate': lastQuizDate?.toIso8601String(),
      'firstQuizDate': firstQuizDate?.toIso8601String(),
      'recentScores': recentScores,
      'currentStreak': currentStreak,
      'longestStreak': longestStreak,
      'formattedAverageScore': formattedAverageScore,
      'formattedBestScore': formattedBestScore,
      'formattedWorstScore': formattedWorstScore,
      'accuracyRate': accuracyRate,
      'formattedTotalTime': formattedTotalTime,
      'formattedAverageTime': formattedAverageTime,
    };
  }
}