import 'dart:async';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

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

  String _status = 'Đang khởi động camera...';

  Timer? _scanTimer;

  String _detectedSign = 'Chưa phát hiện biển báo';
  double _confidence = 0;

  bool _isDisposed = false;

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
      CameraDescription selectedCamera = cameras.first;

      for (final camera in cameras) {
        if (camera.lensDirection == CameraLensDirection.back) {
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

      // Dispose controller cũ nếu còn tồn tại
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

      // Nếu trước khi chuyển app đang nhận diện
      // thì tiếp tục nhận diện
      if (_wasScanningBeforeBackground && !_isScanning) {
        _startScanning();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');

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
      const Duration(milliseconds: 800),
      (_) {
        if (!_isScanning || _isDisposed) return;

        _scanFrame();
      },
    );
  }

  // ============================================================
  // QUÉT FRAME
  // ============================================================

  Future<void> _scanFrame() async {
    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized ||
        _isInitializing ||
        _isDisposed) {
      return;
    }

    try {
      /*
       * HIỆN TẠI:
       * Camera đang hoạt động và chu kỳ quét đang chạy.
       *
       * BƯỚC TIẾP THEO:
       *
       * Camera frame
       *       ↓
       * Image
       *       ↓
       * YOLOv8
       *       ↓
       * Detect biển báo
       *       ↓
       * Class + Confidence
       *       ↓
       * Hiển thị cảnh báo
       */

      if (!mounted || !_isScanning) return;

      setState(() {
        _status = 'AI đang quét...';
      });

      // ======================================================
      // CHƯA KẾT NỐI YOLO Ở BƯỚC NÀY
      // ======================================================

      // Sau này sẽ thay phần này bằng AI inference.
    } catch (e) {
      debugPrint('Scan error: $e');
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
      _status = 'Đã tạm dừng nhận diện';
    });
  }

  // ============================================================
  // XỬ LÝ KHI APP CHUYỂN TRẠNG THÁI
  // ============================================================

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    debugPrint('App lifecycle: $state');

    // --------------------------------------------------------
    // APP RỜI FOREGROUND
    // --------------------------------------------------------

    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _handleAppBackground();

      return;
    }

    // --------------------------------------------------------
    // APP QUAY LẠI FOREGROUND
    // --------------------------------------------------------

    if (state == AppLifecycleState.resumed) {
      _handleAppResumed();
    }
  }

  // ============================================================
  // APP CHẠY NỀN
  // ============================================================

  Future<void> _handleAppBackground() async {
    if (_isDisposed) return;

    // Ghi nhớ trạng thái nhận diện
    _wasScanningBeforeBackground = _isScanning;

    // Dừng timer
    _scanTimer?.cancel();
    _scanTimer = null;

    // Không để trạng thái scanning tiếp tục
    if (mounted) {
      setState(() {
        _isScanning = false;
        _status = 'Camera đang tạm dừng...';
      });
    }

    // Lấy controller hiện tại
    final controller = _controller;

    // QUAN TRỌNG:
    // Xóa reference trước khi dispose
    _controller = null;

    if (controller != null) {
      try {
        await controller.dispose();
      } catch (e) {
        debugPrint('Camera dispose error: $e');
      }
    }
  }

  // ============================================================
  // APP QUAY LẠI
  // ============================================================

  Future<void> _handleAppResumed() async {
    if (_isDisposed) return;

    debugPrint('App resumed -> initialize camera again');

    await _initializeCamera();
  }

  // ============================================================
  // DISPOSE TRANG
  // ============================================================

  @override
  void dispose() {
    _isDisposed = true;

    _scanTimer?.cancel();
    _scanTimer = null;

    WidgetsBinding.instance.removeObserver(this);

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
        child: CircularProgressIndicator(
          color: Colors.blueAccent,
        ),
      );
    }

    final controller = _controller;

    if (controller == null ||
        !controller.value.isInitialized) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.camera_alt_outlined,
              color: Colors.white,
              size: 70,
            ),

            const SizedBox(height: 20),

            Text(
              _status,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),

            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Thử lại'),
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
          child: CameraPreview(controller),
        ),

        // =====================================================
        // STATUS
        // =====================================================

        Positioned(
          top: 20,
          left: 16,
          right: 16,
          child: _buildStatus(),
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
            decoration: BoxDecoration(
              border: Border.all(
                color: _isScanning
                    ? Colors.greenAccent
                    : Colors.white54,
                width: 3,
              ),
              borderRadius: BorderRadius.circular(20),
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
          child: _buildResult(),
        ),

        // =====================================================
        // BUTTON
        // =====================================================

        Positioned(
          bottom: 25,
          left: 30,
          right: 30,
          child: _buildScanButton(),
        ),
      ],
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  Widget _buildStatus() {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.65),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        children: [
          Container(
            width: 11,
            height: 11,
            decoration: BoxDecoration(
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
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
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
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.orangeAccent,
              size: 30,
            ),
          ),

          const SizedBox(width: 14),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _detectedSign,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 5),

                Text(
                  _confidence > 0
                      ? 'Độ tin cậy: ${(_confidence * 100).toStringAsFixed(0)}%'
                      : 'Đang chờ AI nhận diện...',
                  style: const TextStyle(
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
  // BUTTON START / STOP
  // ============================================================

  Widget _buildScanButton() {
    return SizedBox(
      height: 55,
      child: ElevatedButton.icon(
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

        style: ElevatedButton.styleFrom(
          backgroundColor: _isScanning
              ? Colors.redAccent
              : Colors.blueAccent,

          foregroundColor: Colors.white,

          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),

          textStyle: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}