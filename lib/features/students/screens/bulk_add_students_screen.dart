import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/widgets/custom_button.dart';
import '../../../core/widgets/custom_text_field.dart';
class BulkAddStudentsScreen extends StatefulWidget {
  const BulkAddStudentsScreen({super.key});

  @override
  State<BulkAddStudentsScreen> createState() => _BulkAddStudentsScreenState();
}

class _BulkAddStudentsScreenState extends State<BulkAddStudentsScreen> {
  int _currentStep = 0;
  bool _isSaving = false;

  // Step 1 Controllers
  final _classController = TextEditingController();
  final _countController = TextEditingController();

  // Step 2 Controllers
  List<TextEditingController> _nameControllers = [];

  void _generateSlots() {
    final count = int.tryParse(_countController.text) ?? 0;
    if (_classController.text.isEmpty || count <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid class and student count.')),
      );
      return;
    }

    setState(() {
      _nameControllers = List.generate(count, (index) => TextEditingController());
      _currentStep = 1;
    });
  }

  Future<void> _saveStudentsToFirebase() async {
    setState(() => _isSaving = true);

    try {
      final teacherId = FirebaseAuth.instance.currentUser?.uid;
      if (teacherId == null) throw Exception("Not logged in");

      // High-speed write: Upload all students simultaneously
      final batch = FirebaseFirestore.instance.batch();
      int addedCount = 0;

      for (int i = 0; i < _nameControllers.length; i++) {
        final name = _nameControllers[i].text.trim();
        if (name.isNotEmpty) {
          final docRef = FirebaseFirestore.instance.collection('students').doc();
          batch.set(docRef, {
            'studentId': docRef.id,
            'teacherId': teacherId,
            'className': _classController.text.trim(),
            'rollNumber': i + 1,
            'name': name,
            'createdAt': FieldValue.serverTimestamp(),
          });
          addedCount++;
        }
      }

      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Successfully saved $addedCount students! ðŸŽ‰')),
        );
        Navigator.pop(context); // Go back to student dashboard
      }
    } catch (e) {
      setState(() => _isSaving = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving students: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Add Class Batch')),
      body: _isSaving
          ? const Center(child: CircularProgressIndicator())
          : Theme(
              data: Theme.of(context).copyWith(
                colorScheme: Theme.of(context).colorScheme.copyWith(primary: AppColors.primary),
              ),
              child: Stepper(
                currentStep: _currentStep,
                onStepCancel: () => setState(() => _currentStep = 0),
                onStepContinue: _currentStep == 0 ? _generateSlots : _saveStudentsToFirebase,
                controlsBuilder: (context, details) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 24.0),
                    child: Row(
                      children: [
                        Expanded(
                          child: CustomButton(
                            text: _currentStep == 0 ? 'Generate Slots' : 'Save All Students',
                            onPressed: details.onStepContinue ?? () {},
                          ),
                        ),
                        if (_currentStep != 0) ...[
                          const SizedBox(width: 16),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: details.onStepCancel,
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                side: const BorderSide(color: AppColors.border),
                                minimumSize: const Size(double.infinity, 52),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                              ),
                              child: const Text('Back'),
                            ),
                          ),
                        ],
                      ],
                    ),
                  );
                },
                steps: [
                  Step(
                    title: Text('Class Details', style: AppTextStyles.titleMedium),
                    isActive: _currentStep >= 0,
                    content: Container(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Column(
                        children: [
                          CustomTextField(
                            controller: _classController,
                            label: 'Class Name (e.g., 10th A)',
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                          const SizedBox(height: 16),
                          CustomTextField(
                            controller: _countController,
                            label: 'Total Number of Students',
                            prefixIcon: const Icon(Icons.groups_outlined),
                            keyboardType: TextInputType.number,
                          ),
                        ],
                      ),
                    ),
                  ),
                  Step(
                    title: Text('Enter Student Names', style: AppTextStyles.titleMedium),
                    isActive: _currentStep >= 1,
                    content: _nameControllers.isEmpty
                        ? const SizedBox.shrink()
                        : SizedBox(
                            height: MediaQuery.of(context).size.height * 0.45,
                            child: ListView.builder(
                              itemCount: _nameControllers.length,
                              itemBuilder: (context, index) {
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12.0),
                                  child: CustomTextField(
                                    controller: _nameControllers[index],
                                    label: 'Roll No. ${index + 1} Name',
                                    prefixIcon: const Icon(Icons.person_outline),
                                    textInputAction: TextInputAction.next,
                                  ),
                                );
                              },
                            ),
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}
