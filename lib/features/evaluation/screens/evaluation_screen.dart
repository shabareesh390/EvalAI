import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/question_model.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/pdf_service.dart';

class EvaluationScreen extends StatefulWidget {
  final List<QuestionModel> questions;
  final String extractedText;


  const EvaluationScreen({
    super.key,
    required this.questions,
    required this.extractedText,
  });

  @override
  State<EvaluationScreen> createState() => _EvaluationScreenState();
}

class _EvaluationScreenState extends State<EvaluationScreen> {
  final GeminiService _geminiService = GeminiService();
  final PdfService _pdfService = PdfService();

  ExamEvaluationResult? _evaluationResult;
  bool _isEvaluating = false;
  String _currentStatus = '';

  @override
  void initState() {
    super.initState();
    _startEvaluation();
  }

  // â”€â”€ Start AI Evaluation â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _startEvaluation() async {
    setState(() {
      _isEvaluating = true;
      _currentStatus = 'Preparing evaluation...';
    });

    try {
      setState(() => _currentStatus = 'Sending to Gemini AI...');

      final result = await _geminiService.evaluateExam(
        questions: widget.questions,
        extractedAnswerText: widget.extractedText,
      );

      setState(() {
        _evaluationResult = result;
        _isEvaluating = false;
        _currentStatus = 'Evaluation complete!';
      });
    } catch (e) {
      setState(() {
        _isEvaluating = false;
        _currentStatus = 'Evaluation failed: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('AI Evaluation'),
        actions: [
          if (_evaluationResult != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: FilledButton.icon(
                onPressed: () async {
                  await _pdfService.generateStudentReport(
                    studentName: 'Student Name',
                    examName: 'Exam',
                    subject: 'Subject',
                    date: DateTime.now().toString().split(' ')[0],
                    result: _evaluationResult!,
                  );
                },
                icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                label: const Text('Export'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(80, 38),
                ),
              ),
            ),
        ],
      ),
      body: _isEvaluating
          ? _buildLoadingState()
          : _evaluationResult != null
          ? _buildResults()
          : _buildErrorState(),
    );
  }

  // â”€â”€ Loading State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 40,
              color: AppColors.primary,
            ),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1500.ms, color: AppColors.accent),

          const SizedBox(height: 24),

          Text('AI Evaluating...', style: AppTextStyles.headlineMedium)
              .animate()
              .fadeIn(duration: 400.ms),

          const SizedBox(height: 8),

          Text(_currentStatus, style: AppTextStyles.bodyMedium)
              .animate()
              .fadeIn(duration: 400.ms),

          const SizedBox(height: 32),

          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),

          const SizedBox(height: 24),

          Text(
            'Analyzing ${widget.questions.length} questions...',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }

  // â”€â”€ Error State â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildErrorState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text('Evaluation Failed', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 8),
          Text(_currentStatus, style: AppTextStyles.bodyMedium),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _startEvaluation,
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  // â”€â”€ Results â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildResults() {
    final result = _evaluationResult!;

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        // â”€â”€ Score Summary Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _buildScoreSummary(result),

        const SizedBox(height: 24),

        // â”€â”€ Overall Feedback â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        _buildOverallFeedback(result),

        const SizedBox(height: 24),

        // â”€â”€ Question-wise Results â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
        Text('Question-wise Analysis', style: AppTextStyles.headlineMedium)
            .animate()
            .fadeIn(delay: 300.ms),

        const SizedBox(height: 16),

        ...result.questionResults.asMap().entries.map(
              (entry) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: _buildQuestionResult(entry.value, entry.key),
          ),
        ),
      ],
    );
  }

  // â”€â”€ Score Summary â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildScoreSummary(ExamEvaluationResult result) {
    final percentage = result.percentage;
    Color scoreColor;

    if (percentage >= 75) {
      scoreColor = AppColors.success;
    } else if (percentage >= 50) {
      scoreColor = AppColors.warning;
    } else {
      scoreColor = AppColors.error;
    }

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Text(
            'Total Score',
            style: AppTextStyles.bodyMedium.copyWith(
              color: Colors.white.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${result.totalMarksAwarded}/${result.totalMarks}',
            style: AppTextStyles.numericLarge.copyWith(
              color: Colors.white,
              fontSize: 48,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: scoreColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${percentage.toStringAsFixed(1)}%',
              style: AppTextStyles.titleLarge.copyWith(
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(duration: 500.ms)
        .slideY(begin: 0.3, end: 0);
  }

  // â”€â”€ Overall Feedback â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildOverallFeedback(ExamEvaluationResult result) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text('AI Feedback', style: AppTextStyles.titleLarge),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            result.overallFeedback,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: 200.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  // â”€â”€ Question Result Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildQuestionResult(EvaluationResult result, int index) {
    final percentage = result.percentage;
    Color resultColor;

    if (percentage >= 75) {
      resultColor = AppColors.success;
    } else if (percentage >= 50) {
      resultColor = AppColors.warning;
    } else {
      resultColor = AppColors.error;
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // â”€â”€ Question Header â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.05),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: resultColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      'Q${result.questionNumber}',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: resultColor,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Question ${result.questionNumber}',
                        style: AppTextStyles.titleMedium,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'AI Confidence: ${result.aiConfidence.toInt()}%',
                        style: AppTextStyles.caption,
                      ),
                    ],
                  ),
                ),
                // Marks badge
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${result.marksAwarded}/${result.totalMarks}',
                      style: AppTextStyles.numericMedium.copyWith(
                        color: resultColor,
                        fontSize: 20,
                      ),
                    ),
                    Text(
                      '${percentage.toInt()}%',
                      style: AppTextStyles.caption.copyWith(
                        color: resultColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // â”€â”€ Question Details â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Strengths
                _buildFeedbackRow(
                  icon: Icons.check_circle_outline,
                  color: AppColors.success,
                  label: 'Strengths',
                  text: result.strengths,
                ),

                const SizedBox(height: 12),

                // Weaknesses
                _buildFeedbackRow(
                  icon: Icons.cancel_outlined,
                  color: AppColors.error,
                  label: 'Weaknesses',
                  text: result.weaknesses,
                ),

                if (result.missingConcepts.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  _buildFeedbackRow(
                    icon: Icons.lightbulb_outline,
                    color: AppColors.warning,
                    label: 'Missing',
                    text: result.missingConcepts,
                  ),
                ],

                const SizedBox(height: 12),

                // Suggestions
                _buildFeedbackRow(
                  icon: Icons.tips_and_updates_outlined,
                  color: AppColors.primary,
                  label: 'Suggestion',
                  text: result.suggestions,
                ),
              ],
            ),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
      delay: Duration(milliseconds: 400 + (index * 150)),
      duration: 400.ms,
    )
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildFeedbackRow({
    required IconData icon,
    required Color color,
    required String label,
    required String text,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTextStyles.labelMedium.copyWith(color: color),
              ),
              const SizedBox(height: 2),
              Text(text, style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
