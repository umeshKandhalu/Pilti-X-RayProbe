import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:share_plus/share_plus.dart';
import '../services/file_downloader.dart';

class PdfViewScreen extends StatelessWidget {
  final Uint8List pdfBytes;
  final String patientId;
  final String patientName;

  const PdfViewScreen({
    super.key,
    required this.pdfBytes,
    required this.patientId,
    required this.patientName,
  });

  void _showTechnicalError(BuildContext context, String action, dynamic error) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$action Failed'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('The browser blocked this action. This often happens on non-secure (http) connections.'),
            const SizedBox(height: 10),
            Text('Technical details:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.grey[700])),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.grey[100],
              child: Text(error.toString(), style: const TextStyle(fontFamily: 'monospace', fontSize: 10)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          if (action == 'Share')
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                viewFile(pdfBytes, 'report_$patientId.pdf');
              },
              child: const Text('Open in New Tab Instead'),
            ),
        ],
      ),
    );
  }

  Future<void> _shareReport(BuildContext context) async {
    print("DEBUG: _shareReport started for $patientId");
    try {
      final String fileName = 'report_$patientId.pdf';
      final file = XFile.fromData(
        pdfBytes,
        name: fileName,
        mimeType: 'application/pdf',
      );
      
      // Attempt native sharing
      await Share.shareXFiles(
        [file],
        text: 'Chest X-Ray Analysis Report for $patientName',
        subject: 'Medical Report: $patientId',
      );
      print("DEBUG: Native share call completed");
    } catch (e) {
      print("ERROR: Native share failed: $e");
      _showTechnicalError(context, 'Share', e);
    }
  }

  void _downloadReport(BuildContext context) {
    print("DEBUG: _downloadReport triggered");
    try {
      downloadFile(pdfBytes, 'report_$patientId.pdf');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Download request sent to browser...')),
      );
    } catch (e) {
      print("ERROR: Download action failed: $e");
      _showTechnicalError(context, 'Download', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Report: $patientName'),
        actions: [
          IconButton(
            icon: const Icon(Icons.file_download),
            tooltip: 'Download PDF',
            onPressed: () => _downloadReport(context),
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Share Report',
            onPressed: () => _shareReport(context),
          ),
        ],
      ),
      body: SfPdfViewer.memory(
        pdfBytes,
        onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to load PDF: ${details.error}')),
          );
        },
      ),
    );
  }
}
