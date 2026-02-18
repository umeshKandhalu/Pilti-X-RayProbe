import 'dart:typed_data';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart'; // For XFile
import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart'; // Add this import for MediaType
import 'package:shared_preferences/shared_preferences.dart';
import '../../shared/models/analysis_result.dart';
import 'file_downloader.dart'; // Correct import placement
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for utf8

class ApiService {
  static const String _keyUserEmail = 'user_email';
  static const String _keyUserRole = 'user_role';
  static const String _keyLoginTimestamp = 'login_timestamp';
  static const String _keyBaseUrl = 'api_base_url';
  static const String _keyJwtToken = 'jwt_token'; // Store JWT in SharedPreferences instead
  
  static String _baseUrl = _getDefaultBaseUrl();

  static String _getDefaultBaseUrl() {
    if (kIsWeb) {
      // PRO TIP: In production (Docker), we use a relative path /api.
      // This is routed via Nginx proxy to the BACKEND_URL in docker-compose.
      print("[API] Running in Web mode. Defaulting to relative proxy path: /api");
      return '/api';
    }
    // Default for local mobile/emulator
    return 'http://localhost:8888';
  }

  final Dio _dio = Dio(BaseOptions(
    baseUrl: _baseUrl,
    connectTimeout: const Duration(seconds: 300),
    receiveTimeout: const Duration(seconds: 300),
    sendTimeout: const Duration(seconds: 300),
    validateStatus: (status) => true,
  ));

  // TODO: Move this to a secure config or env variable in production
  static const String _hmacSecret = "your-secret-key-change-in-production"; 

  ApiService() {
    _initBaseUrl();
    _setupInterceptors();
  }

  // Singleton SharedPreferences for safety and performance
  static Future<SharedPreferences> get _prefs async {
    return await SharedPreferences.getInstance();
  }

  void _setupInterceptors() {
    print("[API] Setting up Axios/Dio Interceptors...");
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        print("[API] Request: ${options.method} ${options.path}");
        try {
          // 1. Add JWT Token
          final prefs = await _prefs;
          final token = prefs.getString(_keyJwtToken);
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
            print("[API] Added Bearer Token");
          }

          // 2. Add HMAC Signature
          final timestamp = DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;
          options.headers['X-Timestamp'] = timestamp.toString();

          List<int> bodyBytes = [];
          if (options.data != null) {
             if (options.data is FormData || options.path == '/generate_report') {
               // Skip signing FormData body and large report JSON to avoid UI freeze/mismatches
               bodyBytes = [];
             } else if (options.data is Map || options.data is List) {
               bodyBytes = utf8.encode(jsonEncode(options.data));
             } else if (options.data is String) {
               bodyBytes = utf8.encode(options.data);
             }
          }
          
          // Signature = HMAC-SHA256(Secret, Timestamp + Body)
          final hmac = Hmac(sha256, utf8.encode(_hmacSecret));
          final message = utf8.encode('$timestamp') + bodyBytes;
          final digest = hmac.convert(message);
          
          // Convert to hex string (backend expects hexdigest format)
          options.headers['X-Signature'] = digest.toString().replaceAll(RegExp(r'[^0-9a-f]'), '');
          print("[API] Added HMAC Signature");

          return handler.next(options);
        } catch (e) {
          print("[API] Error in Interceptor: $e");
          // Don't block the request, let it fail naturally if headers are missing
          // or rethrow to stop it. Rethrowing is safer to see the error.
          return handler.reject(DioException(requestOptions: options, error: "Interceptor Error: $e"));
        }
      },
      onResponse: (response, handler) {
        print("[API] Response: ${response.statusCode} ${response.statusMessage}");
        return handler.next(response);
      },
      onError: (DioException e, handler) async {
        print("[API] Error: ${e.message}");
        if (e.response != null) {
          print("[API] Response Data: ${e.response?.data}");
        }
        
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          print("[API] Session Expired/Unauthorized");
          await clearSession();
        }
        return handler.next(e);
      }
    ));
  }

  Future<void> _initBaseUrl() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUrl = prefs.getString(_keyBaseUrl);
    
    if (savedUrl != null && savedUrl.isNotEmpty) {
       // If running on web, and the saved URL looks like an old local dev URL, 
       // we should prioritize the relative /api path for Zero-Config support.
       if (kIsWeb && (savedUrl.contains("localhost:8888") || savedUrl.contains("127.0.0.1"))) {
         print("[API] Stale local URL detected in Web mode. Reverting to /api");
         _baseUrl = '/api';
       } else {
         _baseUrl = savedUrl;
       }
    } else {
      _baseUrl = _getDefaultBaseUrl();
    }
    
    _dio.options.baseUrl = _baseUrl;
    print("[API] Initialized with Base URL: $_baseUrl");
  }

  Future<void> updateBaseUrl(String newUrl) async {
    final prefs = await SharedPreferences.getInstance();
    if (newUrl.isEmpty) {
      await prefs.remove(_keyBaseUrl);
      _baseUrl = _getDefaultBaseUrl();
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
    String? heatmapImageBase64,
    String? waveformImageBase64,
    List<String>? doctorMarkedImages,
    String? modelInfo,
    bool isEcg = false,
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
          'waveform_image': waveformImageBase64,
          'doctor_marked_images': doctorMarkedImages ?? [],
          'model_info': modelInfo,
          'is_ecg': isEcg,
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

  Future<Map<String, dynamic>> analyzeEcg(String base64Image) async {
    try {
      final response = await _dio.post('/ecg/analyze', data: {
        'image': base64Image,
      });
      return response.data;
    } catch (e) {
      print('Error analyzing ECG: $e');
      rethrow;
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

  Future<Map<String, dynamic>> getUsageStats() async {
    try {
      final response = await _dio.get('/usage_stats');
      if (response.statusCode == 200) {
        return response.data;
      } else {
        throw Exception('Failed to load usage stats');
      }
    } catch (e) {
      print('Error fetching usage stats: $e');
      rethrow;
    }
  }

  Future<List<Map<String, dynamic>>> adminListUsers() async {
    try {
      final response = await _dio.get('/admin/users');
      if (response.statusCode == 200) {
        return List<Map<String, dynamic>>.from(response.data['users']);
      }
      return [];
    } catch (e) {
      print('Error listing users: $e');
      rethrow;
    }
  }

  Future<void> adminUpdateLimits(String email, {int? maxStorage, int? maxRuns}) async {
    try {
      await _dio.patch('/admin/users/$email/limits', data: {
        if (maxStorage != null) 'max_storage_bytes': maxStorage,
        if (maxRuns != null) 'max_runs_count': maxRuns,
      });
    } catch (e) {
      print('Error updating limits: $e');
      rethrow;
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
        await prefs.setString(_keyUserRole, response.data['role'] ?? 'user');
        await prefs.setInt(_keyLoginTimestamp, DateTime.now().millisecondsSinceEpoch);
        
        // Save JWT in SharedPreferences (web-compatible)
        final token = response.data['access_token'];
        if (token != null) {
          await prefs.setString(_keyJwtToken, token);
        }
        
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
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyLoginTimestamp);
    await prefs.remove(_keyJwtToken);
  }

  Future<String> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyUserRole) ?? 'user';
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
