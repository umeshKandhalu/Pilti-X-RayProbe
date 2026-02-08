class AnalysisResult {
  final Map<String, double> predictions;
  final String topFinding;
  final String heatmapBase64;

  final bool isHighConfidence;
  final String modelInfo;

  AnalysisResult({
    required this.predictions,
    required this.topFinding,
    required this.heatmapBase64,
    this.isHighConfidence = false,
    this.modelInfo = "Standard Model",
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) {
    return AnalysisResult(
      predictions: Map<String, double>.from(json['predictions']),
      topFinding: json['top_finding'] as String,
      heatmapBase64: json['heatmap'] as String,
      isHighConfidence: json['is_high_confidence'] ?? false,
      modelInfo: json['model_info'] ?? "Standard Model",
    );
  }
}
