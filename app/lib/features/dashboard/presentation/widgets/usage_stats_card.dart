import 'package:flutter/material.dart';
import '../../../../shared/widgets/circular_usage_indicator.dart';

class UsageStatsCard extends StatelessWidget {
  final int storageUsedBytes;
  final int runsUsedCount;
  
  // Limits (These should ideally come from backend but for now matched defaults)
  static const int storageLimitBytes = 1024 * 1024 * 1024; // 1 GB default
  static const int runsLimitCount = 100; // 100 runs default

  const UsageStatsCard({
    super.key,
    required this.storageUsedBytes,
    required this.runsUsedCount,
  });

  @override
  Widget build(BuildContext context) {
    final double storagePercent = (storageUsedBytes / storageLimitBytes).clamp(0.0, 1.0);
    final double runsPercent = (runsUsedCount / runsLimitCount).clamp(0.0, 1.0);
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: 0.5,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.analytics_outlined, size: 14, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  "MY PLAN USAGE",
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    letterSpacing: 1.0,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: Colors.blueGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                CircularUsageIndicator(
                  label: "Storage",
                  value: _formatBytes(storageUsedBytes),
                  total: "1 GB",
                  percent: storagePercent,
                  size: 50,
                ),
                CircularUsageIndicator(
                  label: "AI Runs",
                  value: "$runsUsedCount",
                  total: "100",
                  percent: runsPercent,
                  size: 50,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return "$bytes B";
    if (bytes < 1024 * 1024) return "${(bytes / 1024).toStringAsFixed(1)} KB";
    if (bytes < 1024 * 1024 * 1024) return "${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB";
    return "${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB";
  }
}
