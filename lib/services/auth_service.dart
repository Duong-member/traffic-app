import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Lấy user hiện tại
  User? get currentUser => _auth.currentUser;

  // Theo dõi trạng thái đăng nhập
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // =========================================================
  // ĐĂNG NHẬP BẰNG GOOGLE
  // =========================================================

  Future<UserCredential?> signInWithGoogle() async {
    try {
      // -----------------------------------------------------
      // WEB
      // -----------------------------------------------------
      // Với Flutter Web, dùng Firebase Popup sẽ đơn giản
      // và ổn định hơn.
      if (kIsWeb) {
        final GoogleAuthProvider googleProvider =
            GoogleAuthProvider();

        googleProvider.addScope('email');
        googleProvider.addScope('profile');

        final UserCredential userCredential =
            await _auth.signInWithPopup(
          googleProvider,
        );

        return userCredential;
      }

      // -----------------------------------------------------
      // ANDROID / IOS
      // -----------------------------------------------------

      final GoogleSignInAccount googleUser =
          await GoogleSignIn.instance.authenticate();

      final GoogleSignInAuthentication googleAuth =
          googleUser.authentication;

      final OAuthCredential credential =
          GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(
        credential,
      );
    } catch (e) {
      print('Lỗi đăng nhập Google: $e');
      rethrow;
    }
  }

  // =========================================================
  // ĐĂNG XUẤT
  // =========================================================

  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }

      await _auth.signOut();
    } catch (e) {
      print('Lỗi đăng xuất: $e');
      rethrow;
    }
  }
}