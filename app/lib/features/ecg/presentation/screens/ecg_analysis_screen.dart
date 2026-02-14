import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/models/ecg_analysis_result.dart';
import '../../../reports/presentation/screens/ecg_report_preview_screen.dart';

class ECGAnalysisScreen extends StatefulWidget {
  final String userEmail;
  const ECGAnalysisScreen({super.key, required this.userEmail});

  @override
  State<ECGAnalysisScreen> createState() => _ECGAnalysisScreenState();
}

class _ECGAnalysisScreenState extends State<ECGAnalysisScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  // Patient Form
  final TextEditingController _nameController = TextEditingController();
  DateTime? _dob;
  String? _generatedReportId;
  
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  EcgAnalysisResult? _result;
  String? _errorMessage;
  Map<String, dynamic>? _usageStats;
  bool _isLoadingUsage = true;

  @override
  void initState() {
    super.initState();
    _generateReportId();
    _fetchUsageStats();
  }

  Future<void> _fetchUsageStats() async {
    try {
      final stats = await _apiService.getUsageStats();
      if (mounted) {
        setState(() {
          _usageStats = stats;
          _isLoadingUsage = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingUsage = false);
    }
  }

  void _generateReportId() {
    final now = DateTime.now();
    final timestamp = "${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}";
    final random = (1000 + DateTime.now().millisecond % 9000).toString();
    setState(() {
      _generatedReportId = "ECG-$timestamp-$random";
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dob) {
      setState(() => _dob = picked);
    }
  }

  bool get _isFormValid => _nameController.text.isNotEmpty && _dob != null;

  Future<void> _pickImage(ImageSource source) async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter patient details first.')),
      );
      return;
    }
    try {
      final XFile? image = await _picker.pickImage(source: source);
      if (image != null) {
        final bytes = await image.readAsBytes();
        setState(() {
          _selectedImage = image;
          _imageBytes = bytes;
          _result = null;
          _errorMessage = null;
        });
      }
    } catch (e) {
      setState(() => _errorMessage = 'Error picking image: $e');
    }
  }

  Future<void> _analyzeEcg() async {
    if (_selectedImage == null) return;

    // Quota check
    if (_usageStats != null && (_usageStats!['runs_used_count'] ?? 0) >= (_usageStats!['max_runs_count'] ?? 100)) {
      setState(() => _errorMessage = "Usage limit reached. Please contact support.");
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final base64Image = base64Encode(_imageBytes!);
      final data = await _apiService.analyzeEcg(base64Image);
      setState(() {
        _result = EcgAnalysisResult.fromJson(data);
      });
      _fetchUsageStats();
    } catch (e) {
      setState(() => _errorMessage = "Analysis Failed: ${e.toString()}");
    } finally {
      if (mounted) setState(() => _isAnalyzing = false);
    }
  }

  void _navigateToReport() {
    if (_result == null || _dob == null || _selectedImage == null) return;
    
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => EcgReportPreviewScreen(
          imageFile: _selectedImage!,
          result: _result!,
          patientId: _generatedReportId!,
          patientName: _nameController.text,
          dob: _dob!.toIso8601String().split('T')[0],
          email: widget.userEmail,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('ECG Analysis')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPatientForm(),
              const SizedBox(height: 20),
              _buildActionButtons(),
              const SizedBox(height: 20),
              _buildImagePreview(theme),
              const SizedBox(height: 24),
              if (_selectedImage != null && _result == null) _buildAnalyzeButton(),
              if (_errorMessage != null) _buildErrorMessage(),
              if (_result != null) _buildResultsCard(theme),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPatientForm() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Patient Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Patient Name', border: OutlineInputBorder()),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),
            InkWell(
              onTap: () => _selectDate(context),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: 'Patient DOB', border: OutlineInputBorder()),
                child: Text(_dob == null ? 'Select Date' : _dob!.toIso8601String().split('T')[0]),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: TextEditingController(text: _generatedReportId),
              readOnly: true,
              decoration: const InputDecoration(labelText: 'ECG Report ID', border: OutlineInputBorder(), filled: true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                icon: const Icon(Icons.camera_alt),
                label: const Text('Scan Paper ECG'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                icon: const Icon(Icons.photo_library),
                label: const Text('From Gallery'),
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildImagePreview(ThemeData theme) {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.primaryColor.withOpacity(0.3), width: 1),
      ),
      child: _selectedImage == null
        ? const Center(child: Text('Please upload a photo of the ECG paper grid'))
        : ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Image.memory(_imageBytes!, fit: BoxFit.contain),
          ),
    );
  }

  Widget _buildAnalyzeButton() {
    return ElevatedButton(
      onPressed: _isAnalyzing ? null : _analyzeEcg,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      child: _isAnalyzing 
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
        : const Text('START HYBRID ANALYSIS'),
    );
  }

  Widget _buildErrorMessage() {
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Text(_errorMessage!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
    );
  }

  Widget _buildResultsCard(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text('ECG Report Card', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        
        // Waveform View
        if (_result!.waveformBase64.isNotEmpty) ...[
          const Text('Digital Signal Reconstruction', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Container(
            height: 150,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.memory(base64Decode(_result!.waveformBase64), fit: BoxFit.fill),
            ),
          ),
          const SizedBox(height: 20),
        ],

        // Findings
        Card(
          color: Colors.indigo[50],
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.indigo.shade200)),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                const Row(
                  children: [
                    Icon(Icons.psychology, color: Colors.indigo),
                    SizedBox(width: 8),
                    Text('AI Interpretation', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                ),
                const Divider(),
                ..._result!.findings.map((f) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.check_circle_outline, color: Colors.green, size: 18),
                      const SizedBox(width: 8),
                      Text(f, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    ],
                  ),
                )).toList(),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Clinical Metrics
        const Text('Clinical Metrics', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        const SizedBox(height: 8),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _result!.metrics.length,
          itemBuilder: (context, index) {
            String key = _result!.metrics.keys.elementAt(index);
            dynamic value = _result!.metrics[key];
            return Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.grey[200]!)),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(key, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  Text(value.toString(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo)),
                ],
              ),
            );
          },
        ),

        const SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: _isAnalyzing ? null : _navigateToReport,
          icon: const Icon(Icons.assignment_turned_in),
          label: const Text('VERIFY & REPORT'),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
        ),
      ],
    );
  }
}
