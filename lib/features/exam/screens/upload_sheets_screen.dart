import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routes/app_router.dart';

class UploadSheetsScreen extends StatefulWidget {
  const UploadSheetsScreen({super.key});

  @override
  State<UploadSheetsScreen> createState() => _UploadSheetsScreenState();
}

class _UploadSheetsScreenState extends State<UploadSheetsScreen> {
  final List<UploadedSheet> _uploadedSheets = [];
  bool _isUploading = false;

  void _pickFile() async {
    setState(() => _isUploading = true);
    await Future.delayed(const Duration(seconds: 2));
    setState(() {
      _isUploading = false;
      _uploadedSheets.add(
        UploadedSheet(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          studentName: 'Student ${_uploadedSheets.length + 1}',
          fileName: 'answer_sheet_${_uploadedSheets.length + 1}.pdf',
          status: UploadStatus.uploaded,
          uploadedAt: DateTime.now(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Upload Answer Sheets')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          _buildUploadArea(),
          const SizedBox(height: 24),
          if (_uploadedSheets.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Uploaded Sheets (${_uploadedSheets.length})',
                    style: AppTextStyles.headlineMedium),
                TextButton(
                  onPressed: () {},
                  child: Text('Process All',
                      style: AppTextStyles.labelMedium
                          .copyWith(color: AppColors.primary)),
                ),
              ],
            ).animate().fadeIn(duration: 400.ms),
            const SizedBox(height: 16),
            ..._uploadedSheets.asMap().entries.map(
                  (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _buildSheetCard(entry.value, entry.key),
              ),
            ),
          ],
          if (_uploadedSheets.isEmpty && !_isUploading) _buildEmptyState(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isUploading ? null : _pickFile,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: _isUploading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        )
            : const Icon(Icons.upload_file_outlined),
        label: Text(
          _isUploading ? 'Uploading...' : 'Upload Sheet',
          style: AppTextStyles.labelMedium.copyWith(color: Colors.white),
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return GestureDetector(
      onTap: _isUploading ? null : _pickFile,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 40),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.cloud_upload_outlined,
                  size: 32, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text('Upload Answer Sheets', style: AppTextStyles.titleLarge),
            const SizedBox(height: 8),
            Text('Tap to select PDF or Image files',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildFormatChip('PDF'),
                const SizedBox(width: 8),
                _buildFormatChip('JPG'),
                const SizedBox(width: 8),
                _buildFormatChip('PNG'),
              ],
            ),
          ],
        ),
      ),
    ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildFormatChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label, style: AppTextStyles.caption),
    );
  }

  Widget _buildSheetCard(UploadedSheet sheet, int index) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.picture_as_pdf_outlined,
                color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sheet.studentName, style: AppTextStyles.titleMedium),
                const SizedBox(height: 2),
                Text(sheet.fileName, style: AppTextStyles.caption),
              ],
            ),
          ),
          _buildStatusBadge(sheet.status),
          const SizedBox(width: 8),
          IconButton(
            onPressed: () {
              Navigator.pushNamed(context, AppRoutes.ocrProcessing);
            },
            icon: const Icon(Icons.play_circle_outline),
            style: IconButton.styleFrom(foregroundColor: AppColors.primary),
          ),
        ],
      ),
    )
        .animate()
        .fadeIn(delay: Duration(milliseconds: 100 * index), duration: 400.ms)
        .slideX(begin: 0.2, end: 0);
  }

  Widget _buildStatusBadge(UploadStatus status) {
    Color color;
    String label;
    switch (status) {
      case UploadStatus.uploaded:
        color = AppColors.success;
        label = 'Uploaded';
        break;
      case UploadStatus.processing:
        color = AppColors.warning;
        label = 'Processing';
        break;
      case UploadStatus.evaluated:
        color = AppColors.primary;
        label = 'Evaluated';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: AppTextStyles.caption
              .copyWith(color: color, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Icon(Icons.inbox_outlined, size: 64, color: AppColors.textDisabled),
          const SizedBox(height: 16),
          Text('No sheets uploaded yet',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 8),
          Text('Upload student answer sheets to begin evaluation',
              style: AppTextStyles.bodyMedium, textAlign: TextAlign.center),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms, duration: 400.ms);
  }
}

enum UploadStatus { uploaded, processing, evaluated }

class UploadedSheet {
  final String id;
  final String studentName;
  final String fileName;
  final UploadStatus status;
  final DateTime uploadedAt;

  UploadedSheet({
    required this.id,
    required this.studentName,
    required this.fileName,
    required this.status,
    required this.uploadedAt,
  });
}
