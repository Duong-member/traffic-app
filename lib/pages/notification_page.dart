import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/history_service.dart';

class NotificationPage extends StatelessWidget {
  const NotificationPage({super.key});

  @override
  Widget build(BuildContext context) {
    final HistoryService historyService =
        HistoryService();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),

      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,

        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
            color: Color(0xFF1F2937),
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),

        title: const Text(
          'Cảnh báo',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Color(0xFF1F2937),
          ),
        ),

        centerTitle: true,
      ),

      body: StreamBuilder<
          QuerySnapshot<Map<String, dynamic>>>(
        stream: historyService.getHistory(),

        builder: (context, snapshot) {
          // ==================================================
          // ĐANG TẢI
          // ==================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF1677FF),
              ),
            );
          }

          // ==================================================
          // CÓ LỖI
          // ==================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 60,
                      color: Colors.redAccent,
                    ),

                    const SizedBox(height: 16),

                    const Text(
                      'Không thể tải cảnh báo',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          // ==================================================
          // KHÔNG CÓ DỮ LIỆU
          // ==================================================

          if (!snapshot.hasData ||
              snapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          final docs =
              snapshot.data!.docs;

          // ==================================================
          // HIỂN THỊ DANH SÁCH CẢNH BÁO
          // ==================================================

          return ListView.builder(
            padding:
                const EdgeInsets.all(16),

            itemCount: docs.length,

            itemBuilder:
                (context, index) {
              final doc = docs[index];

              final data = doc.data();

              final String displayName =
                  data['displayName'] ??
                      'Biển báo giao thông';

              final String warning =
                  data['warning'] ??
                      'Đã phát hiện biển báo giao thông';

              final double confidence =
                  _getConfidence(
                data['confidence'],
              );

              final Timestamp? timestamp =
                  data['timestamp']
                      as Timestamp?;

              final String time =
                  _formatTime(timestamp);

              final bool isSpeedSign =
                  displayName.contains(
                        'KM/H',
                      ) ||
                      displayName.contains(
                        'TỐC ĐỘ',
                      );

              return Padding(
                padding:
                    const EdgeInsets.only(
                  bottom: 12,
                ),

                child:
                    _buildNotificationCard(
                  icon: isSpeedSign
                      ? Icons.speed
                      : Icons
                          .warning_amber_rounded,

                  title: displayName,

                  message: warning,

                  time: time,

                  confidence: confidence,

                  iconColor: isSpeedSign
                      ? Colors.orange
                      : Colors.amber,
                ),
              );
            },
          );
        },
      ),
    );
  }

  // ============================================================
  // LẤY CONFIDENCE
  // ============================================================

  double _getConfidence(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is num) {
      return value.toDouble();
    }

    return 0;
  }

  // ============================================================
  // FORMAT THỜI GIAN
  // ============================================================

  String _formatTime(
    Timestamp? timestamp,
  ) {
    if (timestamp == null) {
      return 'Đang cập nhật...';
    }

    final DateTime date =
        timestamp.toDate();

    final DateTime now =
        DateTime.now();

    final Duration difference =
        now.difference(date);

    if (difference.inSeconds < 60) {
      return 'Vừa xong';
    }

    if (difference.inMinutes < 60) {
      return '${difference.inMinutes} phút trước';
    }

    if (difference.inHours < 24) {
      return '${difference.inHours} giờ trước';
    }

    if (difference.inDays == 1) {
      return 'Hôm qua';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year} '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // TRẠNG THÁI KHÔNG CÓ CẢNH BÁO
  // ============================================================

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),

        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            Container(
              width: 90,
              height: 90,

              decoration:
                  BoxDecoration(
                color:
                    const Color(0xFF1677FF)
                        .withOpacity(0.1),

                shape:
                    BoxShape.circle,
              ),

              child: const Icon(
                Icons.notifications_none,
                size: 45,
                color: Color(0xFF1677FF),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Chưa có cảnh báo',
              style: TextStyle(
                fontSize: 20,
                fontWeight:
                    FontWeight.bold,
                color:
                    Color(0xFF1F2937),
              ),
            ),

            const SizedBox(height: 8),

            const Text(
              'Các cảnh báo từ hệ thống '
              'nhận diện AI sẽ xuất hiện ở đây.',
              textAlign:
                  TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // CARD CẢNH BÁO
  // ============================================================

  Widget _buildNotificationCard({
    required IconData icon,
    required String title,
    required String message,
    required String time,
    required double confidence,
    required Color iconColor,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(16),

      decoration:
          BoxDecoration(
        color: Colors.white,

        borderRadius:
            BorderRadius.circular(16),

        border: Border.all(
          color:
              const Color(0xFFE5E7EB),
        ),

        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withOpacity(
              0.03,
            ),
            blurRadius: 8,
            offset:
                const Offset(0, 2),
          ),
        ],
      ),

      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,

        children: [
          // ====================================================
          // ICON
          // ====================================================

          Container(
            width: 48,
            height: 48,

            decoration:
                BoxDecoration(
              color:
                  iconColor.withOpacity(
                0.12,
              ),

              borderRadius:
                  BorderRadius.circular(
                14,
              ),
            ),

            child: Icon(
              icon,
              color: iconColor,
              size: 26,
            ),
          ),

          const SizedBox(width: 14),

          // ====================================================
          // NỘI DUNG
          // ====================================================

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  title,

                  style:
                      const TextStyle(
                    fontSize: 16,
                    fontWeight:
                        FontWeight.bold,
                    color:
                        Color(0xFF1F2937),
                  ),
                ),

                const SizedBox(height: 6),

                Text(
                  message,

                  style:
                      const TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    height: 1.4,
                  ),
                ),

                const SizedBox(height: 10),

                // =================================================
                // CONFIDENCE
                // =================================================

                if (confidence > 0)
                  Row(
                    children: [
                      const Icon(
                        Icons.analytics_outlined,
                        size: 15,
                        color:
                            Color(0xFF1677FF),
                      ),

                      const SizedBox(
                        width: 5,
                      ),

                      Text(
                        'Độ tin cậy: '
                        '${(confidence * 100).toStringAsFixed(1)}%',

                        style:
                            const TextStyle(
                          fontSize: 12,
                          color:
                              Color(0xFF1677FF),
                          fontWeight:
                              FontWeight.w600,
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 7),

                // =================================================
                // THỜI GIAN
                // =================================================

                Row(
                  children: [
                    const Icon(
                      Icons.access_time,
                      size: 14,
                      color: Colors.grey,
                    ),

                    const SizedBox(
                      width: 5,
                    ),

                    Text(
                      time,

                      style:
                          const TextStyle(
                        fontSize: 12,
                        color:
                            Colors.grey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}