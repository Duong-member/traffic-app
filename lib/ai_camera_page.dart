import 'dart:async';
import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import 'services/history_service.dart';

class AiCameraPage extends StatefulWidget {
  const AiCameraPage({super.key});

  @override
  State<AiCameraPage> createState() => _AiCameraPageState();
}

class _AiCameraPageState extends State<AiCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;

  bool _isInitializing = true;
  bool _isScanning = false;
  bool _wasScanningBeforeBackground = false;

  // Đang xử lý ảnh bằng AI
  bool _isProcessing = false;

  String _status = 'Đang khởi động camera...';

  Timer? _scanTimer;

  // Kết quả nhận diện
  String _detectedSign = 'Chưa phát hiện biển báo';
  double _confidence = 0;

  bool _isDisposed = false;

  // ============================================================
  // LỊCH SỬ NHẬN DIỆN
  // ============================================================

  final HistoryService _historyService =
      HistoryService();

  // Biển báo cuối cùng đã lưu
  String? _lastSavedSign;

  // Thời gian lưu gần nhất
  DateTime? _lastSavedTime;

  // Khoảng thời gian chống lưu trùng
  static const Duration historyCooldown =
      Duration(seconds: 8);

  // ============================================================
  // FASTAPI
  // ============================================================

  static const String apiUrl =
      'http://localhost:8000/predict';

  // ============================================================
  // NGƯỠNG CONFIDENCE
  // ============================================================

  static const double minConfidence = 0.50;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _initializeCamera();
  }

  // ============================================================
  // KHỞI TẠO CAMERA
  // ============================================================

  Future<void> _initializeCamera() async {
    if (_isDisposed) return;

    if (mounted) {
      setState(() {
        _isInitializing = true;
        _status = 'Đang khởi động camera...';
      });
    }

    try {
      final cameras = await availableCameras();

      if (_isDisposed) return;

      if (cameras.isEmpty) {
        if (!mounted) return;

        setState(() {
          _isInitializing = false;
          _status = 'Không tìm thấy camera';
        });

        return;
      }

      // Ưu tiên camera sau
      CameraDescription selectedCamera =
          cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection ==
            CameraLensDirection.back) {
          selectedCamera = camera;
          break;
        }
      }

      final newController = CameraController(
        selectedCamera,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await newController.initialize();

      if (_isDisposed || !mounted) {
        await newController.dispose();
        return;
      }

      final oldController = _controller;

      _controller = newController;

      if (oldController != null) {
        await oldController.dispose();
      }

      setState(() {
        _isInitializing = false;

        _status = _isScanning
            ? 'AI đang quét biển báo...'
            : 'Camera sẵn sàng';
      });

      if (_wasScanningBeforeBackground &&
          !_isScanning) {
        _startScanning();
      }
    } catch (e) {
      debugPrint(
        'Camera initialization error: $e',
      );

      if (!mounted || _isDisposed) return;

      setState(() {
        _isInitializing = false;
        _status = 'Không thể mở camera';
      });
    }
  }

  // ============================================================
  // BẮT ĐẦU NHẬN DIỆN
  // ============================================================

  void _startScanning() {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isInitializing) {
      return;
    }

    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _status = 'AI đang quét biển báo...';
    });

    _scanTimer?.cancel();

    _scanTimer = Timer.periodic(
      const Duration(milliseconds: 1200),
      (_) {
        if (!_isScanning || _isDisposed) {
          return;
        }

        _scanFrame();
      },
    );

    _scanFrame();
  }

  // ============================================================
  // QUÉT FRAME + GỬI FASTAPI
  // ============================================================

  Future<void> _scanFrame() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isInitializing ||
        _isDisposed ||
        !_isScanning) {
      return;
    }

    if (_isProcessing) {
      return;
    }

    try {
      _isProcessing = true;

      if (mounted) {
        setState(() {
          _status = 'Đang gửi ảnh đến AI...';
        });
      }

      // ======================================================
      // CHỤP ẢNH
      // ======================================================

      final XFile image =
          await controller.takePicture();

      if (_isDisposed || !_isScanning) {
        return;
      }

      // ======================================================
      // ĐỌC ẢNH
      // ======================================================

      final imageBytes =
          await image.readAsBytes();

      // ======================================================
      // TẠO REQUEST
      // ======================================================

      final request = http.MultipartRequest(
        'POST',
        Uri.parse(apiUrl),
      );

      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          imageBytes,
          filename: 'camera_frame.jpg',
          contentType:
              MediaType('image', 'jpeg'),
        ),
      );

      // ======================================================
      // GỬI FASTAPI
      // ======================================================

      final response =
          await request.send();

      final responseBody =
          await response.stream.bytesToString();

      debugPrint(
        '====================================',
      );

      debugPrint(
        'AI Response:',
      );

      debugPrint(responseBody);

      debugPrint(
        '====================================',
      );

      // ======================================================
      // KIỂM TRA HTTP
      // ======================================================

      if (response.statusCode != 200) {
        if (mounted) {
          setState(() {
            _status =
                'AI Server lỗi: '
                '${response.statusCode}';
          });
        }

        return;
      }

      // ======================================================
      // PARSE JSON
      // ======================================================

      final data = jsonDecode(responseBody);

      if (data['success'] != true) {
        if (mounted) {
          setState(() {
            _status =
                data['message'] ??
                'AI nhận diện thất bại';
          });
        }

        return;
      }

      // ======================================================
      // LẤY DANH SÁCH DETECTIONS
      // ======================================================

      final detections =
          data['detections'];

      // ======================================================
      // DEBUG TẤT CẢ DETECTION
      // ======================================================

      if (detections is List) {
        debugPrint(
          '========== DETECTIONS ==========',
        );

        for (final detection in detections) {
          if (detection is Map) {
            debugPrint(
              'class_id: ${detection['class_id']} | '
              'name: ${detection['name']} | '
              'confidence: ${detection['confidence']}',
            );
          }
        }

        debugPrint(
          '================================',
        );
      }

      // ======================================================
      // TÌM BIỂN GIỚI HẠN TỐC ĐỘ
      //
      // 50 = 40 km/h
      // 51 = 50 km/h
      // 52 = 60 km/h
      // 53 = 80 km/h
      //
      // CHỈ NHẬN NẾU CONFIDENCE >= 50%
      // ======================================================

      Map<String, dynamic>? bestSpeedDetection;

      if (detections is List) {
        for (final detection in detections) {
          if (detection is! Map) {
            continue;
          }

          final dynamic classIdValue =
              detection['class_id'];

          final dynamic confidenceValue =
              detection['confidence'];

          if (classIdValue == null ||
              confidenceValue == null) {
            continue;
          }

          final int classId =
              (classIdValue as num).toInt();

          final double confidence =
              (confidenceValue as num).toDouble();

          if (classId < 50 ||
              classId > 53) {
            continue;
          }

          if (confidence <
              minConfidence) {
            continue;
          }

          if (bestSpeedDetection == null) {
            bestSpeedDetection =
                Map<String, dynamic>.from(
              detection,
            );
          } else {
            final double oldConfidence =
                (bestSpeedDetection![
                            'confidence']
                        as num)
                    .toDouble();

            if (confidence >
                oldConfidence) {
              bestSpeedDetection =
                  Map<String, dynamic>.from(
                detection,
              );
            }
          }
        }
      }

      // ======================================================
      // NẾU PHÁT HIỆN BIỂN TỐC ĐỘ
      // ======================================================

      if (bestSpeedDetection != null) {
        final int classId =
            (bestSpeedDetection!['class_id']
                    as num)
                .toInt();

        final double confidence =
            (bestSpeedDetection!['confidence']
                    as num)
                .toDouble();

        final String signName =
            bestSpeedDetection!['name'] ??
            'toc_do_toi_da';

        String speed = '';

        switch (classId) {
          case 50:
            speed = '40';
            break;

          case 51:
            speed = '50';
            break;

          case 52:
            speed = '60';
            break;

          case 53:
            speed = '80';
            break;
        }

        final String displayName =
            'BIỂN GIỚI HẠN $speed KM/H';

        debugPrint(
          '====================================',
        );

        debugPrint(
          'BIEN $speed KM/H DUOC PHAT HIEN',
        );

        debugPrint(
          'Class ID: $classId',
        );

        debugPrint(
          'Confidence: '
          '${confidence.toStringAsFixed(4)}',
        );

        debugPrint(
          'Confidence %: '
          '${(confidence * 100).toStringAsFixed(1)}%',
        );

        debugPrint(
          '====================================',
        );

        if (mounted) {
          setState(() {
            _detectedSign = displayName;

            _confidence = confidence;

            _status =
                'Đã phát hiện biển báo '
                '$speed km/h';
          });
        }

        // ====================================================
        // LƯU LỊCH SỬ FIRESTORE + GPS
        // ====================================================

        await _saveDetectionHistory(
          signName: signName,
          displayName: displayName,
          confidence: confidence,
        );

        return;
      }

      // ======================================================
      // KHÔNG CÓ BIỂN TỐC ĐỘ ĐỦ CONFIDENCE
      // ======================================================

      Map<String, dynamic>? bestDetection;

      if (detections is List) {
        for (final detection in detections) {
          if (detection is! Map) {
            continue;
          }

          final dynamic confidenceValue =
              detection['confidence'];

          if (confidenceValue == null) {
            continue;
          }

          final double confidence =
              (confidenceValue as num).toDouble();

          if (confidence <
              minConfidence) {
            continue;
          }

          if (bestDetection == null) {
            bestDetection =
                Map<String, dynamic>.from(
              detection,
            );
          } else {
            final double oldConfidence =
                (bestDetection!['confidence']
                        as num)
                    .toDouble();

            if (confidence >
                oldConfidence) {
              bestDetection =
                  Map<String, dynamic>.from(
                detection,
              );
            }
          }
        }
      }

      // ======================================================
      // CÓ BIỂN KHÁC ĐỦ CONFIDENCE
      // ======================================================

      if (bestDetection != null) {
        final String name =
            bestDetection!['name'] ??
            'Không xác định';

        final double confidence =
            (bestDetection!['confidence']
                    as num)
                .toDouble();

        final String displayName =
            _convertSignName(name);

        debugPrint(
          '====================================',
        );

        debugPrint(
          'BIEN BAO KHAC DUOC PHAT HIEN',
        );

        debugPrint(
          'Name: $name',
        );

        debugPrint(
          'Confidence: '
          '${confidence.toStringAsFixed(4)}',
        );

        debugPrint(
          '====================================',
        );

        if (mounted) {
          setState(() {
            _detectedSign =
                displayName;

            _confidence = confidence;

            _status =
                'Đã nhận diện biển báo';
          });
        }

        // ====================================================
        // LƯU LỊCH SỬ FIRESTORE + GPS
        // ====================================================

        await _saveDetectionHistory(
          signName: name,
          displayName: displayName,
          confidence: confidence,
        );

        return;
      }

      // ======================================================
      // KHÔNG CÓ BIỂN NÀO ĐỦ CONFIDENCE
      // ======================================================

      debugPrint(
        '====================================',
      );

      debugPrint(
        'KHONG CO BIEN BAO DU CONFIDENCE',
      );

      debugPrint(
        '====================================',
      );

      if (mounted) {
        setState(() {
          _detectedSign =
              'Chưa phát hiện biển báo';

          _confidence = 0;

          _status =
              'AI đang quét biển báo...';
        });
      }
    } catch (e) {
      debugPrint(
        'AI Scan Error: $e',
      );

      if (mounted) {
        setState(() {
          _status =
              'Không kết nối được AI Server';
        });
      }
    } finally {
      _isProcessing = false;
    }
  }

  // ============================================================
  // LẤY GPS HIỆN TẠI
  // ============================================================

  Future<Position?> _getCurrentPosition() async {
    try {
      // Kiểm tra GPS có đang bật không
      final bool serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        debugPrint(
          '⚠️ GPS đang tắt',
        );

        return null;
      }

      // Kiểm tra quyền vị trí
      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        debugPrint(
          '⚠️ Chưa được cấp quyền GPS',
        );

        return null;
      }

      // Lấy vị trí hiện tại
      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      debugPrint(
        '📍 GPS nhận diện: '
        '${position.latitude}, '
        '${position.longitude}',
      );

      return position;
    } catch (e) {
      debugPrint(
        '❌ GPS Error: $e',
      );

      return null;
    }
  }

  // ============================================================
  // LƯU LỊCH SỬ NHẬN DIỆN
  // ============================================================

  Future<void> _saveDetectionHistory({
    required String signName,
    required String displayName,
    required double confidence,
  }) async {
    final now = DateTime.now();

    // ==========================================================
    // CHỐNG LƯU TRÙNG
    // ==========================================================

    if (_lastSavedSign == signName &&
        _lastSavedTime != null &&
        now.difference(_lastSavedTime!) <
            historyCooldown) {
      debugPrint(
        'Bỏ qua lưu trùng: $displayName',
      );

      return;
    }

    // ==========================================================
    // TẠO NỘI DUNG CẢNH BÁO
    // ==========================================================

    String warning = '';

    switch (signName) {
      case 'toc_do_toi_da_40':
        warning =
            'Cảnh báo: Khu vực giới hạn tốc độ 40 km/h';
        break;

      case 'toc_do_toi_da_50':
        warning =
            'Cảnh báo: Khu vực giới hạn tốc độ 50 km/h';
        break;

      case 'toc_do_toi_da_60':
        warning =
            'Cảnh báo: Khu vực giới hạn tốc độ 60 km/h';
        break;

      case 'toc_do_toi_da_80':
        warning =
            'Cảnh báo: Khu vực giới hạn tốc độ 80 km/h';
        break;

      case 'cam_do_xe':
        warning =
            'Cảnh báo: Khu vực cấm đỗ xe';
        break;

      case 'cam_dung_xe_va_do_xe':
        warning =
            'Cảnh báo: Khu vực cấm dừng và đỗ xe';
        break;

      case 'cam_o_to':
        warning =
            'Cảnh báo: Khu vực cấm ô tô';
        break;

      case 'cam_re_trai':
        warning =
            'Cảnh báo: Cấm rẽ trái';
        break;

      case 'cam_re_phai':
        warning =
            'Cảnh báo: Cấm rẽ phải';
        break;

      case 'cam_quay_dau_xe':
        warning =
            'Cảnh báo: Cấm quay đầu xe';
        break;

      case 'cam_vuot':
        warning =
            'Cảnh báo: Cấm vượt';
        break;

      case 'cam_xe_di_nguoc_chieu':
        warning =
            'Cảnh báo: Cấm xe đi ngược chiều';
        break;

      case 'di_cham':
        warning =
            'Cảnh báo: Vui lòng đi chậm';
        break;

      case 'cong_truong':
        warning =
            'Cảnh báo: Phía trước có công trường';
        break;

      case 'chu_y_tre_em':
        warning =
            'Cảnh báo: Chú ý trẻ em';
        break;

      case 'chu_y_nguoi_di_bo_cat_ngang':
        warning =
            'Cảnh báo: Chú ý người đi bộ';
        break;

      case 'chu_y_nguoi_di_xe_dap_cat_ngang':
        warning =
            'Cảnh báo: Chú ý người đi xe đạp';
        break;

      case 'cho_ngoat_nguy_hiem_ben_phai':
        warning =
            'Cảnh báo: Có chỗ ngoặt nguy hiểm bên phải';
        break;

      case 'cho_ngoat_nguy_hiem_ben_trai':
        warning =
            'Cảnh báo: Có chỗ ngoặt nguy hiểm bên trái';
        break;

      case 'cho_ngoat_nguy_hiem_lien_tiep':
        warning =
            'Cảnh báo: Có nhiều chỗ ngoặt nguy hiểm liên tiếp';
        break;

      case 'nguy_hiem_khac':
        warning =
            'Cảnh báo: Khu vực nguy hiểm';
        break;

      case 'duong_uu_tien':
        warning =
            'Thông báo: Bạn đang đi trên đường ưu tiên';
        break;

      case 'duong_het_uu_tien':
        warning =
            'Thông báo: Hết đường ưu tiên';
        break;

      case 'duong_mot_chieu':
        warning =
            'Cảnh báo: Đường một chiều';
        break;

      case 'duong_nguoi_di_bo_sang_ngang':
        warning =
            'Cảnh báo: Chú ý người đi bộ sang ngang';
        break;

      case 'duong_cho_nguoi_di_bo':
        warning =
            'Thông báo: Đường dành cho người đi bộ';
        break;

      case 'duong_cho_xe_o_to':
        warning =
            'Thông báo: Đường dành cho ô tô';
        break;

      default:
        warning =
            'Đã nhận diện biển báo giao thông';
    }

    // ==========================================================
    // LẤY GPS
    // ==========================================================

    final Position? position =
        await _getCurrentPosition();

    final double? latitude =
        position?.latitude;

    final double? longitude =
        position?.longitude;

    if (latitude != null &&
        longitude != null) {
      debugPrint(
        '📍 Lưu lịch sử tại: '
        '$latitude, $longitude',
      );
    } else {
      debugPrint(
        '⚠️ Không lấy được GPS, '
        'lịch sử sẽ lưu latitude/longitude = null',
      );
    }

    // ==========================================================
    // LƯU VÀO FIRESTORE
    // ==========================================================

    await _historyService.saveHistory(
      signName: signName,
      displayName: displayName,
      confidence: confidence,
      warning: warning,
      latitude: latitude,
      longitude: longitude,
    );

    // Chỉ cập nhật trạng thái sau khi lưu
    _lastSavedSign = signName;
    _lastSavedTime = now;

    debugPrint(
      '✅ Đã lưu lịch sử nhận diện: $displayName',
    );
  }

  // ============================================================
  // CHUYỂN TÊN CLASS YOLO SANG TIẾNG VIỆT
  // ============================================================

  String _convertSignName(String name) {
    switch (name) {
      // ==========================================
      // BIỂN GIỚI HẠN TỐC ĐỘ
      // ==========================================

      case 'toc_do_toi_da_40':
        return 'BIỂN GIỚI HẠN 40 KM/H';

      case 'toc_do_toi_da_50':
        return 'BIỂN GIỚI HẠN 50 KM/H';

      case 'toc_do_toi_da_60':
        return 'BIỂN GIỚI HẠN 60 KM/H';

      case 'toc_do_toi_da_80':
        return 'BIỂN GIỚI HẠN 80 KM/H';

      // ==========================================
      // BIỂN CẤM
      // ==========================================

      case 'cam_do_xe':
        return 'CẤM ĐỖ XE';

      case 'cam_dung_xe_va_do_xe':
        return 'CẤM DỪNG VÀ ĐỖ XE';

      case 'cam_o_to':
        return 'CẤM Ô TÔ';

      case 'cam_re_trai':
        return 'CẤM RẼ TRÁI';

      case 'cam_re_phai':
        return 'CẤM RẼ PHẢI';

      case 'cam_quay_dau_xe':
        return 'CẤM QUAY ĐẦU XE';

      case 'cam_vuot':
        return 'CẤM VƯỢT';

      case 'cam_xe_di_nguoc_chieu':
        return 'CẤM XE ĐI NGƯỢC CHIỀU';

      // ==========================================
      // BIỂN CẢNH BÁO
      // ==========================================

      case 'di_cham':
        return 'ĐI CHẬM';

      case 'cong_truong':
        return 'CÔNG TRƯỜNG';

      case 'chu_y_tre_em':
        return 'CHÚ Ý TRẺ EM';

      case 'chu_y_nguoi_di_bo_cat_ngang':
        return 'CHÚ Ý NGƯỜI ĐI BỘ';

      case 'chu_y_nguoi_di_xe_dap_cat_ngang':
        return 'CHÚ Ý NGƯỜI ĐI XE ĐẠP';

      case 'cho_ngoat_nguy_hiem_ben_phai':
        return 'CHỖ NGOẶT NGUY HIỂM BÊN PHẢI';

      case 'cho_ngoat_nguy_hiem_ben_trai':
        return 'CHỖ NGOẶT NGUY HIỂM BÊN TRÁI';

      case 'cho_ngoat_nguy_hiem_lien_tiep':
        return 'CHỖ NGOẶT NGUY HIỂM LIÊN TIẾP';

      case 'nguy_hiem_khac':
        return 'NGUY HIỂM KHÁC';

      // ==========================================
      // BIỂN CHỈ DẪN
      // ==========================================

      case 'duong_uu_tien':
        return 'ĐƯỜNG ƯU TIÊN';

      case 'duong_het_uu_tien':
        return 'HẾT ĐƯỜNG ƯU TIÊN';

      case 'duong_mot_chieu':
        return 'ĐƯỜNG MỘT CHIỀU';

      case 'duong_nguoi_di_bo_sang_ngang':
        return 'NGƯỜI ĐI BỘ SANG NGANG';

      case 'duong_cho_nguoi_di_bo':
        return 'ĐƯỜNG DÀNH CHO NGƯỜI ĐI BỘ';

      case 'duong_cho_xe_o_to':
        return 'ĐƯỜNG DÀNH CHO Ô TÔ';

      // ==========================================
      // KHÁC
      // ==========================================

      case 'khac':
        return 'Biển báo khác';

      default:
        return name;
    }
  }

  // ============================================================
  // DỪNG NHẬN DIỆN
  // ============================================================

  void _stopScanning() {
    _scanTimer?.cancel();

    _scanTimer = null;

    if (!mounted) return;

    setState(() {
      _isScanning = false;
      _status =
          'Đã tạm dừng nhận diện';
    });
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    debugPrint(
      'App lifecycle: $state',
    );

    if (state ==
            AppLifecycleState.inactive ||
        state ==
            AppLifecycleState.paused ||
        state ==
            AppLifecycleState.hidden) {
      _handleAppBackground();

      return;
    }

    if (state ==
        AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  // ============================================================
  // BACKGROUND
  // ============================================================

  Future<void> _handleAppBackground() async {
    if (_isDisposed) return;

    _wasScanningBeforeBackground =
        _isScanning;

    _scanTimer?.cancel();

    _scanTimer = null;

    if (mounted) {
      setState(() {
        _isScanning = false;

        _status =
            'Camera đang tạm dừng...';
      });
    }

    final controller = _controller;

    _controller = null;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint(
          'Camera dispose error: $e',
        );
      }
    }
  }

  // ============================================================
  // RESUME
  // ============================================================

  Future<void> _handleAppResumed() async {
    if (_isDisposed) return;

    debugPrint(
      'App resumed -> initialize camera again',
    );

    await _initializeCamera();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _isDisposed = true;

    _scanTimer?.cancel();

    _scanTimer = null;

    WidgetsBinding.instance
        .removeObserver(this);

    final controller = _controller;

    _controller = null;

    controller?.dispose();

    super.dispose();
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,

      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,

        title: const Text(
          'Nhận diện AI',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        centerTitle: true,
      ),

      body: _buildBody(),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody() {
    if (_isInitializing) {
      return const Center(
        child:
            CircularProgressIndicator(
          color: Colors.blueAccent,
        ),
      );
    }

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,

          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 70,
            ),

            const SizedBox(height: 20),

            Text(
              _status,

              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed:
                  _initializeCamera,

              child:
                  const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,

      children: [
        // =====================================================
        // CAMERA LIVE
        // =====================================================

        Center(
          child:
              CameraPreview(controller),
        ),

        // =====================================================
        // STATUS
        // =====================================================

        Positioned(
          top: 20,
          left: 16,
          right: 16,

          child:
              _buildStatus(),
        ),

        // =====================================================
        // KHUNG NHẬN DIỆN
        // =====================================================

        Positioned(
          left: 30,
          right: 30,
          top: 150,
          bottom: 190,

          child: Container(
            decoration:
                BoxDecoration(
              border: Border.all(
                color: _isScanning
                    ? Colors.greenAccent
                    : Colors.white54,

                width: 3,
              ),

              borderRadius:
                  BorderRadius.circular(20),
            ),
          ),
        ),

        // =====================================================
        // KẾT QUẢ
        // =====================================================

        Positioned(
          left: 16,
          right: 16,
          bottom: 100,

          child:
              _buildResult(),
        ),

        // =====================================================
        // BUTTON
        // =====================================================

        Positioned(
          bottom: 25,
          left: 30,
          right: 30,

          child:
              _buildScanButton(),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatus() {
    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),

      decoration:
          BoxDecoration(
        color:
            Colors.black.withValues(
          alpha: 0.65,
        ),

        borderRadius:
            BorderRadius.circular(30),
      ),

      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,

            decoration:
                BoxDecoration(
              color: _isScanning
                  ? Colors.greenAccent
                  : Colors.orangeAccent,

              shape: BoxShape.circle,
            ),
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _status,

              style:
                  const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // RESULT
  // ============================================================

  Widget _buildResult() {
    final bool isSpeedSign =
        _detectedSign.contains(
              '40 KM/H',
            ) ||
        _detectedSign.contains(
              '50 KM/H',
            ) ||
        _detectedSign.contains(
              '60 KM/H',
            ) ||
        _detectedSign.contains(
              '80 KM/H',
            );

    return Container(
      padding:
          const EdgeInsets.all(18),

      decoration:
          BoxDecoration(
        color:
            Colors.black.withValues(
          alpha: 0.78,
        ),

        borderRadius:
            BorderRadius.circular(18),
      ),

      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,

            decoration:
                BoxDecoration(
              color: isSpeedSign
                  ? Colors.red.withValues(
                      alpha: 0.25,
                    )
                  : Colors.orange
                      .withValues(
                      alpha: 0.2,
                    ),

              borderRadius:
                  BorderRadius.circular(14),
            ),

            child: Icon(
              isSpeedSign
                  ? Icons.speed
                  : Icons.warning_amber_rounded,

              color: isSpeedSign
                  ? Colors.redAccent
                  : Colors.orangeAccent,

              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,

              children: [
                Text(
                  _detectedSign,

                  style:
                      const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _confidence > 0
                      ? 'Độ tin cậy: '
                          '${(_confidence * 100).toStringAsFixed(1)}%'
                      : 'Đang chờ AI nhận diện...',

                  style:
                      const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // BUTTON
  // ============================================================

  Widget _buildScanButton() {
    return SizedBox(
      height: 55,

      child:
          ElevatedButton.icon(
        onPressed: _isScanning
            ? _stopScanning
            : _startScanning,

        icon: Icon(
          _isScanning
              ? Icons.stop_circle_outlined
              : Icons.play_circle_outline,
        ),

        label: Text(
          _isScanning
              ? 'DỪNG NHẬN DIỆN'
              : 'BẮT ĐẦU NHẬN DIỆN',
        ),

        style:
            ElevatedButton.styleFrom(
          backgroundColor: _isScanning
              ? Colors.redAccent
              : Colors.blueAccent,

          foregroundColor:
              Colors.white,

          shape:
              RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(16),
          ),

          textStyle:
              const TextStyle(
            fontWeight:
                FontWeight.bold,
          ),
        ),
      ),
    );
  }
}