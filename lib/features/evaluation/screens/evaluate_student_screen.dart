import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/exam_model.dart';
import '../../../core/models/user_model.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/services/pdf_report_service.dart';
import 'pdf_preview_screen.dart';
import '../../authentication/providers/auth_provider.dart';
import '../../exam/providers/exam_provider.dart';
import '../../exam/providers/student_provider.dart';
import '../providers/evaluation_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class EvaluateStudentScreen extends StatefulWidget {
  const EvaluateStudentScreen({super.key});

  @override
  State<EvaluateStudentScreen> createState() => _EvaluateStudentScreenState();
}

class _EvaluateStudentScreenState extends State<EvaluateStudentScreen> {
  ExamModel? _selectedExam;
  String? _selectedClass;
  final Map<String, File> _attachedFiles = {};
  final Map<String, String> _attachedFileNames = {};
  final Map<String, ExamEvaluationResult> _batchResults = {};

  bool _isProcessing = false;
  String _processingStatus = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacherId = context.read<AuthProvider>().user?.uid ?? '';
      context.read<ExamProvider>().fetchExams(teacherId);
      context.read<StudentProvider>().fetchStudents(teacherId);
    });
  }

  String _getStudentKey(StudentModel student) {
    if (student.id.isNotEmpty && student.id != "null") {
      return student.id;
    }
    return "${student.name.replaceAll(' ', '_')}_${student.rollNumber}";
  }

  @override
  Widget build(BuildContext context) {
    final examProvider = context.watch<ExamProvider>();
    final studentProvider = context.watch<StudentProvider>();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Classroom Evaluation Console')),
      body: _isProcessing
          ? _buildBatchProcessingState()
          : _batchResults.isNotEmpty
          ? _buildClassResultsDashboard()
          : examProvider.isLoading || studentProvider.isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildBlueprintHeader(),
          const SizedBox(height: 12),
          _buildExamSelectorDropdown(examProvider.exams),
          const SizedBox(height: 28),
          _buildClassroomHeader(),
          const SizedBox(height: 12),
          _buildClassSelectorDropdown(studentProvider.students),
          const SizedBox(height: 12),
          _buildClassAccordionList(studentProvider.students),
          const SizedBox(height: 32),
          _buildActionButtonPanel(studentProvider.students),
        ],
      ),
    );
  }

  Widget _buildBlueprintHeader() {
    return Row(
      children: [
        const Icon(Icons.assignment_outlined, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '1. Select Exam Blueprint',
            style: AppTextStyles.headlineMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildClassroomHeader() {
    return Row(
      children: [
        const Icon(Icons.school_outlined, color: AppColors.primary, size: 20),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '2. Manage Classes & Student Answer Sheets',
            style: AppTextStyles.headlineMedium,
          ),
        ),
      ],
    );
  }

  Widget _buildExamSelectorDropdown(List<ExamModel> exams) {
    if (exams.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.warningLight, borderRadius: BorderRadius.circular(12)),
        child: Text('No exam blueprints generated yet. Please create an exam first.', style: AppTextStyles.bodyMedium),
      );
    }

    return DropdownButtonFormField<ExamModel>(
      value: _selectedExam,
      isExpanded: true,
      hint: const Text('Choose reference answer key template'),
      decoration: const InputDecoration(prefixIcon: Icon(Icons.layers_outlined)),
      items: exams.map((exam) {
        return DropdownMenuItem<ExamModel>(
          value: exam,
          child: Text(
            '${exam.name} (${exam.subject} â€¢ ${exam.totalMarks}M)',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
      onChanged: (value) => setState(() => _selectedExam = value),
    );
  }

  Widget _buildClassSelectorDropdown(List<StudentModel> students) {
    final Set<String> classNames = {};
    for (var student in students) {
      final className = student.className.trim();
      if (className.isNotEmpty) {
        classNames.add(className);
      }
    }

    if (classNames.isEmpty) {
      return const SizedBox.shrink();
    }

    final sortedClasses = classNames.toList()..sort();
    final currentValue = classNames.contains(_selectedClass) ? _selectedClass : null;

    return DropdownButtonFormField<String>(
      value: currentValue,
      isExpanded: true,
      hint: const Text('All Classes'),
      decoration: const InputDecoration(prefixIcon: Icon(Icons.filter_list_outlined)),
      items: [
        const DropdownMenuItem<String>(
          value: null,
          child: Text('All Classes'),
        ),
        ...sortedClasses.map((className) {
          return DropdownMenuItem<String>(
            value: className,
            child: Text('Class Room: $className'),
          );
        }),
      ],
      onChanged: (value) => setState(() => _selectedClass = value),
    );
  }

  Widget _buildClassAccordionList(List<StudentModel> students) {
    final Map<String, List<StudentModel>> groupedClasses = {};
    for (var student in students) {
      final className = student.className.trim();
      if (className.isNotEmpty) {
        if (_selectedClass == null || _selectedClass == className) {
          groupedClasses.putIfAbsent(className, () => []).add(student);
        }
      }
    }

    if (groupedClasses.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Text('No student rosters available. Please register student accounts under your dashboard.', style: AppTextStyles.bodyMedium),
      );
    }

    return Column(
      children: groupedClasses.entries.map((entry) {
        final String className = entry.key;
        final List<StudentModel> classRoster = entry.value;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: ExpansionTile(
              backgroundColor: AppColors.surface,
              collapsedBackgroundColor: AppColors.surface,
              title: Text('Class Room: $className', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
              subtitle: Text('${classRoster.length} registered students inside folder', style: AppTextStyles.caption),
              leading: const Icon(Icons.folder_open_rounded, color: Colors.amber),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: classRoster.map((student) {
                final String studentKey = _getStudentKey(student);
                final hasFile = _attachedFiles.containsKey(studentKey);
                final fileName = _attachedFileNames[studentKey] ?? '';

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border.withValues(alpha: 0.5)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 18,
                        backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                        child: Text(student.name[0].toUpperCase(), style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(student.name, style: AppTextStyles.titleMedium),
                            Text('Roll No: ${student.rollNumber} â€¢ USN: ${student.usn} â€¢ Sec: ${student.section}', style: AppTextStyles.caption),
                            if (hasFile)
                              Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Text('ðŸ“‘ $fileName', style: AppTextStyles.caption.copyWith(color: AppColors.success, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _pickDocumentForStudent(studentKey, students),
                        icon: Icon(hasFile ? Icons.sync_rounded : Icons.add_rounded, size: 14),
                        label: Text(hasFile ? 'Change' : 'Add Paper'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          minimumSize: Size.zero,
                          backgroundColor: hasFile ? AppColors.successLight : AppColors.primary.withValues(alpha: 0.08),
                          foregroundColor: hasFile ? AppColors.success : AppColors.primary,
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: 400.ms);
  }

  Future<void> _pickDocumentForStudent(String studentKey, List<StudentModel> allStudents) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
    );

    if (result != null && result.files.single.path != null) {
      setState(() {
        _attachedFiles[studentKey] = File(result.files.single.path!);
        _attachedFileNames[studentKey] = result.files.single.name;
      });

      final prefs = await SharedPreferences.getInstance();
      final autoEvaluate = prefs.getBool('setting_auto_evaluate') ?? true;
      if (autoEvaluate && _selectedExam != null) {
        _startBatchEvaluationPipeline(allStudents);
      }
    }
  }

  Widget _buildActionButtonPanel(List<StudentModel> allStudents) {
    final bool canRun = _selectedExam != null && _attachedFiles.isNotEmpty;

    return FilledButton.icon(
      onPressed: canRun ? () => _startBatchEvaluationPipeline(allStudents) : null,
      icon: const Icon(Icons.auto_awesome_rounded),
      label: Text(_attachedFiles.isEmpty
          ? 'Attach Answer Sheets to Begin'
          : 'Evaluate ${_attachedFiles.length} Staged Papers'),
      style: FilledButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        backgroundColor: AppColors.primary,
      ),
    );
  }

  // â”€â”€ UPGRADED Automated Evaluation Loop â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  Future<void> _startBatchEvaluationPipeline(List<StudentModel> allStudents) async {
    final evaluationProvider = context.read<EvaluationProvider>();
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';

    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult.contains(ConnectivityResult.none) && connectivityResult.length == 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('No internet connection. Please connect to a network and try again.'),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _startBatchEvaluationPipeline(allStudents),
            ),
          ),
        );
      }
      return;
    }

    setState(() {
      _isProcessing = true;
      _batchResults.clear();
    });

    final evaluationQueue = allStudents.where((s) {
      return _attachedFiles.containsKey(_getStudentKey(s));
    }).toList();

    for (int i = 0; i < evaluationQueue.length; i++) {
      final student = evaluationQueue[i];
      final String studentKey = _getStudentKey(student);
      final targetFile = _attachedFiles[studentKey]!;

      setState(() {
        _processingStatus = 'Processing [${i + 1}/${evaluationQueue.length}]\nReading document for ${student.name}...';
      });

      try {
        // Read file bytes and determine mime type
        final fileBytes = await targetFile.readAsBytes();
        final extension = targetFile.path.split('.').last.toLowerCase();

        String mimeType = 'application/pdf';
        if (['jpg', 'jpeg'].contains(extension)) mimeType = 'image/jpeg';
        if (extension == 'png') mimeType = 'image/png';

        // Call the upgraded evaluate method directly with bytes
        final evaluationResult = await evaluationProvider.evaluate(
          exam: _selectedExam!,
          fileBytes: fileBytes,
          mimeType: mimeType,
          onStepUpdate: (status) {
            setState(() {
              _processingStatus = 'Processing [${i + 1}/${evaluationQueue.length}]\n${student.name}: $status';
            });
          },
        );

        if (evaluationResult != null) {
          await evaluationProvider.saveEvaluation(
            exam: _selectedExam!,
            student: student,
            teacherId: teacherId,
            result: evaluationResult,
            extractedText: "Evaluated directly via Gemini AI",
            ocrConfidence: 100.0,
          );

          _batchResults[studentKey] = evaluationResult;
        } else {
          // Fallback if AI entirely fails
          final manualResult = ExamEvaluationResult(
            totalMarksAwarded: 0,
            totalMarks: _selectedExam!.totalMarks,
            questionResults: const [],
            overallFeedback: "Failed to read document. Manual evaluation recommended.",
          );
          _batchResults[studentKey] = manualResult;
        }
      } catch (studentError) {
        debugPrint("Skip on evaluation index failure for ${student.name}: $studentError");
      }
    }

    setState(() => _isProcessing = false);
  }

  Widget _buildBatchProcessingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary)),
          const SizedBox(height: 24),
          Text('Batch Parsing Engine Active', style: AppTextStyles.headlineMedium),
          const SizedBox(height: 12),
          Text(_processingStatus, textAlign: TextAlign.center, style: AppTextStyles.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildClassResultsDashboard() {
    final studentProvider = context.read<StudentProvider>();

    final evaluatedList = studentProvider.students.where((s) {
      return _batchResults.containsKey(_getStudentKey(s));
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Text('Classroom Scorecard Summary', style: AppTextStyles.headlineMedium),
        Text('Reference Key Blueprint: ${_selectedExam?.name}', style: AppTextStyles.caption),
        const SizedBox(height: 20),
        ...evaluatedList.map((student) {
          final String studentKey = _getStudentKey(student);
          final scoreCard = _batchResults[studentKey]!;

          final bool needsManualReview = scoreCard.overallFeedback.contains("Manual evaluation");
          final passed = scoreCard.percentage >= 50;

          return Card(
            margin: const EdgeInsets.symmetric(vertical: 6),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: needsManualReview
                    ? AppColors.warning.withValues(alpha: 0.1)
                    : (passed ? AppColors.success : AppColors.error).withValues(alpha: 0.1),
                child: Icon(
                  needsManualReview
                      ? Icons.back_hand_rounded
                      : (passed ? Icons.check : Icons.close),
                  color: needsManualReview
                      ? AppColors.warning
                      : (passed ? AppColors.success : AppColors.error),
                  size: 18,
                ),
              ),
              title: Text(student.name, style: AppTextStyles.titleMedium),
              subtitle: Text('Roll No: ${student.rollNumber} â€¢ Feedback: ${scoreCard.overallFeedback}'),

              // â”€â”€ ADDED: PDF Print Button inside the trailing row â”€â”€
              trailing: needsManualReview
                  ? OutlinedButton.icon(
                onPressed: () => _showManualGradeDialog(student, scoreCard),
                icon: const Icon(Icons.edit_note_rounded, size: 14),
                label: const Text('Enter Marks'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.warning,
                  side: const BorderSide(color: AppColors.warning),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                ),
              )
                  : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${scoreCard.totalMarksAwarded}/${scoreCard.totalMarks}',
                    style: AppTextStyles.numericMedium.copyWith(
                      color: passed ? AppColors.success : AppColors.error,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => PdfPreviewScreen(
                            title: '${student.name} Report',
                            buildPdf: (format) => PdfReportService.buildPdfForStudent(
                              format,
                              student: student,
                              exam: _selectedExam!,
                              result: scoreCard,
                            ),
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.print_rounded),
                    color: AppColors.primary,
                    tooltip: 'Print Report Card',
                  ),
                ],
              ),
            ),
          );
        }),
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: () => setState(() {
            _batchResults.clear();
            _attachedFiles.clear();
            _attachedFileNames.clear();
          }),
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Reset Console & Evaluate New Batch'),
        )
      ],
    );
  }

  void _showManualGradeDialog(StudentModel student, ExamEvaluationResult currentResult) {
    final scoreController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Manual Grading: ${student.name}'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: scoreController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Awarded Marks (Out of ${currentResult.totalMarks})',
                prefixIcon: const Icon(Icons.grade_outlined),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Please enter a score';
                final marks = int.tryParse(v);
                if (marks == null || marks < 0 || marks > currentResult.totalMarks) {
                  return 'Enter a valid mark between 0 and ${currentResult.totalMarks}';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (!formKey.currentState!.validate()) return;
                final manualScore = int.parse(scoreController.text.trim());
                Navigator.pop(dialogContext);

                final String studentKey = _getStudentKey(student);

                setState(() {
                  _batchResults[studentKey] = ExamEvaluationResult(
                    totalMarksAwarded: manualScore,
                    totalMarks: currentResult.totalMarks,
                    questionResults: const [],
                    overallFeedback: "Evaluated Manually by Instructor.",
                  );
                });
              },
              child: const Text('Save Grade'),
            ),
          ],
        );
      },
    );
  }
}
