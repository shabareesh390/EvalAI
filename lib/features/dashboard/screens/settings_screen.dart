import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
// FIXED: Hidden name collision interface to clear the ambiguous compiler error
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:shared_preferences/shared_preferences.dart'; // INTEGRATED: Local persistence
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routes/app_router.dart';
import '../../authentication/providers/auth_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // ── Settings State ─────────────────────────────────────────────────────
  bool _spellCheck = false;
  bool _negativeMarking = false;
  bool _autoEvaluate = true;
  bool _notifications = true;
  double _graceMarks = 0;
  double _aiStrictness = 0.5;
  String _aiLevel = 'Balanced';
  double _spellCheckDeduction = 1.0;

  @override
  void initState() {
    super.initState();
    _loadPersistedSettings(); // Pull configurations out of local storage on initialization
  }

  // ── Persistence Methods ────────────────────────────────────────────────
  Future<void> _loadPersistedSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _spellCheck = prefs.getBool('setting_spell_check') ?? false;
      _negativeMarking = prefs.getBool('setting_negative_marking') ?? false;
      _autoEvaluate = prefs.getBool('setting_auto_evaluate') ?? true;
      _notifications = prefs.getBool('setting_notifications') ?? true;
      _graceMarks = prefs.getDouble('setting_grace_marks') ?? 0.0;
      _aiStrictness = prefs.getDouble('setting_ai_strictness') ?? 0.5;
      _aiLevel = prefs.getString('setting_ai_level') ?? 'Balanced';
      _spellCheckDeduction =
          prefs.getDouble('setting_spell_check_deduction') ?? 1.0;
    });
  }

  Future<void> _updateBoolPreference(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  Future<void> _updateDoublePreference(String key, double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(key, value);
  }

  Future<void> _updateStringPreference(String key, String value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, value);
  }

  // ── Update Profile Picture ──────────────────────────────────────────────
  Future<void> _updateProfilePicture() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Uploading profile picture...')),
      );

      final ref = FirebaseStorage.instance.ref().child(
        'users/${user.uid}/profile.jpg',
      );
      await ref.putFile(File(pickedFile.path));
      final url = await ref.getDownloadURL();

      await user.updatePhotoURL(url);
      await user.reload();

      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile picture updated!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to update picture: $e')));
      }
    }
  }

  // ── Edit Name Dialog Form ──────────────────────────────────────────────
  void _showEditNameDialog(String currentName) {
    final nameController = TextEditingController(text: currentName);
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Edit Profile Name'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Display Name',
                prefixIcon: Icon(Icons.person_outline),
              ),
              validator: (v) =>
                  v!.trim().isEmpty ? 'Name cannot be empty' : null,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                if (!formKey.currentState!.validate()) return;
                final newName = nameController.text.trim();
                Navigator.pop(dialogContext);

                try {
                  await FirebaseAuth.instance.currentUser?.updateDisplayName(
                    newName,
                  );

                  if (mounted) {
                    setState(() {}); // Re-render local display references
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Profile name updated successfully! 🎉'),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to update name: $e')),
                    );
                  }
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  // ── About Dialog ───────────────────────────────────────────────────────
  void _showAboutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('About EvalAI'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Empowering Educators with Intelligent Evaluation',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  'EvalAI is an advanced AI-powered grading assistant designed to transform the way educators assess student performance. By leveraging cutting-edge machine learning and optical character recognition (OCR) technology, EvalAI helps teachers:',
                ),
                const SizedBox(height: 12),
                const Text(
                  '• Save Time: Reduce hours of manual grading to minutes.',
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Maintain Consistency: Ensure uniform scoring criteria across all student submissions.',
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Provide Actionable Insights: Generate detailed feedback that helps students identify their strengths and areas for improvement.',
                ),
                const SizedBox(height: 4),
                const Text(
                  '• Digitize the Classroom: Seamlessly move from handwritten answer sheets to a structured, digital grading workflow.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Our mission is to support educators in focusing on what matters most—teaching and student success.',
                ),
              ],
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

  // ── Help & Support Dialog ──────────────────────────────────────────────
  void _showHelpSupportDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Help & Support'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'We are here to assist you.',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Need help getting started or running into an issue? Review the frequently asked questions or contact our support team.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Frequently Asked Questions (FAQ)',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 12),
                const Text(
                  'How do I ensure accurate grading?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'For best results, ensure the student answer sheet is well-lit and clearly photographed. Use high-resolution scans or photos and ensure the handwriting is legible.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'Why does my grading show as \'Pending\' or display errors?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Grading is processed in two phases. If you receive a \'Quota Exceeded\' or system error, it usually means the service is busy. Please wait 60 seconds and tap \'Evaluate\' again.',
                ),
                const SizedBox(height: 12),
                const Text(
                  'How do I delete old exam records?',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Navigate to your \'Recent Exams\' dashboard. You can swipe left on an entry to reveal the delete option, or tap the entry to view details and find the delete button.',
                ),
                const SizedBox(height: 16),
                const Text(
                  'Contact Support',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                const Text(
                  'If you continue to experience issues, our support team is available 24/7.',
                ),
                const SizedBox(height: 8),
                const Text(
                  'Email: shabareesh390@gmail.com\nIn-App: Tap the \'Report a Bug\' button in the settings menu.',
                ),
              ],
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
    final authProvider = context.watch<AuthProvider>();
    final userName = authProvider.user?.displayName ?? 'Teacher';
    final userEmail = authProvider.user?.email ?? '';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          // ── Profile Card ───────────────────────────────────────────────
          _buildProfileCard(userName, userEmail),

          const SizedBox(height: 24),

          // ── Evaluation Settings ────────────────────────────────────────
          _buildSectionHeader('Evaluation Settings'),
          const SizedBox(height: 12),
          _buildEvaluationSettings(),

          const SizedBox(height: 24),

          // ── AI Settings ────────────────────────────────────────────────
          _buildSectionHeader('AI Settings'),
          const SizedBox(height: 12),
          _buildAiSettings(),

          const SizedBox(height: 24),

          // ── Notification Settings ──────────────────────────────────────
          _buildSectionHeader('Notifications'),
          const SizedBox(height: 12),
          _buildNotificationSettings(),

          const SizedBox(height: 24),

          // ── Account ────────────────────────────────────────────────────
          _buildSectionHeader('Account'),
          const SizedBox(height: 12),
          _buildAccountSettings(),

          const SizedBox(height: 32),

          // ── Logout Button ──────────────────────────────────────────────
          _buildLogoutButton(),

          const SizedBox(height: 16),

          // ── App Version ───────────────────────────────────────────────
          Center(child: Text('EvalAI v1.0.0', style: AppTextStyles.caption)),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildProfileCard(String name, String email) {
    final photoUrl = FirebaseAuth.instance.currentUser?.photoURL;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: _updateProfilePicture,
            child: Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                  backgroundImage: photoUrl != null
                      ? NetworkImage(photoUrl)
                      : null,
                  child: photoUrl == null
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: AppTextStyles.headlineLarge.copyWith(
                            color: Colors.white,
                          ),
                        )
                      : null,
                ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 12,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: AppTextStyles.titleLarge.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 4),
                Text(
                  email,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => _showEditNameDialog(name),
            icon: const Icon(Icons.edit_outlined),
            style: IconButton.styleFrom(foregroundColor: Colors.white),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: AppTextStyles.titleMedium.copyWith(color: AppColors.textSecondary),
    ).animate().fadeIn(duration: 400.ms);
  }

  Widget _buildEvaluationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          _buildToggleTile(
            icon: Icons.spellcheck_rounded,
            title: 'Spell Check',
            subtitle: 'Deduct marks for spelling mistakes',
            value: _spellCheck,
            onChanged: (v) {
              setState(() => _spellCheck = v);
              _updateBoolPreference('setting_spell_check', v);
            },
          ),
          if (_spellCheck) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Deduction per Mistake',
                        style: AppTextStyles.bodyMedium,
                      ),
                      Text(
                        '-${_spellCheckDeduction.toStringAsFixed(1)} Marks',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.error,
                        ),
                      ),
                    ],
                  ),
                  Slider(
                    value: _spellCheckDeduction,
                    min: 0.5,
                    max: 5.0,
                    divisions: 9,
                    activeColor: AppColors.error,
                    inactiveColor: AppColors.border,
                    onChanged: (v) {
                      setState(() => _spellCheckDeduction = v);
                      _updateDoublePreference(
                        'setting_spell_check_deduction',
                        v,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
          _buildDivider(),
          _buildToggleTile(
            icon: Icons.remove_circle_outline,
            title: 'Negative Marking',
            subtitle: 'Deduct marks for wrong answers',
            value: _negativeMarking,
            onChanged: (v) {
              setState(() => _negativeMarking = v);
              _updateBoolPreference('setting_negative_marking', v);
            },
          ),
          _buildDivider(),
          _buildToggleTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Auto Evaluate',
            subtitle: 'Automatically evaluate high confidence OCR',
            value: _autoEvaluate,
            onChanged: (v) {
              setState(() => _autoEvaluate = v);
              _updateBoolPreference('setting_auto_evaluate', v);
            },
          ),
          _buildDivider(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.star_outline,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Grace Marks',
                              style: AppTextStyles.titleMedium,
                            ),
                            Text(
                              'Extra marks to award',
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ],
                    ),
                    Text(
                      '${_graceMarks.toInt()}',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                Slider(
                  value: _graceMarks,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() => _graceMarks = v);
                    _updateDoublePreference('setting_grace_marks', v);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms, duration: 400.ms);
  }

  Widget _buildAiSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.tune_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AI Strictness',
                              style: AppTextStyles.titleMedium,
                            ),
                            Text(_aiLevel, style: AppTextStyles.caption),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                Slider(
                  value: _aiStrictness,
                  min: 0,
                  max: 1,
                  activeColor: AppColors.primary,
                  onChanged: (v) {
                    setState(() {
                      _aiStrictness = v;
                      if (v < 0.33) {
                        _aiLevel = 'Lenient';
                      } else if (v < 0.66) {
                        _aiLevel = 'Balanced';
                      } else {
                        _aiLevel = 'Strict';
                      }
                    });
                    _updateDoublePreference('setting_ai_strictness', v);
                    _updateStringPreference('setting_ai_level', _aiLevel);
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Lenient', style: AppTextStyles.caption),
                    Text('Balanced', style: AppTextStyles.caption),
                    Text('Strict', style: AppTextStyles.caption),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms, duration: 400.ms);
  }

  Widget _buildNotificationSettings() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: _buildToggleTile(
        icon: Icons.notifications_outlined,
        title: 'Push Notifications',
        subtitle: 'Get notified when evaluation is complete',
        value: _notifications,
        onChanged: (v) {
          setState(() => _notifications = v);
          _updateBoolPreference('setting_notifications', v);
        },
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }

  // FIXED: Wrapped account settings in Material layout to permit ripple interactions correctly
  Widget _buildAccountSettings() {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: AppColors.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            _buildActionTile(
              icon: Icons.lock_outline,
              title: 'Change Password',
              onTap: () =>
                  Navigator.pushNamed(context, AppRoutes.forgotPassword),
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.help_outline,
              title: 'Help & Support',
              onTap: _showHelpSupportDialog,
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.info_outline,
              title: 'About EvalAI',
              onTap: _showAboutDialog,
            ),
            _buildDivider(),
            _buildActionTile(
              icon: Icons.bug_report_outlined,
              title: 'Report a Bug',
              onTap: () async {
                final Uri emailUri = Uri.parse(
                  'mailto:shabareesh390@gmail.com?subject=EvalAI%20Bug%20Report',
                );
                try {
                  await launchUrl(emailUri);
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Could not launch email client'),
                      ),
                    );
                  }
                }
              },
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 400.ms, duration: 400.ms);
  }

  Widget _buildLogoutButton() {
    return OutlinedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Logout'),
            content: const Text('Are you sure you want to logout?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                child: const Text('Logout'),
              ),
            ],
          ),
        );

        if (confirm == true && mounted) {
          await context.read<AuthProvider>().signOut();
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              AppRoutes.login,
              (route) => false,
            );
          }
        }
      },
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: const BorderSide(color: AppColors.error),
        minimumSize: const Size(double.infinity, 52),
      ),
      icon: const Icon(Icons.logout_rounded),
      label: const Text('Logout'),
    ).animate().fadeIn(delay: 500.ms, duration: 400.ms);
  }

  Widget _buildToggleTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleMedium),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Switch(
            value: value,
            onChanged: onChanged,
            activeThumbColor: AppColors.primary,
          ),
        ],
      ),
    );
  }

  // FIXED: Replaced default ListTile hook with interactive Inkwell structure to repair tap UI
  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: AppColors.primary, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppTextStyles.titleMedium)),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.textDisabled,
            ),
          ],
        ),
      ),
    );
  }

  // FIXED: Added color boundary formatting
  Widget _buildDivider() {
    return const Divider(
      height: 1,
      thickness: 1,
      indent: 64,
      endIndent: 16,
      color: AppColors.border,
    );
  }
}
