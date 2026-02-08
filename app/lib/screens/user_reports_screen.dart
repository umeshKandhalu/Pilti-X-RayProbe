import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../services/api_service.dart';
import 'pdf_view_screen.dart';

class UserReportsScreen extends StatefulWidget {
  final String userEmail;
  const UserReportsScreen({super.key, required this.userEmail});

  @override
  State<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends State<UserReportsScreen> {
  final ApiService _apiService = ApiService();
  // Removed _emailController
  
  List<Map<String, dynamic>> _reports = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  // Desktop: selected bytes to show in right pane
  Uint8List? _selectedPdfBytes;
  String? _selectedPatientId;

  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  Future<void> _fetchReports() async {
    final email = widget.userEmail;
    // Email check removed as it comes from auth
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _selectedPdfBytes = null;
      _selectedPatientId = null;
    });

    try {
      final reports = await _apiService.getUserReports(email);
      if (mounted) {
        setState(() {
          _reports = reports;
          if (reports.isEmpty) {
            _errorMessage = "No reports found for this account.";
          }
        });
      }
    } catch (e) {
      if (mounted) setState(() => _errorMessage = "Error fetching reports: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _viewReport(String email, String patientId, String patientName) async {
    setState(() => _isLoading = true);
    try {
      final pdfBytes = await _apiService.fetchReportPdf(email, patientId);
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => PdfViewScreen(
              pdfBytes: pdfBytes,
              patientId: patientId,
              patientName: patientName,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // _viewReport Removed as we are using direct launch now

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('My Reports')),
      body: Container(
        color: Colors.grey[50],
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
             // Search Card Removed - Auto fetching for logged in user
            if (_isLoading && _reports.isEmpty)
              const CircularProgressIndicator()
            else if (_errorMessage != null)
              Text(_errorMessage!, style: const TextStyle(color: Colors.red))
            else
              Expanded(
                child: ListView.builder(
                  itemCount: _reports.length,
                  itemBuilder: (context, index) {
                    final report = _reports[index];
                    final patientId = report['patient_id'];
                    final patientName = report['patient_name'] ?? 'Unknown';
                    final date = report['date'].toString().split('T')[0];
                    final email = widget.userEmail;
                    
                    return Card(
                      elevation: 1,
                      margin: const EdgeInsets.symmetric(vertical: 8),
                      child: ListTile(
                        leading: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
                        title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Report ID: $patientId', style: const TextStyle(fontSize: 12)),
                            Text('Date: $date', style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: IconButton(
                          icon: const Icon(Icons.visibility, color: Colors.teal),
                          tooltip: 'View Report',
                          onPressed: () => _viewReport(email, patientId, patientName),
                        ),
                        onTap: () => _viewReport(email, patientId, patientName),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// MobilePdfViewerScreen removed and replaced by PdfViewScreen
