import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/api_service.dart';
import '../../../analysis/presentation/screens/analysis_screen.dart';
import '../../../reports/presentation/screens/user_reports_screen.dart';
import '../../../auth/presentation/screens/login_screen.dart';
import '../widgets/usage_stats_card.dart';
import '../../../admin/presentation/screens/admin_screen.dart';
import '../../../ecg/presentation/screens/ecg_analysis_screen.dart';

class HomeScreen extends StatefulWidget {
  final String userEmail;
  
  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _acceptedDisclaimer = false;
  Map<String, dynamic>? _usageStats;
  bool _loadingStats = true;
  String _userRole = 'user';

  @override
  void initState() {
    super.initState();
    _fetchUsageStats();
    _loadRole();
  }

  Future<void> _loadRole() async {
    final role = await ApiService().getUserRole();
    if (mounted) setState(() => _userRole = role);
  }

  Future<void> _fetchUsageStats() async {
    try {
      final stats = await ApiService().getUsageStats();
      if (mounted) {
        setState(() {
          _usageStats = stats;
          _loadingStats = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading stats: $e");
      if (mounted) {
        setState(() {
          _loadingStats = false;
        });
      }
    }
  }

  void _navigateToAnalysis() {
    if (_acceptedDisclaimer) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AnalysisScreen(userEmail: widget.userEmail)),
      ).then((_) => _fetchUsageStats()); // Refresh stats after coming back
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the disclaimer to proceed.')),
      );
    }
  }

  void _navigateToEcg() {
    if (_acceptedDisclaimer) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => ECGAnalysisScreen(userEmail: widget.userEmail)),
      ).then((_) => _fetchUsageStats());
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please accept the disclaimer to proceed.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/logo.png', height: 32),
            const SizedBox(width: 12),
            const Text('PCSS'),
          ],
        ),
        actions: [
          if (_userRole == 'admin')
            IconButton(
              icon: const Icon(Icons.admin_panel_settings),
              tooltip: 'Admin Panel',
              onPressed: () {
                Navigator.push(
                  context, 
                  MaterialPageRoute(builder: (context) => const AdminScreen())
                ).then((_) => _fetchUsageStats()); // Refresh stats in case admin updated their own? 
              },
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: _fetchUsageStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () async {
              await ApiService().clearSession();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 16),
                Center(
                  child: Image.asset('assets/logo.png', height: 100),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to PCSS',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                 const Text(
                  'Pilti Clinical Support System',
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    border: Border.all(color: Colors.red),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'IMPORTANT DISCLAIMER',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'This system is for clinical decision support ONLY. It does NOT provide a medical diagnosis. All findings must be verified by a qualified medical professional.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      height: 24, 
                      width: 24,
                      child: Checkbox(
                        value: _acceptedDisclaimer,
                        onChanged: (val) => setState(() => _acceptedDisclaimer = val ?? false),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _acceptedDisclaimer = !_acceptedDisclaimer),
                        child: const Text(
                          'I acknowledge that this is a support tool, not a diagnostic device.',
                          style: TextStyle(height: 1.2),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: _acceptedDisclaimer ? _navigateToAnalysis : null,
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Start X-Ray Analysis', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  onPressed: _acceptedDisclaimer ? _navigateToEcg : null,
                  icon: const Icon(Icons.monitor_heart, color: Colors.white),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.indigo,
                    foregroundColor: Colors.white,
                  ),
                  label: const Text('Start ECG Paper Analysis', style: TextStyle(fontSize: 18)),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserReportsScreen(userEmail: widget.userEmail)),
                    ).then((_) => _fetchUsageStats());
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Earlier Reports'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
                const SizedBox(height: 48),
                const Divider(),
                // Usage Stats Card (Moved to bottom)
                if (_usageStats != null)
                  UsageStatsCard(
                    storageUsedBytes: _usageStats!['storage_used_bytes'] ?? 0, 
                    runsUsedCount: _usageStats!['runs_used_count'] ?? 0
                  )
                else if (_loadingStats)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  )),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
