import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart'; // New import
import 'package:url_launcher/url_launcher.dart'; // New import
import 'analysis_screen.dart';
import 'user_reports_screen.dart';
import 'login_screen.dart'; 
import '../services/api_service.dart';

class HomeScreen extends StatefulWidget { // Keep as StatefulWidget to manage disclaimer state
  final String userEmail; // New required parameter
  
  const HomeScreen({super.key, required this.userEmail});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _acceptedDisclaimer = false;

  void _navigateToAnalysis() {
    if (_acceptedDisclaimer) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (context) => AnalysisScreen(userEmail: widget.userEmail)),
      );
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
                Center(
                  child: Image.asset('assets/logo.png', height: 120), // Reduced height for mobile
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
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => UserReportsScreen(userEmail: widget.userEmail)),
                    );
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Earlier Reports'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
