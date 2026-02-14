import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../../core/services/api_service.dart';
import '../../../../shared/models/analysis_result.dart';
import '../../../reports/presentation/screens/report_preview_screen.dart';

class AnalysisScreen extends StatefulWidget {
  final String userEmail;
  const AnalysisScreen({super.key, required this.userEmail});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> {
  final ApiService _apiService = ApiService();
  final ImagePicker _picker = ImagePicker();
  
  // Patient Form
  final TextEditingController _nameController = TextEditingController();
  
  DateTime? _dob;
  String? _generatedPatientId;
  
  XFile? _selectedImage;
  Uint8List? _imageBytes;
  bool _isAnalyzing = false;
  AnalysisResult? _result;
  String? _errorMessage;
  Map<String, dynamic>? _usageStats;
  bool _isLoadingUsage = true;

  @override
  void initState() {
    super.initState();
    _generatePatientId();
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
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _isLoadingUsage = false);
    }
  }

  void _generatePatientId() {
    final now = DateTime.now();
    final timestamp = "${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}";
    final random = (1000 + DateTime.now().millisecond % 9000).toString();
    setState(() {
      _generatedPatientId = "PCSS-$timestamp-$random";
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
      setState(() {
        _dob = picked;
      });
    }
  }

  bool get _isFormValid => 
      _nameController.text.isNotEmpty && 
      widget.userEmail.isNotEmpty && 
      _dob != null;

  Future<void> _pickImage(ImageSource source) async {
    if (!_isFormValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please complete patient details first.')),
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

  Future<void> _analyzeImage() async {
    if (_selectedImage == null) return;
    
    // UI Enforcement: Check runs limit
    if (_usageStats != null && (_usageStats!['runs_used_count'] ?? 0) >= 100) {
      setState(() => _errorMessage = "Run limit reached (100/100). Please contact support to upgrade.");
      return;
    }

    setState(() {
      _isAnalyzing = true;
      _errorMessage = null;
    });

    try {
      final result = await _apiService.analyzeImage(_selectedImage!);
      setState(() {
        _result = result;
      });
      // Re-fetch usage stats after success to reflect the new run
      _fetchUsageStats();
    } catch (e) {
      String msg = e.toString();
      if (msg.contains("OOD_DETECTED")) {
        msg = "Upload Rejected: The image does not appear to be a valid Chest X-Ray.";
      }
      setState(() => _errorMessage = msg);
    } finally {
      setState(() => _isAnalyzing = false);
    }
  }

  void _navigateToReport() {
    if (_selectedImage != null && _result != null && _isFormValid) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ReportPreviewScreen(
            imageFile: _selectedImage!,
            result: _result!,
            patientId: _generatedPatientId!,
            patientName: _nameController.text,
            dob: _dob!.toIso8601String().split('T')[0],
            email: widget.userEmail,
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      appBar: AppBar(title: const Text('X-Ray Analysis')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Patient Intake Form
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Patient Intake', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _nameController,
                        decoration: const InputDecoration(labelText: 'Patient Name', border: OutlineInputBorder()),
                        onChanged: (_) => setState((){}),
                      ),
                      const SizedBox(height: 12),
                      InkWell(
                        onTap: () => _selectDate(context),
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            labelText: 'Patient Date of Birth', 
                            border: OutlineInputBorder(),
                          ),
                          child: Text(_dob == null ? 'Select Date' : _dob!.toIso8601String().split('T')[0]),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: TextEditingController(text: _generatedPatientId),
                        readOnly: true,
                        decoration: const InputDecoration(labelText: 'Auto-Generated Report ID', border: OutlineInputBorder(), filled: true),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              
              // Action Buttons (Moved Above Image)
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.camera),
                    icon: const Icon(Icons.camera_alt),
                    label: const Text('Take X-ray photo'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _isAnalyzing ? null : () => _pickImage(ImageSource.gallery),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Upload X-ray image from Gallery'),
                    style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 16)),
                  ),
                ],
              ),
              
              const SizedBox(height: 20),

              // Image Selection Area
              Opacity(
                opacity: _isFormValid ? 1.0 : 0.5,
                child: AbsorbPointer(
                  absorbing: !_isFormValid,
                  child: GestureDetector(
                    onTap: () => _pickImage(ImageSource.gallery),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        double uploadBoxHeight = constraints.maxWidth < 400 ? 180 : 250;
                        return Container(
                          height: uploadBoxHeight,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: theme.primaryColor.withOpacity(0.5),
                              width: 2,
                            ),
                          ),
                          child: _selectedImage == null
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.cloud_upload_outlined, size: 48, color: theme.primaryColor),
                                      const Text('Tap to Upload X-Ray', style: TextStyle(fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                )
                              : ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      _imageBytes != null 
                                        ? Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              Image.memory(_imageBytes!, fit: BoxFit.contain),
                                              if (_result != null && _result!.heatmapBase64.isNotEmpty)
                                                Image.memory(
                                                  base64Decode(_result!.heatmapBase64),
                                                  fit: BoxFit.contain,
                                                ),
                                            ],
                                          )
                                        : const Center(child: CircularProgressIndicator()),
                                    ],
                                  ),
                                ),
                        );
                      }
                    ),
                  ),
                ),
              ),

                      const SizedBox(height: 20),

                      if (_selectedImage != null && _result == null)
                        ElevatedButton(
                          onPressed: _isAnalyzing ? null : _analyzeImage,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            backgroundColor: Colors.teal,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isAnalyzing
                              ? const SizedBox(
                                  height: 20, width: 20, 
                                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                                )
                              : const Text('ANALYZE X-RAY'),
                        ),

                      if (_errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 20),
                          child: Text(
                            _errorMessage!,
                            style: const TextStyle(color: Colors.red),
                            textAlign: TextAlign.center,
                          ),
                        ),

                      // Results Section
                      if (_result != null) ...[
                        const SizedBox(height: 24),
                        const Divider(),
                        const Text(
                          'Analysis Results',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 10),
                        Card(
                          elevation: 4,
                          color: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: _result!.topFinding == 'No Findings' ? Colors.green.shade200 : Colors.orange.shade200,
                              width: 2
                            )
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(20.0),
                            child: Column(
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      _result!.topFinding == 'No Findings' ? Icons.check_circle : Icons.warning_amber_rounded,
                                      color: _result!.topFinding == 'No Findings' ? Colors.green : Colors.orange,
                                      size: 32,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          const Text('Primary Analysis', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                          Text(
                                            _result!.topFinding,
                                            style: TextStyle(
                                              fontSize: 20, 
                                              fontWeight: FontWeight.bold,
                                              color: _result!.topFinding == 'No Findings' ? Colors.green[700] : Colors.deepOrange[800]
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                const Divider(height: 30),
                                // Model & Confidence Badges
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blue.shade50,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blue.shade200),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.psychology, size: 16, color: Colors.blue),
                                          const SizedBox(width: 4),
                                          Text(_result!.modelInfo, style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                                        ],
                                      ),
                                    ),
                                    if (_result!.isHighConfidence) ...[
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.green.shade50,
                                          borderRadius: BorderRadius.circular(4),
                                          border: Border.all(color: Colors.green.shade200),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.verified, size: 16, color: Colors.green),
                                            SizedBox(width: 4),
                                            Text("High Confidence", style: TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text('Detailed Confidence Scores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                ),
                                const SizedBox(height: 16),
                                // Display probabilities with Progress Bars
                                ..._result!.predictions.entries
                                    .where((e) => e.value > 0.05) // Show only significant findings
                                    .map((e) {
                                      final isHighRisk = e.value > 0.7;
                                      final isMediumRisk = e.value > 0.3;
                                      final color = isHighRisk ? Colors.red : (isMediumRisk ? Colors.orange : Colors.green);
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Text(e.key, style: const TextStyle(fontWeight: FontWeight.w500)),
                                                Text('${(e.value * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: color)),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            ClipRRect(
                                              borderRadius: BorderRadius.circular(4),
                                              child: LinearProgressIndicator(
                                                value: e.value,
                                                minHeight: 8,
                                                backgroundColor: Colors.grey[100],
                                                valueColor: AlwaysStoppedAnimation<Color>(color),
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    })
                                    .toList(),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton.icon(
                          onPressed: _navigateToReport,
                          icon: const Icon(Icons.assignment_turned_in),
                          label: const Text('VERIFY & REPORT'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.indigo, 
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 50),
                          ),
                        ),
                      ]
                    ],
          ),
        ),
      ),
    );
  }
}
