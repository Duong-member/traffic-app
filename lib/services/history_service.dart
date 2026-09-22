import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class HistoryService {
  final FirebaseFirestore _firestore =
      FirebaseFirestore.instance;

  final FirebaseAuth _auth =
      FirebaseAuth.instance;

  Future<void> saveHistory({
    required String signName,
    required String displayName,
    required double confidence,
    required String warning,
    double? latitude,
    double? longitude,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      print('Chưa đăng nhập Firebase');
      return;
    }

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('history')
          .add({
        'signName': signName,
        'displayName': displayName,
        'confidence': confidence,
        'warning': warning,
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': FieldValue.serverTimestamp(),
      });

      print('✅ Đã lưu lịch sử: $displayName');
    } catch (e) {
      print('❌ Lỗi lưu lịch sử: $e');
    }
  }

  Stream<QuerySnapshot<Map<String, dynamic>>>
      getHistory() {
    final User? user = _auth.currentUser;

    if (user == null) {
      return const Stream.empty();
    }

    return _firestore
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .orderBy(
          'timestamp',
          descending: true,
        )
        .snapshots();
  }

  Future<void> deleteHistory(
    String historyId,
  ) async {
    final User? user = _auth.currentUser;

    if (user == null) return;

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .doc(historyId)
        .delete();
  }

  Future<void> deleteAllHistory() async {
    final User? user = _auth.currentUser;

    if (user == null) return;

    final snapshot = await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('history')
        .get();

    final batch = _firestore.batch();

    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }
}