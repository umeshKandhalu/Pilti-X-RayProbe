import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb; // Add import
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart'; // Add import
import '../../../../core/services/api_service.dart';
import '../../../../shared/models/analysis_result.dart';
import 'pdf_view_screen.dart';

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

  bool get _canGenerate => 
      _verifiedPatientId && 
      _verifiedImageQuality && 
      _clinicalCorrelation && 
      _findingsReviewed; // Report ID is now pre-verified

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
            ElevatedButton.icon(
              onPressed: _canGenerate ? _generateAndDownloadReport : null,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('CONFIRM & VIEW REPORT'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.indigo,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
