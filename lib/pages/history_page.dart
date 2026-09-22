import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/history_service.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final HistoryService _historyService =
      HistoryService();

  // ==========================================================
  // XÓA MỘT LỊCH SỬ
  // ==========================================================

  Future<void> _deleteHistory(
    String historyId,
  ) async {
    try {
      await _historyService.deleteHistory(
        historyId,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Đã xóa lịch sử nhận diện'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Không thể xóa lịch sử: $e'),
        ),
      );
    }
  }

  // ==========================================================
  // XÓA TẤT CẢ
  // ==========================================================

  Future<void> _deleteAllHistory() async {
    final shouldDelete =
        await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Xóa tất cả lịch sử?',
          ),
          content: const Text(
            'Bạn có chắc muốn xóa toàn bộ '
            'lịch sử nhận diện không?',
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
            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text(
                'Xóa tất cả',
              ),
            ),
          ],
        );
      },
    );

    if (shouldDelete != true) {
      return;
    }

    try {
      await _historyService.deleteAllHistory();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('Đã xóa toàn bộ lịch sử'),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('Không thể xóa lịch sử: $e'),
        ),
      );
    }
  }

  // ==========================================================
  // FORMAT THỜI GIAN
  // ==========================================================

  String _formatTimestamp(
    dynamic timestamp,
  ) {
    if (timestamp == null) {
      return 'Đang cập nhật...';
    }

    if (timestamp is Timestamp) {
      final date =
          timestamp.toDate();

      final day =
          date.day.toString().padLeft(2, '0');

      final month =
          date.month.toString().padLeft(2, '0');

      final year =
          date.year.toString();

      final hour =
          date.hour.toString().padLeft(2, '0');

      final minute =
          date.minute.toString().padLeft(2, '0');

      final second =
          date.second.toString().padLeft(2, '0');

      return '$day/$month/$year - '
          '$hour:$minute:$second';
    }

    return 'Không xác định';
  }

  // ==========================================================
  // ICON BIỂN BÁO
  // ==========================================================

  IconData _getSignIcon(
    String signName,
  ) {
    if (signName.contains(
          'toc_do_toi_da',
        )) {
      return Icons.speed;
    }

    if (signName.contains(
          'cam_',
        )) {
      return Icons.block;
    }

    if (signName.contains(
          'nguy_hiem',
        ) ||
        signName.contains(
          'chu_y',
        )) {
      return Icons.warning_amber_rounded;
    }

    return Icons.traffic;
  }

  // ==========================================================
  // MÀU ICON
  // ==========================================================

  Color _getSignColor(
    String signName,
  ) {
    if (signName.contains(
          'toc_do_toi_da',
        )) {
      return Colors.redAccent;
    }

    if (signName.contains(
          'cam_',
        )) {
      return Colors.red;
    }

    return Colors.orange;
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F7FB),

      appBar: AppBar(
        backgroundColor:
            Colors.white,

        elevation: 0,

        foregroundColor:
            Colors.black,

        title: const Text(
          'Lịch sử nhận diện',
          style: TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),

        centerTitle: true,

        actions: [
          IconButton(
            tooltip:
                'Xóa tất cả',

            icon: const Icon(
              Icons.delete_sweep_outlined,
            ),

            onPressed:
                _deleteAllHistory,
          ),
        ],
      ),

      body: StreamBuilder<
          QuerySnapshot<
              Map<String, dynamic>>>(
        stream:
            _historyService.getHistory(),

        builder:
            (context, snapshot) {
          // ==================================================
          // ĐANG TẢI
          // ==================================================

          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          // ==================================================
          // LỖI
          // ==================================================

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  24,
                ),

                child: Column(
                  mainAxisAlignment:
                      MainAxisAlignment.center,

                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.red,
                      size: 60,
                    ),

                    const SizedBox(
                        height: 16),

                    const Text(
                      'Không thể tải lịch sử',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),

                    const SizedBox(
                        height: 8),

                    Text(
                      '${snapshot.error}',
                      textAlign:
                          TextAlign.center,

                      style:
                          const TextStyle(
                        color:
                            Colors.grey,
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

          final documents =
              snapshot.data?.docs ?? [];

          if (documents.isEmpty) {
            return RefreshIndicator(
              onRefresh: () async {
                setState(() {});
              },

              child:
                  ListView(
                physics:
                    const AlwaysScrollableScrollPhysics(),

                children: [
                  SizedBox(
                    height:
                        MediaQuery.of(context)
                                .size
                                .height *
                            0.30,
                  ),

                  const Icon(
                    Icons.history,
                    size: 80,
                    color:
                        Colors.grey,
                  ),

                  const SizedBox(
                      height: 20),

                  const Center(
                    child: Text(
                      'Chưa có lịch sử nhận diện',
                      style:
                          TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(
                      height: 8),

                  const Center(
                    child: Text(
                      'Các biển báo được AI nhận diện '
                      'sẽ xuất hiện tại đây.',
                      textAlign:
                          TextAlign.center,
                      style:
                          TextStyle(
                        color:
                            Colors.grey,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }

          // ==================================================
          // CÓ DỮ LIỆU
          // ==================================================

          return ListView.builder(
            padding:
                const EdgeInsets.all(
              16,
            ),

            itemCount:
                documents.length,

            itemBuilder:
                (context, index) {
              final doc =
                  documents[index];

              final data =
                  doc.data();

              final String signName =
                  data['signName'] ??
                  '';

              final String displayName =
                  data['displayName'] ??
                  'Biển báo không xác định';

              final String warning =
                  data['warning'] ??
                  'Đã nhận diện biển báo giao thông';

              final double confidence =
                  data['confidence'] != null
                      ? (data['confidence']
                              as num)
                          .toDouble()
                      : 0;

              final dynamic timestamp =
                  data['timestamp'];

              final IconData icon =
                  _getSignIcon(signName);

              final Color iconColor =
                  _getSignColor(signName);

              return Dismissible(
                key: Key(doc.id),

                direction:
                    DismissDirection.endToStart,

                confirmDismiss:
                    (direction) async {
                  return await showDialog<
                      bool>(
                    context: context,
                    builder:
                        (context) {
                      return AlertDialog(
                        title: const Text(
                          'Xóa lịch sử?',
                        ),
                        content:
                            const Text(
                          'Bạn có muốn xóa '
                          'bản ghi này không?',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                false,
                              );
                            },
                            child:
                                const Text(
                              'Hủy',
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () {
                              Navigator.pop(
                                context,
                                true,
                              );
                            },
                            child:
                                const Text(
                              'Xóa',
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },

                onDismissed:
                    (direction) {
                  _deleteHistory(
                    doc.id,
                  );
                },

                background:
                    Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),

                  alignment:
                      Alignment.centerRight,

                  padding:
                      const EdgeInsets.only(
                    right: 20,
                  ),

                  decoration:
                      BoxDecoration(
                    color: Colors.red,
                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),
                  ),

                  child:
                      const Icon(
                    Icons.delete,
                    color:
                        Colors.white,
                  ),
                ),

                child:
                    Container(
                  margin:
                      const EdgeInsets.only(
                    bottom: 12,
                  ),

                  padding:
                      const EdgeInsets.all(
                    16,
                  ),

                  decoration:
                      BoxDecoration(
                    color:
                        Colors.white,

                    borderRadius:
                        BorderRadius.circular(
                      18,
                    ),

                    boxShadow: [
                      BoxShadow(
                        color: Colors
                            .black
                            .withOpacity(
                          0.05,
                        ),
                        blurRadius:
                            10,
                        offset:
                            const Offset(
                          0,
                          3,
                        ),
                      ),
                    ],
                  ),

                  child:
                      Column(
                    crossAxisAlignment:
                        CrossAxisAlignment
                            .start,

                    children: [
                      // ========================================
                      // TIÊU ĐỀ
                      // ========================================

                      Row(
                        children: [
                          Container(
                            width: 50,
                            height: 50,

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

                            child:
                                Icon(
                              icon,
                              color:
                                  iconColor,
                              size: 28,
                            ),
                          ),

                          const SizedBox(
                              width: 14),

                          Expanded(
                            child:
                                Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment
                                      .start,

                              children: [
                                Text(
                                  displayName,

                                  style:
                                      const TextStyle(
                                    fontSize:
                                        16,
                                    fontWeight:
                                        FontWeight
                                            .bold,
                                  ),
                                ),

                                const SizedBox(
                                    height: 5),

                                Text(
                                  _formatTimestamp(
                                    timestamp,
                                  ),

                                  style:
                                      const TextStyle(
                                    fontSize:
                                        12,
                                    color:
                                        Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(
                          height: 14),

                      // ========================================
                      // CẢNH BÁO
                      // ========================================

                      Container(
                        width:
                            double.infinity,

                        padding:
                            const EdgeInsets
                                .all(
                          12,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFFFF7E6,
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            12,
                          ),
                        ),

                        child:
                            Row(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,

                          children: [
                            const Icon(
                              Icons
                                  .warning_amber_rounded,
                              color:
                                  Colors.orange,
                              size: 20,
                            ),

                            const SizedBox(
                                width: 8),

                            Expanded(
                              child:
                                  Text(
                                warning,

                                style:
                                    const TextStyle(
                                  fontSize:
                                      13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(
                          height: 12),

                      // ========================================
                      // CONFIDENCE
                      // ========================================

                      Row(
                        children: [
                          const Icon(
                            Icons
                                .analytics_outlined,
                            size: 18,
                            color:
                                Colors.blue,
                          ),

                          const SizedBox(
                              width: 6),

                          Text(
                            'Độ tin cậy: '
                            '${(confidence * 100).toStringAsFixed(1)}%',

                            style:
                                const TextStyle(
                              fontSize:
                                  13,
                              fontWeight:
                                  FontWeight
                                      .w600,
                            ),
                          ),
                        ],
                      ),

                      // ========================================
                      // GPS NẾU CÓ
                      // ========================================

                      if (data['latitude'] !=
                              null &&
                          data['longitude'] !=
                              null) ...[
                        const SizedBox(
                            height: 8),

                        Row(
                          children: [
                            const Icon(
                              Icons
                                  .location_on_outlined,
                              size: 18,
                              color:
                                  Colors.blue,
                            ),

                            const SizedBox(
                                width: 6),

                            Text(
                              '${(data['latitude'] as num).toStringAsFixed(6)}, '
                              '${(data['longitude'] as num).toStringAsFixed(6)}',

                              style:
                                  const TextStyle(
                                fontSize:
                                    12,
                                color:
                                    Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}