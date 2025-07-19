import 'package:flutter/material.dart';

enum ContentType { article, video, quiz, infographic }

enum DifficultyLevel { beginner, intermediate, advanced }

class EducationContentModel {
  final String id;
  final String title;
  final String description;
  final ContentType type;
  final DifficultyLevel difficulty;
  final int estimatedMinutes;
  final String? imageUrl;
  final String? contentUrl;
  final List<String> tags;
  final int viewCount;
  final DateTime publishedDate;
  final bool isCompleted;
  final double? progress;

  EducationContentModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.estimatedMinutes,
    this.imageUrl,
    this.contentUrl,
    required this.tags,
    this.viewCount = 0,
    required this.publishedDate,
    this.isCompleted = false,
    this.progress,
  });

  String get typeString {
    switch (type) {
      case ContentType.article:
        return 'Article';
      case ContentType.video:
        return 'Video';
      case ContentType.quiz:
        return 'Quiz';
      case ContentType.infographic:
        return 'Infographic';
    }
  }

  String get difficultyString {
    switch (difficulty) {
      case DifficultyLevel.beginner:
        return 'Beginner';
      case DifficultyLevel.intermediate:
        return 'Intermediate';
      case DifficultyLevel.advanced:
        return 'Advanced';
    }
  }

  factory EducationContentModel.fromJson(Map<String, dynamic> json) {
    return EducationContentModel(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: ContentType.values.firstWhere(
        (e) => e.toString() == 'ContentType.${json['type']}',
      ),
      difficulty: DifficultyLevel.values.firstWhere(
        (e) => e.toString() == 'DifficultyLevel.${json['difficulty']}',
      ),
      estimatedMinutes: json['estimatedMinutes'],
      imageUrl: json['imageUrl'],
      contentUrl: json['contentUrl'],
      tags: List<String>.from(json['tags'] ?? []),
      viewCount: json['viewCount'] ?? 0,
      publishedDate: DateTime.parse(json['publishedDate']),
      isCompleted: json['isCompleted'] ?? false,
      progress: json['progress']?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type.toString().split('.').last,
      'difficulty': difficulty.toString().split('.').last,
      'estimatedMinutes': estimatedMinutes,
      'imageUrl': imageUrl,
      'contentUrl': contentUrl,
      'tags': tags,
      'viewCount': viewCount,
      'publishedDate': publishedDate.toIso8601String(),
      'isCompleted': isCompleted,
      'progress': progress,
    };
  }
}

class QuizQuestion {
  final String id;
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String? explanation;

  QuizQuestion({
    required this.id,
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    this.explanation,
  });

  factory QuizQuestion.fromJson(Map<String, dynamic> json) {
    return QuizQuestion(
      id: json['id'],
      question: json['question'],
      options: List<String>.from(json['options']),
      correctAnswerIndex: json['correctAnswerIndex'],
      explanation: json['explanation'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'question': question,
      'options': options,
      'correctAnswerIndex': correctAnswerIndex,
      'explanation': explanation,
    };
  }
}

class SecurityTip {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color backgroundColor;

  SecurityTip({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.backgroundColor,
  });
}