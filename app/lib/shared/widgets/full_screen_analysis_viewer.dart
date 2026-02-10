import 'package:flutter/material.dart';
import '../../shared/models/analysis_result.dart';

class FullScreenAnalysisViewer extends StatelessWidget {
  final AnalysisResult result;

  const FullScreenAnalysisViewer({
    super.key,
    required this.result,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Analysis Summary'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Finding Card
            Card(
              elevation: 4,
              color: result.topFinding == 'No Findings' ? Colors.green.shade50 : Colors.orange.shade50,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: result.topFinding == 'No Findings' ? Colors.green : Colors.orange,
                  width: 2,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Icon(
                      result.topFinding == 'No Findings' ? Icons.check_circle : Icons.warning_amber_rounded,
                      color: result.topFinding == 'No Findings' ? Colors.green : Colors.orange,
                      size: 40,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Primary Detection', style: TextStyle(fontSize: 14, color: Colors.black54)),
                          Text(
                            result.topFinding,
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: result.topFinding == 'No Findings' ? Colors.green[800] : Colors.deepOrange[800],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            
            const Text(
              'Detailed Confidence Probabilities',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Below are the confidence scores for various conditions detected by the AI model.',
              style: TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 24),

            // Predictions List
            ...result.predictions.entries.map((e) {
              final val = e.value;
              final isHigh = val > 0.7;
              final isMed = val > 0.3;
              final color = isHigh ? Colors.red : (isMed ? Colors.orange : Colors.green);
              
              return Padding(
                padding: const EdgeInsets.only(bottom: 20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(e.key, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                        Text(
                          '${(val * 100).toStringAsFixed(1)}%',
                          style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: LinearProgressIndicator(
                        value: val,
                        minHeight: 12,
                        backgroundColor: Colors.grey[200],
                        valueColor: AlwaysStoppedAnimation<Color>(color),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),
            
            // Model Info
            Row(
              children: [
                const Icon(Icons.info_outline, size: 20, color: Colors.blueGrey),
                const SizedBox(width: 8),
                Text(
                  'Analysis Model: ${result.modelInfo}',
                  style: const TextStyle(color: Colors.blueGrey, fontStyle: FontStyle.italic),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (result.isHighConfidence)
              const Row(
                children: [
                  Icon(Icons.verified_user_sharp, size: 20, color: Colors.teal),
                  SizedBox(width: 8),
                  Text(
                    'Verification Status: High Confidence Result',
                    style: TextStyle(color: Colors.teal, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
