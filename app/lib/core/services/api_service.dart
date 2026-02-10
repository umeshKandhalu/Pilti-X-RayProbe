import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart'; // For XFile
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // Add this import for MediaType
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/analysis_result.dart';
import 'file_downloader.dart'; // Correct import placement

class ApiService {
  static const String _keyUserEmail = 'user_email';
  static const String _keyLoginTimestamp = 'login_timestamp';
  static const String _keyBaseUrl = 'api_base_url';
  
  // Default URL (Localhost for emulator/device)
  static String _baseUrl = kIsWeb 
      ? '${Uri.base.scheme}://${Uri.base.host}:8888' 
      : (Platform.isMacOS || Platform.isWindows || Platform.isLinux)
          ? 'http://localhost:8888'
          : 'http://192.168.0.91:8888';

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 15),
  ));

  ApiService() {
    _initBaseUrl();
  }

  Future<void> _initBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    if (savedUrl != null && savedUrl.isNotEmpty) {
      _baseUrl = savedUrl;
      _dio.options.baseUrl = savedUrl;
    }
  }

  Future<void> updateBaseUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (newUrl.isEmpty) {
      await prefs.remove(_keyBaseUrl);
      // Reset to default if cleared? Or keep empty? 
      // Better to keep previous or reset to default hardcoded one.
      _baseUrl = kIsWeb 
        ? '${Uri.base.scheme}://${Uri.base.host}:8888' 
        : 'http://192.168.0.91:8888';
    } else {
      await prefs.setString(_keyBaseUrl, newUrl);
      _baseUrl = newUrl;
    }
    _dio.options.baseUrl = _baseUrl;
  }
  
  String get currentBaseUrl => _baseUrl;

  Future<AnalysisResult> analyzeImage(XFile imageFile) async {
    try {
      String fileName = imageFile.name;
      
      // Handle Web (Bytes) vs Mobile (Path)
      MultipartFile multipartFile;
      if (kIsWeb) {
        final bytes = await imageFile.readAsBytes();
        multipartFile = MultipartFile.fromBytes(
          bytes,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        );
      } else {
        multipartFile = await MultipartFile.fromFile(
          imageFile.path,
          filename: fileName,
          contentType: MediaType('image', 'jpeg'),
        );
      }

      FormData formData = FormData.fromMap({
        "file": multipartFile,
      });

      Response response = await _dio.post('/analyze', data: formData);
      
      if (response.statusCode == 200) {
        if (response.data is Map && response.data.containsKey('error')) {
          throw Exception(response.data['error'] + ": " + response.data['message']);
        }
        return AnalysisResult.fromJson(response.data);
      } else {
        throw Exception('Failed to analyze image: ${response.statusCode}');
      }
    } catch (e) {
      if (e.toString().contains("OOD_DETECTED")) rethrow;
      throw Exception('Error connecting to server: $e');
    }
  }



  Future<Uint8List?> downloadReport({
    required String patientId,
    required String patientName,
    required String dob,
    required String email,
    required Map<String, dynamic> findings,
    required String originalImageBase64,
    required String heatmapImageBase64,
    String modelInfo = "Standard Model",
    bool shouldDownload = true,
  }) async {
    try {
      final response = await _dio.post(
        '/generate_report',
        data: {
          'patient_id': patientId,
          'patient_name': patientName,
          'dob': dob,
          'email': email,
          'findings': findings,
          'original_image': originalImageBase64,
          'heatmap_image': heatmapImageBase64,
          'model_info': modelInfo,
        },
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.statusCode == 200) {
        final bytes = Uint8List.fromList(response.data);
        if (shouldDownload) {
          downloadFile(bytes, 'report_$patientId.pdf');
        }
        return bytes;
      }
      return null;
    } catch (e) {
      print('Error processing report: $e');
      throw e;
    }
  }

  Future<List<Map<String, dynamic>>> getUserReports(String email) async {
    try {
      final response = await _dio.get('/reports/$email');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data);
      }
      return [];
    } catch (e) {
      print('Error fetching user reports: $e');
      return [];
    }
  }

  String getReportPdfUrl(String email, String patientId) {
    return '${_dio.options.baseUrl}/reports/$email/$patientId/pdf';
  }

  Future<Uint8List> fetchReportPdf(String email, String patientId) async {
    try {
      final response = await _dio.get(
        '/reports/$email/$patientId/pdf',
        options: Options(responseType: ResponseType.bytes),
      );
      if (response.statusCode == 200) {
        print('PDF Fetched: ${response.data.runtimeType}, Length: ${(response.data as List).length}');
        return Uint8List.fromList(response.data);
      }
      throw Exception('Failed to load PDF: Status ${response.statusCode}');
    } catch (e) {
      throw Exception('Error fetching PDF: $e');
    }
  }

  Future<bool> login(String email, String password, {String? dob}) async {
    try {
      final response = await _dio.post('/login', data: {
        'email': email,
        'password': password,
        if (dob != null) 'dob': dob,
      });
      
      if (response.statusCode == 200) {
        // Save session locally for 24h persistence
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_keyUserEmail, email);
        await prefs.setInt(_keyLoginTimestamp, DateTime.now().millisecondsSinceEpoch);
        return true;
      }
      return false;
    } catch (e) {
      if (e is DioException && e.response != null) {
         throw Exception(e.response?.data['detail'] ?? 'Login failed');
      }
      throw Exception('Login error: $e');
    }
  }

  Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserEmail);
    await prefs.remove(_keyLoginTimestamp);
  }

  Future<String?> getSavedSession() async {
    final prefs = await SharedPreferences.getInstance();
    final email = prefs.getString(_keyUserEmail);
    final timestamp = prefs.getInt(_keyLoginTimestamp);

    if (email != null && timestamp != null) {
      final loginTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final now = DateTime.now();
      
      // Persist for 24 hours
      if (now.difference(loginTime).inHours < 24) {
        return email;
      } else {
        // Session expired
        await clearSession();
      }
    }
    return null;
  }

  Future<bool> register(String email, String password, String dob) async {
     try {
      final response = await _dio.post('/register', data: {
        'email': email,
        'password': password,
        'dob': dob,
      });
      return response.statusCode == 200;
    } catch (e) {
      if (e is DioException && e.response != null) {
         throw Exception(e.response?.data['detail'] ?? 'Registration failed');
      }
      throw Exception('Registration error: $e');
    }
  }
}
