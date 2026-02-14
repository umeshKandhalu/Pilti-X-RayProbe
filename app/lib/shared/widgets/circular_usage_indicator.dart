import 'package:flutter/material.dart';

class CircularUsageIndicator extends StatelessWidget {
  final String label;
  final String value;
  final String total;
  final double percent;
  final double size;

  const CircularUsageIndicator({
    super.key,
    required this.label,
    required this.value,
    required this.total,
    required this.percent,
    this.size = 60,
  });

  @override
  Widget build(BuildContext context) {
    // Color logic: Green < 75%, Orange < 90%, Red >= 90%
    Color progressColor = Colors.green;
    if (percent >= 0.9) {
      progressColor = Colors.red;
    } else if (percent >= 0.75) {
      progressColor = Colors.orange;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              height: size,
              width: size,
              child: CircularProgressIndicator(
                value: percent,
                strokeWidth: 6,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(progressColor),
                strokeCap: StrokeCap.round,
              ),
            ),
            Text(
              "${(percent * 100).toInt()}%",
              style: TextStyle(
                fontSize: size * 0.2, 
                fontWeight: FontWeight.bold,
                color: progressColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
        ),
        Text(
          "$value / $total",
          style: const TextStyle(fontSize: 10, color: Colors.grey),
        ),
      ],
    );
  }
}
