import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/services/api_service.dart';
import '../../../analysis/presentation/screens/analysis_screen.dart';
import 'pdf_view_screen.dart';

class UserReportsScreen extends StatefulWidget {
  final String userEmail;
  const UserReportsScreen({super.key, required this.userEmail});

  @override
  State<UserReportsScreen> createState() => _UserReportsScreenState();
}

class _UserReportsScreenState extends State<UserReportsScreen> {
  final ApiService _apiService = ApiService();
  final TextEditingController _searchController = TextEditingController();
  
  List<Map<String, dynamic>> _reports = [];
  String _searchQuery = "";
  bool _isLoading = false;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _fetchReports();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchReports() async {
    final email = widget.userEmail;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
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

  String _formatBytes(int bytes) {
    if (bytes <= 0) return "0 B";
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
  }

  @override
  Widget build(BuildContext context) {
    final filteredReports = _reports.where((report) {
      final q = _searchQuery.toLowerCase();
      final name = (report['patient_name'] ?? "").toString().toLowerCase();
      final id = (report['patient_id'] ?? "").toString().toLowerCase();
      final date = (report['date'] ?? "").toString().toLowerCase();
      return name.contains(q) || id.contains(q) || date.contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Reports'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchReports),
        ],
      ),
      body: Container(
        color: Colors.grey[50],
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by name, ID, or date...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty 
                    ? IconButton(
                        icon: const Icon(Icons.clear), 
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = "");
                        },
                      ) 
                    : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  fillColor: Colors.white,
                  filled: true,
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
            ),
            if (!_isLoading && _reports.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4.0),
                child: Row(
                  children: [
                    Text(
                      'Showing ${filteredReports.length} of ${_reports.length} records',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                    ),
                  ],
                ),
              ),
            const Divider(),
            Expanded(
              child: _isLoading && _reports.isEmpty
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null && _reports.isEmpty
                  ? Center(child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)))
                  : filteredReports.isEmpty
                    ? const Center(child: Text('No matching reports found.'))
                    : ListView.separated(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: filteredReports.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          final report = filteredReports[index];
                          final patientId = report['patient_id'];
                          final patientName = report['patient_name'] ?? 'Unknown';
                          final date = report['date'].toString().split('T')[0];
                          final size = report['size_bytes'] ?? 0;
                          final email = widget.userEmail;
                          
                          return Card(
                            elevation: 0.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: Colors.grey.withOpacity(0.2)),
                            ),
                            child: ListTile(
                              leading: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.indigo.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(Icons.picture_as_pdf, color: Colors.indigo),
                              ),
                              title: Text(patientName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Report ID: $patientId', style: const TextStyle(fontSize: 12)),
                                    Row(
                                      children: [
                                        Text('Date: $date', style: const TextStyle(fontSize: 12)),
                                        const Spacer(),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            _formatBytes(size),
                                            style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.blueGrey),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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
