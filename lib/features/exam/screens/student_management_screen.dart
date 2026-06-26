import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/models/user_model.dart';
import '../providers/student_provider.dart';
import '../../authentication/providers/auth_provider.dart';

class StudentManagementScreen extends StatefulWidget {
  const StudentManagementScreen({super.key});

  @override
  State<StudentManagementScreen> createState() => _StudentManagementScreenState();
}

class _StudentManagementScreenState extends State<StudentManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();

  List<String> _explicitClasses = [];
  bool _isLoadingClasses = false;

  // Form Controllers
  final _nameController = TextEditingController();
  final _usnController = TextEditingController();
  final _sectionController = TextEditingController();
  final _newClassController = TextEditingController();
  final _studentCountController = TextEditingController(); // Controls sequential generation length

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshScreenData();
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usnController.dispose();
    _sectionController.dispose();
    _newClassController.dispose();
    _studentCountController.dispose();
    super.dispose();
  }

  Future<void> _refreshScreenData() async {
    if (!mounted) return;
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';

    setState(() => _isLoadingClasses = true);

    await context.read<StudentProvider>().fetchStudents(teacherId);

    try {
      final snapshot = await _firestore
          .collection('classes')
          .where('teacherId', isEqualTo: teacherId)
          .get();

      final classes = snapshot.docs.map((doc) => doc.data()['name'].toString().toUpperCase()).toList();

      if (mounted) {
        setState(() {
          _explicitClasses = classes;
        });
      }
    } catch (e) {
      debugPrint("Error loading explicit classes: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoadingClasses = false);
      }
    }
  }

  // â”€â”€ Action 1: Create Class & Sequentially Provision Slots â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showCreateClassDialog() {
    _newClassController.clear();
    _studentCountController.clear();

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Create Class Folder', style: AppTextStyles.titleLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _newClassController,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  labelText: 'Class Name (e.g., 10 A, CS-B)',
                  prefixIcon: Icon(Icons.folder_open_rounded),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _studentCountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Total Students / Seats (e.g., 30)',
                  prefixIcon: Icon(Icons.groups_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _submitCreateClassBatch(dialogContext),
              child: const Text('Provision Class'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitCreateClassBatch(BuildContext dialogContext) async {
    final className = _newClassController.text.trim().toUpperCase();
    final countText = _studentCountController.text.trim();
    final int? studentCount = int.tryParse(countText);

    if (className.isEmpty || studentCount == null || studentCount <= 0) {
      _showSnackBar('Please enter a valid class name and student capacity count.');
      return;
    }

    final teacherId = context.read<AuthProvider>().user?.uid ?? '';
    Navigator.pop(dialogContext);

    if (mounted) setState(() => _isLoadingClasses = true);

    try {
      // 1. Create the persistent Class Folder document
      await _firestore.collection('classes').add({
        'name': className,
        'teacherId': teacherId,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // 2. High-Performance Atomic Batch Write to generate sequential unassigned roll numbers
      final batch = _firestore.batch();

      for (int i = 1; i <= studentCount; i++) {
        final studentId = _uuid.v4();
        final studentRef = _firestore.collection('students').doc(studentId);

        final placeholderMap = {
          'id': studentId,
          'name': 'Unassigned Slot', // Placeholder moniker flag
          'rollNumber': i.toString(), // Sequential Assignment
          'usn': '',
          'className': className,
          'section': '',
          'teacherId': teacherId,
        };

        batch.set(studentRef, placeholderMap);
      }

      await batch.commit(); // Push all slots atomicly to the cluster

      _refreshScreenData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Class $className provisioned with $studentCount sequential roll slots! ðŸ“')),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to compile structural grid: $e');
    } finally {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  // â”€â”€ Action 2: Assign Data into Provisioned Roll Position â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€â”€
  void _showAssignStudentDialog(StudentModel targetedSlot) {
    // If the profile card was unassigned, keep entry input empty, otherwise pre-fill for fast edits
    _nameController.text = targetedSlot.name == 'Unassigned Slot' ? '' : targetedSlot.name;
    _usnController.text = targetedSlot.usn;
    _sectionController.text = targetedSlot.section;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return AlertDialog(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Assign Identity Profile', style: AppTextStyles.titleLarge),
              Text('Class ${targetedSlot.className} â€¢ Roll Position No: ${targetedSlot.rollNumber}',
                  style: AppTextStyles.caption.copyWith(color: AppColors.primary, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(labelText: 'Student Full Name', prefixIcon: Icon(Icons.person_outline)),
                    validator: (v) => v!.isEmpty ? 'Name cannot remain blank' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _usnController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'USN / Seat Identity Code', prefixIcon: Icon(Icons.badge_outlined)),
                    validator: (v) => v!.isEmpty ? 'University number is required' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _sectionController,
                    textCapitalization: TextCapitalization.characters,
                    decoration: const InputDecoration(labelText: 'Section Code (e.g., A, B, C)', prefixIcon: Icon(Icons.grid_3x3)),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => _submitAssignStudent(dialogContext, targetedSlot),
              child: const Text('Lock Credentials'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAssignStudent(BuildContext dialogContext, StudentModel targetedSlot) async {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(dialogContext);
    if (mounted) setState(() => _isLoadingClasses = true);

    try {
      // Direct Firestore update pipeline to override the explicit position placeholders
      await _firestore.collection('students').doc(targetedSlot.id).update({
        'name': _nameController.text.trim(),
        'usn': _usnController.text.trim().toUpperCase(),
        'section': _sectionController.text.trim().toUpperCase(),
      });

      _refreshScreenData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Roll No ${targetedSlot.rollNumber} updated successfully! âœ…')),
        );
      }
    } catch (e) {
      if (mounted) _showSnackBar('Failed to register details: $e');
    } finally {
      if (mounted) setState(() => _isLoadingClasses = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentProvider = context.watch<StudentProvider>();
    final bool loadingState = studentProvider.isLoading || _isLoadingClasses;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Student Roster Directory')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateClassDialog,
        backgroundColor: AppColors.primary,
        icon: const Icon(Icons.create_new_folder_outlined, color: Colors.white),
        label: const Text('Create Class', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
      body: loadingState
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 90),
        children: [
          Text('Class Folders', style: AppTextStyles.headlineMedium),
          Text('Create class configurations, then expand tiles to assign data info directly to sequential roll positions.', style: AppTextStyles.caption),
          const SizedBox(height: 20),
          _buildDynamicClassGridSystem(studentProvider.students),
        ],
      ),
    );
  }

  Widget _buildDynamicClassGridSystem(List<StudentModel> students) {
    final Map<String, List<StudentModel>> masterClassMap = {};

    for (var explicitClass in _explicitClasses) {
      if (explicitClass.isNotEmpty) {
        masterClassMap[explicitClass] = [];
      }
    }

    for (var student in students) {
      final className = student.className.trim().toUpperCase();
      if (className.isNotEmpty) {
        masterClassMap.putIfAbsent(className, () => []).add(student);
      }
    }

    if (masterClassMap.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.only(top: 60.0),
          child: Column(
            children: [
              Icon(Icons.folder_open_outlined, size: 54, color: AppColors.textDisabled),
              const SizedBox(height: 12),
              Text('No Classes Found', style: AppTextStyles.titleMedium),
              Text('Tap "Create Class" below to build your structured workspace.', textAlign: TextAlign.center, style: AppTextStyles.caption),
            ],
          ),
        ),
      );
    }

    final sortedClassEntries = masterClassMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Column(
      children: sortedClassEntries.map((entry) {
        final String className = entry.key;
        final List<StudentModel> classRoster = entry.value;

        // Force bulletproof numeric sequence order sorting
        classRoster.sort((a, b) {
          final int? rollA = int.tryParse(a.rollNumber);
          final int? rollB = int.tryParse(b.rollNumber);
          if (rollA != null && rollB != null) return rollA.compareTo(rollB);
          return a.rollNumber.compareTo(b.rollNumber);
        });

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
              leading: Icon(
                classRoster.isEmpty ? Icons.create_new_folder_rounded : Icons.folder_shared_rounded,
                color: classRoster.isEmpty ? Colors.grey.shade400 : Colors.amber,
                size: 24,
              ),
              title: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Class: $className', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold)),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep_outlined, color: AppColors.error, size: 20),
                    tooltip: 'Delete Class Room Folder',
                    onPressed: () => _confirmClassDeletion(className),
                    constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
              subtitle: Text('${classRoster.length} positional assignments inside', style: AppTextStyles.caption),
              childrenPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                if (classRoster.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Text('Roster generation initialization missing.', textAlign: TextAlign.center),
                  )
                else
                  ...classRoster.map((student) {
                    final bool isUnassigned = student.name == 'Unassigned Slot';

                    return Container(
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isUnassigned ? AppColors.background.withValues(alpha: 0.3) : AppColors.background,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isUnassigned ? AppColors.border.withValues(alpha: 0.3) : AppColors.border.withValues(alpha: 0.6),
                        ),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: isUnassigned
                                ? Colors.grey.withValues(alpha: 0.1)
                                : AppColors.primary.withValues(alpha: 0.08),
                            child: Text(
                              student.rollNumber,
                              style: TextStyle(
                                  color: isUnassigned ? Colors.grey : AppColors.primary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  student.name,
                                  style: AppTextStyles.titleMedium.copyWith(
                                    color: isUnassigned ? Colors.grey.shade500 : AppColors.textPrimary,
                                    fontStyle: isUnassigned ? FontStyle.italic : FontStyle.normal,
                                  ),
                                ),
                                Text(
                                  isUnassigned
                                      ? 'Position Open'
                                      : 'USN: ${student.usn} â€¢ Sec: ${student.section.isEmpty ? "N/A" : student.section}',
                                  style: AppTextStyles.caption,
                                ),
                              ],
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: () => _showAssignStudentDialog(student),
                            icon: Icon(isUnassigned ? Icons.add_rounded : Icons.edit_rounded, size: 14),
                            label: Text(isUnassigned ? 'Fill info' : 'Edit'),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              backgroundColor: isUnassigned
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : Colors.grey.withValues(alpha: 0.08),
                              foregroundColor: isUnassigned ? AppColors.primary : AppColors.textSecondary,
                              elevation: 0,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
        );
      }).toList(),
    ).animate().fadeIn(duration: 400.ms);
  }

  void _confirmClassDeletion(String className) {
    final teacherId = context.read<AuthProvider>().user?.uid ?? '';

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('Delete Class $className?'),
          content: Text('This will permanently delete this class folder and ALL sequential slots inside it. This action cannot be reversed.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Cancel')),
            TextButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                if (!mounted) return;
                setState(() => _isLoadingClasses = true);

                try {
                  final classDocs = await _firestore
                      .collection('classes')
                      .where('teacherId', isEqualTo: teacherId)
                      .where('name', isEqualTo: className)
                      .get();

                  for (var doc in classDocs.docs) {
                    await doc.reference.delete();
                  }

                  final studentDocs = await _firestore
                      .collection('students')
                      .where('teacherId', isEqualTo: teacherId)
                      .where('className', isEqualTo: className)
                      .get();

                  for (var doc in studentDocs.docs) {
                    await doc.reference.delete();
                  }

                  _refreshScreenData();

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Class $className swept cleanly from server storage.')),
                    );
                  }
                } catch (e) {
                  if (mounted) _showSnackBar('Error clearing folder: $e');
                } finally {
                  if (mounted) setState(() => _isLoadingClasses = false);
                }
              },
              child: const Text('Delete Everything', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
