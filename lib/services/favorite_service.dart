import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/favorite_model.dart';

class FavoriteService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  // Lấy danh sách địa điểm yêu thích
  Stream<List<FavoriteModel>> getFavorites() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) {
            return snapshot.docs.map(
              (doc) {
                return FavoriteModel.fromMap(
                  doc.id,
                  doc.data(),
                );
              },
            ).toList();
          },
        );
  }

  // Thêm địa điểm yêu thích
  Future<void> addFavorite({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('Bạn chưa đăng nhập');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .add({
      'name': name,
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // Xóa một địa điểm yêu thích
  Future<void> deleteFavorite(
    String favoriteId,
  ) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw Exception('Bạn chưa đăng nhập');
    }

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('favorites')
        .doc(favoriteId)
        .delete();
  }
}