import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb; 
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Add import
import '../../../../core/services/api_service.dart';
import '../../../../shared/models/analysis_result.dart';
import '../../../../shared/widgets/full_screen_image_viewer.dart';
import '../../../../shared/widgets/full_screen_analysis_viewer.dart';
import 'pdf_view_screen.dart';
import 'annotation_screen.dart';

class ReportPreviewScreen extends StatefulWidget {
  final XFile imageFile;
  final AnalysisResult result;
  
  // New Fields
  final String patientId;
  final String patientName;
  final String dob;
  final String email;

  const ReportPreviewScreen({
    super.key,
    required this.imageFile,
    required this.result,
    required this.patientId,
    required this.patientName,
    required this.dob,
    required this.email,
  });

  @override
  State<ReportPreviewScreen> createState() => _ReportPreviewScreenState();
}

class _ReportPreviewScreenState extends State<ReportPreviewScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _notesController = TextEditingController();
  
  // Checklist items
  bool _verifiedPatientId = false;
  bool _verifiedImageQuality = false;
  bool _clinicalCorrelation = false;
  bool _findingsReviewed = false;

  final List<Uint8List> _markedImages = [];
  Map<String, dynamic>? _usageStats;
  bool _isLoadingUsage = true;
  String? _quotaError;

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
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoadingUsage = false);
    }
  }

  Future<void> _checkStorageQuota() async {
    if (_usageStats == null) return;
    
    final int used = _usageStats!['storage_used_bytes'] ?? 0;
    final int limit = 1 * 1024 * 1024 * 1024; // 1 GB
    
    // Estimate upload size: Image + Safety Margin (~5MB per scan max)
    final int imageSize = await widget.imageFile.length();
    final int estimatedTotal = used + imageSize + (50 * 1024); // +50KB for PDF/Metadata
    
    if (estimatedTotal > limit) {
      setState(() {
        _quotaError = "Storage Full (${(used / (1024 * 1024)).toStringAsFixed(1)} MB / 1 GB). Delete old reports to proceed.";
      });
    }
  }

  bool get _canGenerate => 
      _verifiedPatientId && 
      _verifiedImageQuality && 
      _clinicalCorrelation && 
      _findingsReviewed &&
      _quotaError == null; // Added quota check

  Future<void> _generateAndDownloadReport() async {
    if (!_canGenerate) return;

    try {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => const Center(child: CircularProgressIndicator()),
      );

      // Prepare findings for the report
      Map<String, dynamic> findings = {
        'top_finding': widget.result.topFinding,
        'predictions': widget.result.predictions,
        'doctor_notes': _notesController.text,
        'checklist_verified': true,
      };

      // Convert XFile to base64
      final bytes = await widget.imageFile.readAsBytes();
      String imageBase64 = base64Encode(bytes);
      
      // Call endpoint
      final pdfBytes = await _apiService.downloadReport(
        patientId: widget.patientId,
        patientName: widget.patientName,
        dob: widget.dob,
        email: widget.email,
        findings: findings,
        originalImageBase64: imageBase64,
        heatmapImageBase64: widget.result.heatmapBase64,
        doctorMarkedImages: _markedImages.map((e) => base64Encode(e)).toList().cast<String>(),
        modelInfo: widget.result.modelInfo,
        shouldDownload: false,
      );

      Navigator.pop(context); // Pop loading

      if (pdfBytes != null) {
        if (!mounted) return;
        
        // Navigate to In-App PDF Viewer
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewScreen(
              pdfBytes: pdfBytes,
              patientId: widget.patientId,
              patientName: widget.patientName,
            ),
          ),
        );

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Report generated and opened.'),
            backgroundColor: Colors.green,
          ),
        );
      }

    } catch (e) {
      Navigator.pop(context); // Pop loading
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error generating report: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Doctor Verification')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Patient Information',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: ${widget.patientName}', style: const TextStyle(fontSize: 16)),
                    Text('Report ID: ${widget.patientId}', style: const TextStyle(fontSize: 16)),
                    Text('Patient Date of Birth: ${widget.dob}', style: const TextStyle(fontSize: 16)),
                    Text('Account Email: ${widget.email}', style: const TextStyle(fontSize: 16)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text(
              'Verify Findings & Generate Report',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text('Visual Verification', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () async {
                              final bytes = await widget.imageFile.readAsBytes();
                              if (!mounted) return;
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageViewer(
                                    imageBytes: bytes,
                                    title: 'Original High-Res X-Ray',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.image_outlined),
                            label: const Text('Open Original High-Resolution Image'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.draw_outlined, size: 20),
                          tooltip: 'Annotate Original X-Ray',
                          onPressed: () async {
                            final bytes = await widget.imageFile.readAsBytes();
                            if (!mounted) return;
                            final Uint8List? marked = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AnnotationScreen(
                                  imageBytes: bytes,
                                  title: 'Annotate Original X-Ray',
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
                    Row(
                      children: [
                        Expanded(
                          child: TextButton.icon(
                            onPressed: () {
                               Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (context) => FullScreenImageViewer(
                                    imageBytes: base64Decode(widget.result.heatmapBase64),
                                    title: 'AI Analysis - Heatmap (High-Res)',
                                  ),
                                ),
                              );
                            },
                            icon: const Icon(Icons.remove_red_eye_outlined),
                            label: const Text('Open Analyzed High-Resolution Image'),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.draw_outlined, size: 20),
                          tooltip: 'Annotate AI Heatmap',
                          onPressed: () async {
                            final bytes = base64Decode(widget.result.heatmapBase64);
                            if (!mounted) return;
                            final Uint8List? marked = await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => AnnotationScreen(
                                  imageBytes: bytes,
                                  title: 'Annotate AI Heatmap',
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
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => FullScreenAnalysisViewer(
                              result: widget.result,
                            ),
                          ),
                        );
                      },
                      label: const Text('Open AI Analysis Report / Summary'),
                    ),
                    const Divider(),
                    const Text('Clinical Annotations', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        ..._markedImages.asMap().entries.map((entry) {
                          final index = entry.key;
                          final img = entry.value;
                          return Stack(
                            children: [
                              InkWell(
                                onTap: () {
                                  // Show full-screen preview of marked image
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => Scaffold(
                                        appBar: AppBar(
                                          title: Text('Clinical Annotation ${index + 1}'),
                                          backgroundColor: Colors.black,
                                        ),
                                        backgroundColor: Colors.black,
                                        body: Center(
                                          child: InteractiveViewer(
                                            child: Image.memory(img),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(4),
                                  child: Image.memory(img, width: 60, height: 60, fit: BoxFit.cover),
                                ),
                              ),
                              Positioned(
                                right: -10,
                                top: -10,
                                child: IconButton(
                                  icon: const Icon(Icons.cancel, size: 20, color: Colors.red),
                                  onPressed: () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Annotation'),
                                        content: const Text('Are you sure you want to delete this clinical annotation?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () => Navigator.of(context).pop(true),
                                            child: const Text('Delete', style: TextStyle(color: Colors.red)),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (confirm == true) {
                                      setState(() {
                                        _markedImages.remove(img);
                                      });
                                    }
                                  },
                                ),
                              ),
                            ],
                          );
                        }),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            
            const Text('Verification Checklist', style: TextStyle(fontWeight: FontWeight.bold)),
            CheckboxListTile(
              title: const Text('Report Identity Verified'),
              value: _verifiedPatientId,
              onChanged: (val) => setState(() => _verifiedPatientId = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Image Quality Acceptable'),
              value: _verifiedImageQuality,
              onChanged: (val) => setState(() => _verifiedImageQuality = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Findings Reviewed against Scan'),
              value: _findingsReviewed,
              onChanged: (val) => setState(() => _findingsReviewed = val ?? false),
            ),
            CheckboxListTile(
              title: const Text('Clinical Correlation Confirmed'),
              value: _clinicalCorrelation,
              onChanged: (val) => setState(() => _clinicalCorrelation = val ?? false),
            ),
            
            const SizedBox(height: 16),
            TextField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Clinical Notes / Recommendations',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
            ),
            
            const SizedBox(height: 24),
            if (_quotaError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  _quotaError!,
                  style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
              ),

            ElevatedButton(
              onPressed: _canGenerate ? _generateAndDownloadReport : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.teal,
                foregroundColor: Colors.white,
              ),
              child: const Text('GENERATE & DOWNLOAD REPORT'),
            ),
          ],
        ),
      ),
    );
  }
}
