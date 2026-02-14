class EcgAnalysisResult {
  final List<double> signalData;
  final double samplingRate;
  final Map<String, dynamic> metrics;
  final List<String> findings;
  final String waveformBase64;
  final String modelInfo;

  EcgAnalysisResult({
    required this.signalData,
    required this.samplingRate,
    required this.metrics,
    required this.findings,
    required this.waveformBase64,
    this.modelInfo = "NeuroKit2 + Rule-based Engine",
  });

  factory EcgAnalysisResult.fromJson(Map<String, dynamic> json) {
    return EcgAnalysisResult(
      signalData: List<double>.from(json['signal_data'] ?? []),
      samplingRate: (json['sampling_rate'] ?? 250).toDouble(),
      metrics: Map<String, dynamic>.from(json['metrics'] ?? {}),
      findings: List<String>.from(json['findings'] ?? []),
      waveformBase64: json['waveform'] ?? "",
      modelInfo: json['model_info'] ?? "NeuroKit2 + Rule-based Engine",
    );
  }
}
