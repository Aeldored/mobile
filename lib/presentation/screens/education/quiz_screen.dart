import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../main_screen.dart';

class QuizQuestion {
  final String question;
  final List<String> options;
  final int correctAnswerIndex;
  final String explanation;

  QuizQuestion({
    required this.question,
    required this.options,
    required this.correctAnswerIndex,
    required this.explanation,
  });
}

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key});

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  int _currentQuestionIndex = 0;
  int _selectedAnswerIndex = -1;
  int _score = 0;
  bool _hasAnswered = false;
  bool _quizCompleted = false;

  Future<bool> _onWillPop() async {
    // Navigate back to home instead of exiting the app
    Navigator.of(context).popUntil((route) => route.isFirst);
    MainScreen.navigateToTab(context, 0);
    return false;
  }

  final List<QuizQuestion> _questions = [
    QuizQuestion(
      question: "What is an 'Evil Twin' Wi-Fi attack?",
      options: [
        "A virus that infects twin computers",
        "A fake Wi-Fi hotspot that mimics a legitimate network",
        "Two routers with the same password",
        "A network that only allows two devices"
      ],
      correctAnswerIndex: 1,
      explanation: "An Evil Twin attack involves creating a malicious Wi-Fi hotspot that appears to be a legitimate network to steal user data.",
    ),
    QuizQuestion(
      question: "Which of these is the BEST practice when connecting to public Wi-Fi?",
      options: [
        "Always use a VPN",
        "Only connect to networks with strong passwords",
        "Turn off auto-connect features",
        "All of the above"
      ],
      correctAnswerIndex: 3,
      explanation: "All these practices are essential for public Wi-Fi security - using VPNs, avoiding weak networks, and controlling auto-connections.",
    ),
    QuizQuestion(
      question: "What should you verify before connecting to a public Wi-Fi network?",
      options: [
        "The network name with venue staff",
        "That it requires a password",
        "The signal strength",
        "The number of connected devices"
      ],
      correctAnswerIndex: 0,
      explanation: "Always verify the legitimate network name with venue staff to avoid connecting to malicious Evil Twin networks.",
    ),
    QuizQuestion(
      question: "Which type of website should you AVOID accessing on public Wi-Fi?",
      options: [
        "News websites",
        "Banking and financial sites",
        "Social media platforms",
        "Weather websites"
      ],
      correctAnswerIndex: 1,
      explanation: "Banking and financial sites contain sensitive information that could be intercepted on unsecured public networks.",
    ),
    QuizQuestion(
      question: "What does WPA3 provide for Wi-Fi security?",
      options: [
        "Faster internet speeds",
        "Enhanced encryption and protection",
        "Better signal range",
        "Automatic network switching"
      ],
      correctAnswerIndex: 1,
      explanation: "WPA3 is the latest Wi-Fi security protocol providing stronger encryption and better protection against attacks.",
    ),
    QuizQuestion(
      question: "How can you identify a suspicious Wi-Fi network?",
      options: [
        "Generic names like 'Free_WiFi'",
        "Multiple networks with similar names",
        "Networks without passwords in public places",
        "All of the above"
      ],
      correctAnswerIndex: 3,
      explanation: "Suspicious networks often have generic names, duplicate names, or lack proper security in public areas.",
    ),
    QuizQuestion(
      question: "What should you do if you suspect you've connected to an Evil Twin network?",
      options: [
        "Continue browsing but avoid sensitive sites",
        "Disconnect immediately and change passwords",
        "Turn off Wi-Fi for a few minutes",
        "Switch to mobile data only"
      ],
      correctAnswerIndex: 1,
      explanation: "Immediately disconnect and change passwords for any accounts accessed, as your data may have been compromised.",
    ),
    QuizQuestion(
      question: "Which government agency in the Philippines handles cybersecurity guidelines?",
      options: [
        "DOT (Department of Tourism)",
        "DICT (Department of Information and Communications Technology)",
        "DTI (Department of Trade and Industry)",
        "DOF (Department of Finance)"
      ],
      correctAnswerIndex: 1,
      explanation: "DICT is responsible for ICT development and cybersecurity policies in the Philippines.",
    ),
    QuizQuestion(
      question: "What is the purpose of MAC address filtering in Wi-Fi security?",
      options: [
        "To block specific device types",
        "To allow only authorized devices to connect",
        "To improve internet speed",
        "To reduce network interference"
      ],
      correctAnswerIndex: 1,
      explanation: "MAC address filtering allows network administrators to control which devices can connect to the network.",
    ),
    QuizQuestion(
      question: "When using public Wi-Fi, you should avoid:",
      options: [
        "Checking email",
        "Online banking and shopping",
        "Reading news articles",
        "Watching videos"
      ],
      correctAnswerIndex: 1,
      explanation: "Avoid activities involving sensitive personal or financial information on public Wi-Fi networks due to security risks.",
    ),
  ];

  void _selectAnswer(int answerIndex) {
    if (_hasAnswered) return;

    setState(() {
      _selectedAnswerIndex = answerIndex;
      _hasAnswered = true;
      
      if (answerIndex == _questions[_currentQuestionIndex].correctAnswerIndex) {
        _score++;
      }
    });
  }

  void _nextQuestion() {
    setState(() {
      if (_currentQuestionIndex < _questions.length - 1) {
        _currentQuestionIndex++;
        _selectedAnswerIndex = -1;
        _hasAnswered = false;
      } else {
        _quizCompleted = true;
      }
    });
  }

  void _restartQuiz() {
    setState(() {
      _currentQuestionIndex = 0;
      _selectedAnswerIndex = -1;
      _score = 0;
      _hasAnswered = false;
      _quizCompleted = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_quizCompleted) {
      return _buildResultsScreen();
    }

    final currentQuestion = _questions[_currentQuestionIndex];
    final progress = (_currentQuestionIndex + 1) / _questions.length;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Wi-Fi Security Quiz'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      body: Column(
        children: [
          // Progress indicator
          Container(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Question ${_currentQuestionIndex + 1} of ${_questions.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      'Score: $_score',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: progress,
                  backgroundColor: Colors.grey[300],
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ],
            ),
          ),

          // Question and answers
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Question
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
                    ),
                    child: Text(
                      currentQuestion.question,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Answer options
                  ...List.generate(currentQuestion.options.length, (index) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _buildAnswerOption(
                        index,
                        currentQuestion.options[index],
                        currentQuestion.correctAnswerIndex,
                      ),
                    );
                  }),

                  // Explanation (shown after answering)
                  if (_hasAnswered) ...[
                    const SizedBox(height: 24),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                            ? Colors.green[50]
                            : Colors.red[50],
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                              ? Colors.green[300]!
                              : Colors.red[300]!,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                    ? Icons.check_circle
                                    : Icons.cancel,
                                color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                    ? Colors.green[600]
                                    : Colors.red[600],
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                    ? 'Correct!'
                                    : 'Incorrect',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: _selectedAnswerIndex == currentQuestion.correctAnswerIndex
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            currentQuestion.explanation,
                            style: TextStyle(
                              color: Colors.grey[700],
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Next button
          if (_hasAnswered)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              child: ElevatedButton(
                onPressed: _nextQuestion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  _currentQuestionIndex < _questions.length - 1 ? 'Next Question' : 'View Results',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
            ),
        ],
      ),
    ),
    );
  }

  Widget _buildAnswerOption(int index, String option, int correctIndex) {
    Color? backgroundColor;
    Color? borderColor;
    Color? textColor;

    if (_hasAnswered) {
      if (index == correctIndex) {
        backgroundColor = Colors.green[100];
        borderColor = Colors.green[400];
        textColor = Colors.green[800];
      } else if (index == _selectedAnswerIndex) {
        backgroundColor = Colors.red[100];
        borderColor = Colors.red[400];
        textColor = Colors.red[800];
      }
    } else if (_selectedAnswerIndex == index) {
      backgroundColor = AppColors.primary.withValues(alpha: 0.1);
      borderColor = AppColors.primary;
    }

    return GestureDetector(
      onTap: () => _selectAnswer(index),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor ?? Colors.white,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: borderColor ?? Colors.grey[300]!,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: backgroundColor ?? Colors.transparent,
                border: Border.all(
                  color: borderColor ?? Colors.grey[400]!,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(
                  String.fromCharCode(65 + index), // A, B, C, D
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: textColor ?? Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                option,
                style: TextStyle(
                  fontSize: 16,
                  color: textColor ?? Colors.black87,
                  fontWeight: _hasAnswered && index == correctIndex 
                      ? FontWeight.w600 
                      : FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsScreen() {
    final percentage = (_score / _questions.length * 100).round();
    String resultMessage;
    Color resultColor;
    IconData resultIcon;

    if (percentage >= 80) {
      resultMessage = "Excellent! You're well-versed in Wi-Fi security.";
      resultColor = Colors.green;
      resultIcon = Icons.emoji_events;
    } else if (percentage >= 60) {
      resultMessage = "Good job! You have a solid understanding of Wi-Fi security.";
      resultColor = Colors.blue;
      resultIcon = Icons.thumb_up;
    } else {
      resultMessage = "Keep learning! Review the educational materials to improve your Wi-Fi security knowledge.";
      resultColor = Colors.orange;
      resultIcon = Icons.school;
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (!didPop) {
          await _onWillPop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Quiz Results'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              resultIcon,
              size: 80,
              color: resultColor,
            ),
            const SizedBox(height: 24),
            Text(
              'Quiz Complete!',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Your Score',
              style: TextStyle(
                fontSize: 18,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$_score/${_questions.length}',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.bold,
                color: resultColor,
              ),
            ),
            Text(
              '$percentage%',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: resultColor,
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: resultColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: resultColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                resultMessage,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _restartQuiz,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Retake Quiz',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      'Continue Learning',
                      style: TextStyle(fontSize: 16),
                    ),
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
}