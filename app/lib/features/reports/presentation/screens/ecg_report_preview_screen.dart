import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/models/ecg_analysis_result.dart';
import '../../../../shared/widgets/full_screen_image_viewer.dart';
import 'annotation_screen.dart';
import 'pdf_view_screen.dart';

class EcgReportPreviewScreen extends StatefulWidget {
  final XFile imageFile;
  final EcgAnalysisResult result;
  final String patientId;
  final String patientName;
  final String dob;
  final String email;

  const EcgReportPreviewScreen({
    super.key,
    required this.imageFile,
    required this.result,
    required this.patientId,
    required this.patientName,
    required this.dob,
    required this.email,
  });

  @override
  State<EcgReportPreviewScreen> createState() => _EcgReportPreviewScreenState();
}

class _EcgReportPreviewScreenState extends State<EcgReportPreviewScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  
  // Checklist items
  bool _verifiedPatientId = false;
  bool _verifiedSignalQuality = false;
  bool _clinicalCorrelation = false;
  bool _findingsReviewed = false;

  Map<String, dynamic>? _usageStats;
  bool _isLoadingUsage = true;
  String? _quotaError;
  bool _isGenerating = false;
  final List<Uint8List> _markedImages = [];

  @override
  void initState() {
    super.initState();
    _fetchUsageStats();
  }

  Future<void> _fetchUsageStats() async {
    try {
      final stats = await _apiService.getUsageStats();
      if (mounted) {
        setState(() {
          _usageStats = stats;
          _isLoadingUsage = false;
          _checkStorageQuota();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsage = false);
    }
  }

  Future<void> _checkStorageQuota() async {
    if (_usageStats == null) return;
    final int used = _usageStats!['storage_used_bytes'] ?? 0;
    final int limit = 1 * 1024 * 1024 * 1024; // 1 GB
    if (used > limit * 0.95) {
      setState(() => _quotaError = "Storage limit nearly reached.");
    }
  }

  bool get _canGenerate => 
      _verifiedPatientId && 
      _verifiedSignalQuality && 
      _clinicalCorrelation && 
      _findingsReviewed &&
      !_isGenerating;

  Future<void> _generateReport() async {
    if (!_canGenerate) return;

    setState(() => _isGenerating = true);
    
    try {
      final bytes = await widget.imageFile.readAsBytes();
      final originalBase64 = base64Encode(bytes);
      
      final pdfBytes = await _apiService.downloadReport(
        patientId: widget.patientId,
        patientName: widget.patientName,
        dob: widget.dob,
        email: widget.email,
        findings: {
            ...widget.result.metrics,
            'findings': widget.result.findings,
            'doctor_notes': _notesController.text,
        },
        originalImageBase64: originalBase64,
        waveformImageBase64: widget.result.waveformBase64,
        doctorMarkedImages: _markedImages.map((e) => base64Encode(e)).toList(),
        isEcg: true,
        shouldDownload: false,
      );

      if (pdfBytes != null && mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => PdfViewScreen(
              pdfBytes: pdfBytes,
              patientId: widget.patientId,
              patientName: widget.patientName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('ECG Clinical Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildPatientCard(),
            const SizedBox(height: 20),
            _buildVisualVerification(theme),
            const SizedBox(height: 20),
            _buildChecklist(),
            const SizedBox(height: 16),
            _buildNotesField(),
            const SizedBox(height: 24),
            _buildGenerateButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildPatientCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const Divider(),
            Text('Name: ${widget.patientName}'),
            Text('Report ID: ${widget.patientId}'),
            Text('DOB: ${widget.dob}'),
            Text('Email: ${widget.email}'),
          ],
        ),
      ),
    );
  }

  Widget _buildVisualVerification(ThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('Visual Verification', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final bytes = await widget.imageFile.readAsBytes();
                      if (!mounted) return;
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FullScreenImageViewer(imageBytes: bytes, title: 'Original Paper ECG'),
                      ));
                    },
                    icon: const Icon(Icons.image),
                    label: const Text('View Paper Scan'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.draw_outlined),
                  tooltip: 'Annotate Paper Scan',
                  onPressed: () async {
                    final bytes = await widget.imageFile.readAsBytes();
                    if (!mounted) return;
                    final Uint8List? marked = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AnnotationScreen(
                          imageBytes: bytes,
                          title: 'Annotate Paper ECG',
                        ),
                      ),
                    );
                    if (marked != null) {
                      setState(() {
                        _markedImages.add(marked);
                      });
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(MaterialPageRoute(
                        builder: (context) => FullScreenImageViewer(
                          imageBytes: base64Decode(widget.result.waveformBase64),
                          title: 'Digitized Tracing',
                        ),
                      ));
                    },
                    icon: const Icon(Icons.auto_graph),
                    label: const Text('View Digitized'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.draw_outlined),
                  tooltip: 'Annotate Digitized Tracing',
                  onPressed: () async {
                    if (!mounted) return;
                    final Uint8List? marked = await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => AnnotationScreen(
                          imageBytes: base64Decode(widget.result.waveformBase64),
                          title: 'Annotate Digitized Tracing',
                        ),
                      ),
                    );
                    if (marked != null) {
                      setState(() {
                        _markedImages.add(marked);
                      });
                    }
                  },
                ),
              ],
            ),
            if (_markedImages.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (int i = 0; i < _markedImages.length; i++)
                    Stack(
                      children: [
                        Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: Image.memory(_markedImages[i], fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          right: -10,
                          top: -10,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, size: 20, color: Colors.red),
                            onPressed: () => setState(() => _markedImages.removeAt(i)),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              const Text('Marked images will be appended to the report', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChecklist() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Verification Checklist', style: TextStyle(fontWeight: FontWeight.bold)),
        CheckboxListTile(
          title: const Text('Patient Identity Confirmed'),
          value: _verifiedPatientId,
          onChanged: (v) => setState(() => _verifiedPatientId = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        CheckboxListTile(
          title: const Text('Signal Reconstruction Accurate'),
          value: _verifiedSignalQuality,
          onChanged: (v) => setState(() => _verifiedSignalQuality = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        CheckboxListTile(
          title: const Text('Findings Reviewed & Validated'),
          value: _findingsReviewed,
          onChanged: (v) => setState(() => _findingsReviewed = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
        CheckboxListTile(
          title: const Text('Clinical Correlation Complete'),
          value: _clinicalCorrelation,
          onChanged: (v) => setState(() => _clinicalCorrelation = v ?? false),
          controlAffinity: ListTileControlAffinity.leading,
          dense: true,
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return TextField(
      controller: _notesController,
      decoration: const InputDecoration(
        labelText: 'Clinical Notes / Cardiologist Recommendations',
        border: OutlineInputBorder(),
        hintText: 'Enter specific observations or next steps...',
      ),
      maxLines: 4,
    );
  }

  Widget _buildGenerateButton() {
    return ElevatedButton(
      onPressed: _canGenerate ? _generateReport : null,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      child: _isGenerating 
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : const Text('GENERATE CLINICAL REPORT'),
    );
  }
}
