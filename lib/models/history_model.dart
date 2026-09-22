class HistoryModel {
  final String id;
  final String signName;
  final String displayName;
  final double confidence;
  final String warning;
  final double? latitude;
  final double? longitude;
  final DateTime timestamp;

  HistoryModel({
    required this.id,
    required this.signName,
    required this.displayName,
    required this.confidence,
    required this.warning,
    this.latitude,
    this.longitude,
    required this.timestamp,
  });

  factory HistoryModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return HistoryModel(
      id: id,
      signName: data['signName'] ?? '',
      displayName: data['displayName'] ?? '',
      confidence:
          (data['confidence'] ?? 0).toDouble(),
      warning: data['warning'] ?? '',
      latitude:
          data['latitude'] != null
              ? (data['latitude'] as num).toDouble()
              : null,
      longitude:
          data['longitude'] != null
              ? (data['longitude'] as num).toDouble()
              : null,
      timestamp:
          data['timestamp'] != null
              ? (data['timestamp'] as dynamic).toDate()
              : DateTime.now(),
    );
  }
}