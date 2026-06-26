import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/services/ocr_service.dart';
import '../../../core/routes/app_router.dart';
import '../../../core/models/question_model.dart';

class OcrScreen extends StatefulWidget {
  const OcrScreen({super.key});

  @override
  State<OcrScreen> createState() => _OcrScreenState();
}

class _OcrScreenState extends State<OcrScreen> {
  final OcrService _ocrService = OcrService();
  final ImagePicker _imagePicker = ImagePicker();

  File? _selectedImage;
  OcrResult? _ocrResult;
  bool _isProcessing = false;

  @override
  void dispose() {
    _ocrService.dispose();
    super.dispose();
  }

  // â”€â”€ Pick image from gallery â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _pickImage() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _ocrResult = null;
      });
      await _processOcr();
    }
  }

  // â”€â”€ Take photo with camera â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _takePhoto() async {
    final XFile? picked = await _imagePicker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (picked != null) {
      setState(() {
        _selectedImage = File(picked.path);
        _ocrResult = null;
      });
      await _processOcr();
    }
  }

  // â”€â”€ Process OCR â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _processOcr() async {
    if (_selectedImage == null) return;

    setState(() => _isProcessing = true);

    try {
      final result = await _ocrService.extractTextFromImage(_selectedImage!);
      setState(() {
        _ocrResult = result;
        _isProcessing = false;
      });
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('OCR Processing'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // â”€â”€ Pick Image Buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          _buildPickButtons(),

          const SizedBox(height: 24),

          // â”€â”€ Selected Image Preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (_selectedImage != null) _buildImagePreview(),

          // â”€â”€ Processing Indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (_isProcessing) _buildProcessingIndicator(),

          // â”€â”€ OCR Result â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
          if (_ocrResult != null) ...[
            const SizedBox(height: 24),
            _buildConfidenceCard(),
            const SizedBox(height: 16),
            _buildExtractedTextCard(),
            const SizedBox(height: 24),
            _buildActionButton(),
          ],
        ],
      ),
    );
  }

  // â”€â”€ Pick Buttons â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildPickButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: _pickImage,
            icon: const Icon(Icons.photo_library_outlined),
            label: const Text('Gallery'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 52),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: FilledButton.icon(
            onPressed: _takePhoto,
            icon: const Icon(Icons.camera_alt_outlined),
            label: const Text('Camera'),
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, 52),
            ),
          ),
        ),
      ],
    ).animate().fadeIn(duration: 400.ms);
  }

  // â”€â”€ Image Preview â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildImagePreview() {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        image: DecorationImage(
          image: FileImage(_selectedImage!),
          fit: BoxFit.cover,
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).scale(begin: const Offset(0.95, 0.95));
  }

  // â”€â”€ Processing Indicator â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildProcessingIndicator() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 32),
      child: Column(
        children: [
          const CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Extracting text from image...',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  // â”€â”€ Confidence Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildConfidenceCard() {
    final result = _ocrResult!;

    Color confidenceColor;
    IconData confidenceIcon;

    switch (result.confidenceLevel) {
      case OcrConfidenceLevel.high:
        confidenceColor = AppColors.success;
        confidenceIcon = Icons.check_circle_outline;
        break;
      case OcrConfidenceLevel.medium:
        confidenceColor = AppColors.warning;
        confidenceIcon = Icons.warning_amber_outlined;
        break;
      case OcrConfidenceLevel.low:
        confidenceColor = AppColors.error;
        confidenceIcon = Icons.error_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: confidenceColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: confidenceColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(confidenceIcon, color: confidenceColor, size: 32),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  result.confidenceLabel,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: confidenceColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'OCR Confidence: ${result.confidence.toStringAsFixed(1)}%',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          // Confidence percentage circle
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: confidenceColor.withValues(alpha: 0.15),
            ),
            child: Center(
              child: Text(
                '${result.confidence.toInt()}%',
                style: AppTextStyles.labelMedium.copyWith(
                  color: confidenceColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  // â”€â”€ Extracted Text Card â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildExtractedTextCard() {
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Extracted Text', style: AppTextStyles.titleLarge),
              Text(
                '${_ocrResult!.extractedText.length} chars',
                style: AppTextStyles.caption,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            _ocrResult!.extractedText.isEmpty
                ? 'No text could be extracted from this image.'
                : _ocrResult!.extractedText,
            style: AppTextStyles.bodyMedium.copyWith(
              color: _ocrResult!.extractedText.isEmpty
                  ? AppColors.textDisabled
                  : AppColors.textPrimary,
              height: 1.8,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  // â”€â”€ Action Button â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Widget _buildActionButton() {
    final isHighConfidence =
        _ocrResult?.confidenceLevel == OcrConfidenceLevel.high;

    return FilledButton.icon(
      onPressed: () {
        // Navigate to evaluation with extracted text
        // For now use sample questions â€” later pass real exam questions
        Navigator.pushNamed(
          context,
          AppRoutes.evaluation,
          arguments: {
            'questions': _getSampleQuestions(),
            'extractedText': _ocrResult?.extractedText ?? '',
          },
        );
      },
      icon: Icon(
        isHighConfidence
            ? Icons.auto_awesome_rounded
            : Icons.rate_review_outlined,
      ),
      label: Text(
        isHighConfidence ? 'Start AI Evaluation' : 'Review & Evaluate',
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

// Sample questions for testing â€” replace with real exam questions later
  List<QuestionModel> _getSampleQuestions() {
    return [
      QuestionModel(
        id: '1',
        questionNumber: 1,
        marks: 5,
        modelAnswer: 'Photosynthesis is the process by which plants use sunlight, water and carbon dioxide to produce oxygen and energy in the form of glucose.',
        keywords: ['sunlight', 'chlorophyll', 'glucose', 'oxygen', 'carbon dioxide'],
        rubric: 'Definition: 2 marks, Process: 2 marks, Products: 1 mark',
      ),
      QuestionModel(
        id: '2',
        questionNumber: 2,
        marks: 5,
        modelAnswer: 'Newton\'s first law states that an object at rest stays at rest and an object in motion stays in motion unless acted upon by an external force.',
        keywords: ['inertia', 'rest', 'motion', 'external force', 'Newton'],
        rubric: 'Law statement: 3 marks, Example: 2 marks',
      ),
    ];
  }
}
