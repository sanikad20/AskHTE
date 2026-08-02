import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../services/storage_service.dart';
import '../theme/app_theme.dart';

class UploadDocumentScreen extends StatefulWidget {
  const UploadDocumentScreen({super.key});

  @override
  State<UploadDocumentScreen> createState() => _UploadDocumentScreenState();
}

class _UploadDocumentScreenState extends State<UploadDocumentScreen> {
  final StorageService _storageService = StorageService();
  final TextEditingController _equipmentController = TextEditingController();

  bool _loading = false;
  String? _fileName;
  int? _fileSize;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _pickAndUpload() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf'],
    );

    if (picked == null || picked.files.single.path == null) {
      return;
    }

    final file = File(picked.files.single.path!);

    setState(() {
      _loading = true;
      _error = null;
      _result = null;
      _fileName = picked.files.single.name;
      _fileSize = picked.files.single.size;
    });

    try {
      final result = await _storageService.uploadAndIngest(
        file,
        picked.files.single.name,
        equipmentId: _equipmentController.text.trim().isEmpty
            ? null
            : _equipmentController.text.trim(),
      );

      setState(() {
        _loading = false;
        _result = result;
      });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  @override
  void dispose() {
    _equipmentController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ingest Government Document'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Modern Header Card
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                    border: Border.all(color: AppColors.primary.withOpacity(0.15)),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.verified_user, color: AppColors.primary, size: 28),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Authenticated Ingestion Engine',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              'PDF documents are chunked, embedded, and indexed into ChromaDB for grounded RAG QA.',
                              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Optional Reference ID input
                TextField(
                  controller: _equipmentController,
                  decoration: const InputDecoration(
                    labelText: 'Government Resolution / Circular No. (Optional)',
                    hintText: 'e.g. GR-2026/HTE-89',
                    prefixIcon: Icon(Icons.pin_outlined, color: AppColors.primary),
                  ),
                ),
                const SizedBox(height: AppSpacing.lg),

                // Drag & Drop Upload Zone Card
                InkWell(
                  onTap: _loading ? null : _pickAndUpload,
                  borderRadius: BorderRadius.circular(AppRadius.xl),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(AppRadius.xl),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.4),
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.cloud_upload_outlined, size: 42, color: AppColors.primary),
                        ),
                        const SizedBox(height: 14),
                        const Text(
                          'Tap to select PDF Government Document',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Supports official GRs, Notices, & Circular PDFs',
                          style: TextStyle(fontSize: 12, color: AppColors.textFaint),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),

                // Loading State with Shimmer
                if (_loading) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                    ),
                    child: Column(
                      children: [
                        const LinearProgressIndicator(color: AppColors.primary),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            const Icon(Icons.picture_as_pdf, color: AppColors.primary, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _fileName ?? 'Uploading...',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                            ),
                            if (_fileSize != null)
                              Text(
                                '${(_fileSize! / 1024).toStringAsFixed(1)} KB',
                                style: const TextStyle(fontSize: 11, color: AppColors.textFaint),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],

                // Error Card
                if (_error != null) ...[
                  Card(
                    color: AppColors.dangerBg,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.lg)),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.danger),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(_error!, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                // Success Result Card
                if (_result != null) ...[
                  Card(
                    color: AppColors.successBg,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppRadius.lg),
                      side: const BorderSide(color: AppColors.success, width: 1),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.check_circle, color: AppColors.success, size: 22),
                              SizedBox(width: 8),
                              Text(
                                'Ingestion Complete! 🔒',
                                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.success),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text('File Name: $_fileName', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                          Text('Document ID: ${_result!['docId']}', style: const TextStyle(fontSize: 12.5)),
                          Text('Pages Processed: ${_result!['pageCount']}', style: const TextStyle(fontSize: 12.5)),
                          Text('Vector Chunks Created: ${_result!['chunkCount']}', style: const TextStyle(fontSize: 12.5)),
                          const SizedBox(height: 12),
                          if ((_result!['equipmentTags'] as List? ?? []).isNotEmpty) ...[
                            const Text('Extracted Reference Tags:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            const SizedBox(height: 4),
                            Wrap(
                              spacing: 6,
                              children: List<String>.from(_result!['equipmentTags'])
                                  .map((tag) => Chip(
                                        label: Text(tag, style: const TextStyle(fontSize: 11)),
                                        backgroundColor: AppColors.primary.withOpacity(0.1),
                                      ))
                                  .toList(),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}