import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routes/app_router.dart';
import 'package:provider/provider.dart';
import '../../../features/authentication/providers/auth_provider.dart';
import '../../exam/providers/exam_provider.dart';
import '../../exam/providers/student_provider.dart';
import '../../../core/services/pdf_report_service.dart';
import '../../../core/models/evaluation_model.dart';
import '../../evaluation/screens/pdf_preview_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final teacherId = context.read<AuthProvider>().user?.uid ?? '';
      context.read<ExamProvider>().fetchExams(teacherId);
      context.read<StudentProvider>().fetchStudents(teacherId);
    });
  }

  // ── Native Error-Free Dialog Viewer ───────────────────────────────────
  void _showSavedExamsDialog() {
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Saved Exams Database'),
          content: SizedBox(
            width: double.maxFinite,
            height: 350,
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore
                  .collection('exams')
                  .where('teacherId', isEqualTo: teacherId)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data?.docs ?? [];

                if (docs.isEmpty) {
                  return const Center(child: Text('No saved exams found.'));
                }

                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data() as Map<String, dynamic>;
                    final name = data['name'] ?? data['examName'] ?? 'Unnamed Exam';
                    final subject = data['subject'] ?? 'No Subject';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.assignment, color: Colors.blue),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(subject),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          await _firestore
                              .collection('exams')
                              .doc(docs[index].id)
                              .delete();
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(child: _buildTopBar()),
            SliverToBoxAdapter(child: _buildWelcomeHeader()),
            SliverToBoxAdapter(child: _buildStatsGrid()),
            SliverToBoxAdapter(child: _buildQuickActionsHeader()),
            SliverToBoxAdapter(child: _buildQuickActions()),
            // ── INJECTED CHART MODULES ──
            SliverToBoxAdapter(child: _buildChartHeader()),
            SliverToBoxAdapter(child: _buildPerformanceChart()),
            // ────────────────────────────
            SliverToBoxAdapter(child: _buildRecentExamsHeader()),
            SliverToBoxAdapter(child: _buildRecentExams()),
            SliverToBoxAdapter(child: _buildRecentEvaluationsHeader()),
            SliverToBoxAdapter(child: _buildRecentEvaluations()),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.asset('assets/images/evalai.png', fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                'EvalAI',
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          Row(
            children: [
              IconButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('No new notifications')),
                  );
                },
                icon: const Icon(Icons.notifications_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.settings),
                icon: const Icon(Icons.settings_outlined),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.textPrimary,
                ),
              ),
              const SizedBox(width: 8),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final name = auth.user?.displayName ?? 'Teacher';
                  final photoUrl = auth.user?.photoURL;
                  return CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary,
                    backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                    child: photoUrl == null 
                        ? Text(
                            name.isNotEmpty ? name[0].toUpperCase() : '?',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: Colors.white,
                            ),
                          )
                        : null,
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildWelcomeHeader() {
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('evaluations')
          .where('teacherId', isEqualTo: teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        final totalDocs = snapshot.data?.docs.length ?? 0;
        final pendingReview = totalDocs > 0 ? (totalDocs * 0.1).ceil() : 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('HELLO,', style: AppTextStyles.bodyMedium),
              const SizedBox(height: 4),
              Consumer<AuthProvider>(
                builder: (context, auth, _) {
                  final name = auth.user?.displayName ?? 'Teacher';
                  return Text(name, style: AppTextStyles.displayMedium);
                },
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.warningLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.pending_actions_rounded,
                      size: 16,
                      color: AppColors.warning,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$pendingReview papers need review',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: AppColors.warning,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    )
        .animate()
        .fadeIn(delay: 100.ms, duration: 400.ms)
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildStatsGrid() {
    final examProvider = context.watch<ExamProvider>();
    final studentProvider = context.watch<StudentProvider>();
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('evaluations')
          .where('teacherId', isEqualTo: teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        final int totalEvaluations = snapshot.data?.docs.length ?? 0;
        final int pendingReview = totalEvaluations > 0 ? (totalEvaluations * 0.1).ceil() : 0;

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 0),
          child: GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.2,
            children: [
              _buildStatCard(
                label: 'Total Exams',
                value: '${examProvider.exams.length}',
                icon: Icons.assignment_outlined,
                color: AppColors.primary,
                bgColor: AppColors.primary.withValues(alpha: 0.08),
                delay: 200,
              ),
              _buildStatCard(
                label: 'Students',
                value: '${studentProvider.students.length}',
                icon: Icons.people_outline,
                color: AppColors.success,
                bgColor: AppColors.successLight,
                delay: 300,
              ),
              _buildStatCard(
                label: 'Evaluated',
                value: '$totalEvaluations',
                icon: Icons.check_circle_outline,
                color: AppColors.info,
                bgColor: AppColors.infoLight,
                delay: 400,
              ),
              _buildStatCard(
                label: 'Pending Review',
                value: '$pendingReview',
                icon: Icons.hourglass_empty_rounded,
                color: AppColors.warning,
                bgColor: AppColors.warningLight,
                delay: 500,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatCard({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required int delay,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: AppTextStyles.numericMedium),
              const SizedBox(height: 2),
              Text(label, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: delay), duration: 400.ms)
        .slideY(begin: 0.3, end: 0);
  }

  Widget _buildQuickActionsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Text('Quick Actions', style: AppTextStyles.headlineMedium),
    ).animate().fadeIn(delay: 600.ms, duration: 400.ms);
  }

  Widget _buildQuickActions() {
    final actions = [
      _QuickAction(
        label: 'Create Exam',
        icon: Icons.add_circle_outline,
        color: AppColors.primary,
        bgColor: AppColors.primary.withValues(alpha: 0.08),
        onTap: () => Navigator.pushNamed(context, AppRoutes.createExam),
      ),
      _QuickAction(
        label: 'Evaluate',
        icon: Icons.rate_review_outlined,
        color: AppColors.success,
        bgColor: AppColors.successLight,
        onTap: () => Navigator.pushNamed(context, AppRoutes.evaluateStudent),
      ),
      _QuickAction(
        label: 'Class',
        icon: Icons.people_outline,
        color: AppColors.info,
        bgColor: AppColors.infoLight,
        onTap: () => Navigator.pushNamed(context, AppRoutes.studentManagement),
      ),
      _QuickAction(
        label: 'Saved Exams',
        icon: Icons.folder_special_outlined,
        color: AppColors.warning,
        bgColor: AppColors.warningLight,
        onTap: _showSavedExamsDialog,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: actions
              .asMap()
              .entries
              .map(
                (entry) => Expanded(
              child: Padding(
                padding: EdgeInsets.only(
                  right: entry.key < actions.length - 1 ? 8 : 0,
                ),
                child: _buildQuickActionButton(entry.value, entry.key),
              ),
            ),
          )
              .toList(),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(_QuickAction action, int index) {
    return GestureDetector(
      onTap: action.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 2),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: action.bgColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(action.icon, color: action.color, size: 18),
            ),
            const SizedBox(height: 6),
            Text(
              action.label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                fontSize: 10,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    )
        .animate()
        .fadeIn(
      delay: Duration(milliseconds: 650 + (index * 80)),
      duration: 400.ms,
    )
        .slideY(begin: 0.3, end: 0);
  }

  // ── INJECTED: Chart Section Header ─────────────────────────────────────
  Widget _buildChartHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Text('Evaluation Analytics', style: AppTextStyles.headlineMedium),
    ).animate().fadeIn(delay: 750.ms, duration: 400.ms);
  }

  // ── INJECTED: Live Custom Performance Analytics Chart Bar Widget ─────────
  Widget _buildPerformanceChart() {
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('evaluations')
          .where('teacherId', isEqualTo: teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        // Dynamic evaluation dataset tracking grouped by generic score tiers
        int excellent = 0; // >= 80%
        int good = 0;      // >= 60%
        int average = 0;   // >= 40%
        int remedial = 0;  // < 40%

        for (var doc in docs) {
          final data = doc.data() as Map<String, dynamic>;
          final double marksAwarded = (data['totalMarksAwarded'] ?? 0).toDouble();
          final double totalMarks = (data['totalMarks'] ?? 1).toDouble();
          final double percentage = totalMarks > 0 ? (marksAwarded / totalMarks) * 100 : 0.0;
          if (percentage >= 80) { excellent++; }
          else if (percentage >= 60) { good++; }
          else if (percentage >= 40) { average++; }
          else { remedial++; }
        }

        // Determine max vertical bounds range scale dynamically to avoid division errors
        int maxCount = [excellent, good, average, remedial].reduce((a, b) => a > b ? a : b);
        if (maxCount == 0) maxCount = 1;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Container(
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
                    Text('Score Tier Distribution', style: AppTextStyles.titleMedium),
                    Icon(Icons.bar_chart_rounded, color: AppColors.primary.withValues(alpha: 0.6), size: 20),
                  ],
                ),
                const SizedBox(height: 24),
                // Core Graphic Layout Framework Rendering Block
                SizedBox(
                  height: 140,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      _buildVerticalBar('Excellent\n(>80%)', excellent, maxCount, AppColors.success),
                      _buildVerticalBar('Good\n(60-80%)', good, maxCount, AppColors.info),
                      _buildVerticalBar('Average\n(40-60%)', average, maxCount, AppColors.warning),
                      _buildVerticalBar('Remedial\n(<40%)', remedial, maxCount, AppColors.error),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    ).animate().fadeIn(delay: 820.ms, duration: 400.ms);
  }

  // Sub-helper structure to build cleanly proportional graph lines
  Widget _buildVerticalBar(String label, int currentCount, int maxVal, Color barColor) {
    final double computedHeightRatio = currentCount / maxVal;

    return Expanded(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('$currentCount', style: AppTextStyles.caption.copyWith(fontWeight: FontWeight.bold, fontSize: 11)),
          const SizedBox(height: 6),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedContainer(
                    duration: 600.ms,
                    curve: Curves.easeOutCubic,
                    width: 24,
                    height: (constraints.maxHeight * computedHeightRatio).clamp(4.0, constraints.maxHeight),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: AppTextStyles.caption.copyWith(fontSize: 9, height: 1.2),
            maxLines: 2,
          ),
        ],
      ),
    );
  }

  Widget _buildRecentExamsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Recent Exams', style: AppTextStyles.headlineMedium),
          TextButton(
            onPressed: _showSavedExamsDialog,
            child: Text(
              'View all',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 900.ms, duration: 400.ms);
  }

  Widget _buildRecentExams() {
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';
    final studentProvider = context.watch<StudentProvider>();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('exams')
          .where('teacherId', isEqualTo: teacherId)
          .orderBy('createdAt', descending: true)
          .limit(3)
          .snapshots(),
      builder: (context, examSnapshot) {
        if (examSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        final examDocs = examSnapshot.data?.docs ?? [];

        if (examDocs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No exams built yet. Tap "Create Exam" to begin.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          );
        }

        return StreamBuilder<QuerySnapshot>(
          stream: _firestore
              .collection('evaluations')
              .where('teacherId', isEqualTo: teacherId)
              .snapshots(),
          builder: (context, evalSnapshot) {
            final evalDocs = evalSnapshot.data?.docs ?? [];
            
            return Column(
              children: examDocs.asMap().entries.map((entry) {
                final int index = entry.key;
                final doc = entry.value;
                final data = doc.data() as Map<String, dynamic>;
    
                final String id = data['id'] ?? doc.id;
                final String name = data['name'] ?? 'Unnamed Exam';
                final String subject = data['subject'] ?? 'No Subject';
                final String date = data['date'] ?? 'No Date';
                final String className = data['className'] ?? '';
                
                // Count evaluations for this exam
                int evaluatedCount = 0;
                for (var eval in evalDocs) {
                  final evalData = eval.data() as Map<String, dynamic>;
                  if (evalData['examId'] == id) {
                    evaluatedCount++;
                  }
                }
                
                // Count total students for this exam's class
                int totalStudents = 0;
                if (className.isNotEmpty) {
                  totalStudents = studentProvider.students.where((s) => s.className.trim() == className.trim()).length;
                }
                if (totalStudents == 0) {
                  totalStudents = studentProvider.students.length;
                }
                if (totalStudents == 0) totalStudents = 1; // Prevent division by zero visually
    
                final bool isCompleted = evaluatedCount >= totalStudents;
    
                final item = _ExamItem(
                  name: name,
                  subject: subject,
                  date: date,
                  evaluated: evaluatedCount,
                  total: totalStudents,
                  status: isCompleted ? 'Completed' : 'In Progress',
                  statusColor: isCompleted ? AppColors.success : AppColors.warning,
                );
    
                return Padding(
                  padding: EdgeInsets.only(
                    bottom: index < examDocs.length - 1 ? 12 : 0,
                  ),
                  child: _buildExamCard(item, index),
                );
              }).toList(),
            );
          }
        );
      },
    );
  }

  Widget _buildExamCard(_ExamItem exam, int index) {
    final progress = exam.total > 0 ? exam.evaluated / exam.total : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.description_outlined,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(exam.name, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 2),
                    Text(
                      '${exam.subject} • ${exam.date}',
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: exam.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  exam.status,
                  style: AppTextStyles.caption.copyWith(
                    color: exam.statusColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${exam.evaluated}/${exam.total} evaluated',
                    style: AppTextStyles.caption,
                  ),
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: AppColors.surfaceAlt,
                  valueColor: AlwaysStoppedAnimation<Color>(exam.statusColor),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(
      delay: Duration(milliseconds: 950 + (index * 100)),
      duration: 400.ms,
    )
        .slideY(begin: 0.2, end: 0);
  }

  Widget _buildRecentEvaluationsHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text('Student Reports', style: AppTextStyles.headlineMedium),
        ],
      ),
    ).animate().fadeIn(delay: 1000.ms, duration: 400.ms);
  }

  Widget _buildRecentEvaluations() {
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';
    final examProvider = context.watch<ExamProvider>();

    return StreamBuilder<QuerySnapshot>(
      stream: _firestore
          .collection('evaluations')
          .where('teacherId', isEqualTo: teacherId)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          debugPrint('Firestore Error: ${snapshot.error}');
        }
        
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: Padding(
            padding: EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ));
        }

        var docs = snapshot.data?.docs ?? [];
        
        if (docs.isNotEmpty) {
          // Sort locally to avoid requiring a composite index in Firestore
          docs.sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTime = DateTime.tryParse(aData['evaluatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = DateTime.tryParse(bData['evaluatedAt']?.toString() ?? '') ?? DateTime.fromMillisecondsSinceEpoch(0);
            return bTime.compareTo(aTime);
          });
          if (docs.length > 5) docs = docs.sublist(0, 5);
        }

        if (docs.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'No evaluated students yet. When you evaluate answer sheets, their reports will appear here.',
              textAlign: TextAlign.center,
              style: AppTextStyles.caption,
            ),
          );
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: docs.asMap().entries.map((entry) {
              final int index = entry.key;
              final doc = entry.value;
              final data = doc.data() as Map<String, dynamic>;
              final evaluation = EvaluationModel.fromMap(data);
              
              // Find the corresponding exam to get the subject name
              final exam = examProvider.exams.where((e) => e.id == evaluation.examId).firstOrNull;
              final subjectText = exam != null && exam.subject.isNotEmpty ? '${exam.subject} • ' : '';

              return Card(
                margin: EdgeInsets.only(bottom: index < docs.length - 1 ? 12 : 0),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: AppColors.border),
                ),
                color: AppColors.surface,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withValues(alpha: 0.08),
                    child: Text(
                      evaluation.studentName.isNotEmpty ? evaluation.studentName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  title: Text(evaluation.studentName, style: AppTextStyles.titleMedium),
                  subtitle: Text('$subjectText${evaluation.examName} • Score: ${evaluation.totalMarksAwarded}/${evaluation.totalMarks}'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.picture_as_pdf, color: AppColors.primary),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => PdfPreviewScreen(
                                title: '${evaluation.studentName} Report',
                                buildPdf: (format) => PdfReportService.buildPdfFromEvaluation(
                                  format, 
                                  evaluation,
                                  subject: exam?.subject ?? '',
                                ),
                              ),
                            ),
                          );
                        },
                        tooltip: 'View Report',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () async {
                          final confirm = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Delete Report'),
                              content: const Text('Are you sure you want to delete this student report?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                ),
                              ],
                            ),
                          );
                          if (confirm == true) {
                            await _firestore.collection('evaluations').doc(doc.id).delete();
                          }
                        },
                        tooltip: 'Delete Report',
                      ),
                    ],
                  ),
                ),
              ).animate().fadeIn(
                delay: Duration(milliseconds: 1050 + (index * 100)),
                duration: 400.ms,
              ).slideY(begin: 0.2, end: 0);
            }).toList(),
          ),
        );
      },
    );
  }
}

class _QuickAction {
  final String label;
  final IconData icon;
  final Color color;
  final Color bgColor;
  final VoidCallback onTap;

  _QuickAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.bgColor,
    required this.onTap,
  });
}

class _ExamItem {
  final String name;
  final String subject;
  final String date;
  final int evaluated;
  final int total;
  final String status;
  final Color statusColor;

  _ExamItem({
    required this.name,
    required this.subject,
    required this.date,
    required this.evaluated,
    required this.total,
    required this.status,
    required this.statusColor,
  });
}