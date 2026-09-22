class FavoriteModel {
  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final DateTime? createdAt;

  FavoriteModel({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    this.createdAt,
  });

  factory FavoriteModel.fromMap(
    String id,
    Map<String, dynamic> data,
  ) {
    return FavoriteModel(
      id: id,
      name: data['name'] ?? 'Địa điểm yêu thích',
      address: data['address'] ?? '',
      latitude:
          (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude:
          (data['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: data['createdAt'] != null
          ? (data['createdAt'] as dynamic).toDate()
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }
}