import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../services/auth_service.dart';

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final User? user = FirebaseAuth.instance.currentUser;

    final String displayName =
        user?.displayName ?? 'Người dùng';

    final String email =
        user?.email ?? 'Chưa có email';

    final String? photoUrl =
        user?.photoURL;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        title: const Text(
          'Tài khoản',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),

        centerTitle: true,
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),

        child: Column(
          children: [
            // ==============================
            // AVATAR
            // ==============================

            Container(
              width: 100,
              height: 100,

              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE8F0FE),

                image: photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(photoUrl),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),

              child: photoUrl == null
                  ? const Icon(
                      Icons.person,
                      size: 55,
                      color: Color(0xFF1677FF),
                    )
                  : null,
            ),

            const SizedBox(height: 16),

            // ==============================
            // TÊN
            // ==============================

            Text(
              displayName,
              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1F2937),
              ),
            ),

            const SizedBox(height: 6),

            Text(
              email,
              textAlign: TextAlign.center,

              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),

            const SizedBox(height: 30),

            // ==============================
            // THÔNG TIN TÀI KHOẢN
            // ==============================

            _buildMenuItem(
              icon: Icons.person_outline,
              title: 'Thông tin tài khoản',
              subtitle: 'Thông tin đăng nhập Google',
              onTap: () {
                _showAccountInfo(
                  context,
                  displayName,
                  email,
                );
              },
            ),

            const SizedBox(height: 12),

            _buildMenuItem(
              icon: Icons.notifications_none,
              title: 'Thông báo',
              subtitle: 'Quản lý cảnh báo giao thông',
              onTap: () {
                Navigator.pop(context);
              },
            ),

            const SizedBox(height: 12),

            _buildMenuItem(
              icon: Icons.info_outline,
              title: 'Về ứng dụng',
              subtitle: 'Giao Thông Thông Minh',
              onTap: () {
                showAboutDialog(
                  context: context,
                  applicationName:
                      'Giao Thông Thông Minh',
                  applicationVersion: '1.0.0',
                  applicationIcon: const Icon(
                    Icons.traffic,
                    color: Color(0xFF1677FF),
                  ),
                  children: const [
                    Text(
                      'Ứng dụng hỗ trợ lái xe thông minh '
                      'kết hợp AI nhận diện biển báo '
                      'giao thông và bản đồ số.',
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 30),

            // ==============================
            // ĐĂNG XUẤT
            // ==============================

            SizedBox(
              width: double.infinity,
              height: 52,

              child: OutlinedButton.icon(
                onPressed: () async {
                  final shouldLogout =
                      await showDialog<bool>(
                    context: context,

                    builder: (context) {
                      return AlertDialog(
                        title: const Text(
                          'Đăng xuất',
                        ),

                        content: const Text(
                          'Bạn có chắc muốn đăng xuất '
                          'khỏi tài khoản không?',
                        ),

                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                false,
                              );
                            },

                            child: const Text(
                              'Hủy',
                            ),
                          ),

                          FilledButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                true,
                              );
                            },

                            child: const Text(
                              'Đăng xuất',
                            ),
                          ),
                        ],
                      );
                    },
                  );

                  if (shouldLogout == true) {
                    await AuthService().signOut();

                    if (context.mounted) {
                      Navigator.of(context).popUntil(
                        (route) => route.isFirst,
                      );
                    }
                  }
                },

                icon: const Icon(
                  Icons.logout,
                  color: Colors.red,
                ),

                label: const Text(
                  'Đăng xuất',
                  style: TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),

                style: OutlinedButton.styleFrom(
                  side: const BorderSide(
                    color: Colors.red,
                  ),

                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,

      borderRadius: BorderRadius.circular(16),

      child: InkWell(
        onTap: onTap,

        borderRadius: BorderRadius.circular(16),

        child: Padding(
          padding: const EdgeInsets.all(16),

          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,

                decoration: BoxDecoration(
                  color: const Color(0xFFEAF2FF),
                  borderRadius:
                      BorderRadius.circular(14),
                ),

                child: Icon(
                  icon,
                  color: const Color(0xFF1677FF),
                ),
              ),

              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,

                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 4),

                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),

              const Icon(
                Icons.chevron_right,
                color: Colors.grey,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAccountInfo(
    BuildContext context,
    String name,
    String email,
  ) {
    showDialog(
      context: context,

      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Thông tin tài khoản',
          ),

          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,

            children: [
              const Text(
                'Họ và tên',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(name),

              const SizedBox(height: 16),

              const Text(
                'Email',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 4),

              Text(email),
            ],
          ),

          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },

              child: const Text('Đóng'),
            ),
          ],
        );
      },
    );
  }
}