import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../models/favorite_model.dart';
import '../services/favorite_service.dart';

class FavoritePage extends StatefulWidget {
  const FavoritePage({super.key});

  @override
  State<FavoritePage> createState() => _FavoritePageState();
}

class _FavoritePageState extends State<FavoritePage> {
  final FavoriteService _favoriteService = FavoriteService();

  Future<Position?> _getCurrentPosition() async {
    try {
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng bật GPS'),
            ),
          );
        }
        return null;
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Ứng dụng chưa được cấp quyền vị trí',
              ),
            ),
          );
        }
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
    } catch (e) {
      debugPrint('GPS Error: $e');
      return null;
    }
  }

  Future<void> _addFavorite() async {
    final TextEditingController nameController =
        TextEditingController();

    final TextEditingController addressController =
        TextEditingController();

    Position? position;

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            '⭐ Thêm địa điểm yêu thích',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Tên địa điểm',
                  hintText: 'Ví dụ: Trường học',
                  prefixIcon: Icon(Icons.place),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                decoration: const InputDecoration(
                  labelText: 'Địa chỉ',
                  hintText: 'Nhập địa chỉ',
                  prefixIcon: Icon(Icons.location_on),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () async {
                  final result =
                      await _getCurrentPosition();

                  if (result != null) {
                    position = result;

                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(
                        SnackBar(
                          content: Text(
                            'Đã lấy vị trí: '
                            '${result.latitude.toStringAsFixed(6)}, '
                            '${result.longitude.toStringAsFixed(6)}',
                          ),
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.my_location),
                label: const Text(
                  'Lấy vị trí hiện tại',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (nameController.text.trim().isEmpty) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng nhập tên địa điểm',
                      ),
                    ),
                  );
                  return;
                }

                if (position == null) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Vui lòng lấy vị trí GPS',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  await _favoriteService.addFavorite(
                    name: nameController.text.trim(),
                    address:
                        addressController.text.trim(),
                    latitude: position!.latitude,
                    longitude: position!.longitude,
                  );

                  if (context.mounted) {
                    Navigator.pop(context);

                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      const SnackBar(
                        content: Text(
                          '✅ Đã lưu địa điểm yêu thích',
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(
                      SnackBar(
                        content: Text(
                          'Lỗi: $e',
                        ),
                      ),
                    );
                  }
                }
              },
              child: const Text('Lưu'),
            ),
          ],
        );
      },
    );

    nameController.dispose();
    addressController.dispose();
  }

  Future<void> _deleteFavorite(
    FavoriteModel favorite,
  ) async {
    final bool? confirm =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Xóa địa điểm?',
          ),
          content: Text(
            'Bạn có chắc muốn xóa '
            '"${favorite.name}" không?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
              },
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context, true);
              },
              child: const Text('Xóa'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;

    try {
      await _favoriteService.deleteFavorite(
        favorite.id,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              '🗑️ Đã xóa địa điểm',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(
          SnackBar(
            content: Text(
              'Lỗi khi xóa: $e',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          '⭐ Địa điểm yêu thích',
        ),
        centerTitle: true,
      ),
      body: StreamBuilder<List<FavoriteModel>>(
        stream: _favoriteService.getFavorites(),
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                'Lỗi: ${snapshot.error}',
              ),
            );
          }

          final favorites =
              snapshot.data ?? [];

          if (favorites.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.star_border,
                      size: 80,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Chưa có địa điểm yêu thích',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Hãy thêm những địa điểm '
                      'bạn thường xuyên di chuyển đến.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _addFavorite,
                      icon: const Icon(Icons.add),
                      label: const Text(
                        'Thêm địa điểm',
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: favorites.length,
            itemBuilder: (context, index) {
              final favorite =
                  favorites[index];

              return Card(
                margin:
                    const EdgeInsets.only(
                  bottom: 12,
                ),
                child: ListTile(
                  leading: const CircleAvatar(
                    child: Icon(
                      Icons.location_on,
                    ),
                  ),
                  title: Text(
                    favorite.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  subtitle: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      if (favorite.address
                          .isNotEmpty)
                        Text(
                          favorite.address,
                        ),
                      const SizedBox(height: 4),
                      Text(
                        '${favorite.latitude.toStringAsFixed(6)}, '
                        '${favorite.longitude.toStringAsFixed(6)}',
                        style: const TextStyle(
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  isThreeLine: true,
                  trailing: IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                    ),
                    onPressed: () =>
                        _deleteFavorite(
                      favorite,
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton:
          FloatingActionButton.extended(
        onPressed: _addFavorite,
        icon: const Icon(Icons.add),
        label: const Text(
          'Thêm địa điểm',
        ),
      ),
    );
  }
}