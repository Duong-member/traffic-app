import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../ai_camera_page.dart';
import 'account_page.dart';
import 'notification_page.dart';
import 'history_page.dart';
import 'favorite_page.dart';
import 'navigation_page.dart';
import 'navigation_search_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController mapController = MapController();

  Position? currentPosition;

  bool isLoadingLocation = false;

  String locationMessage = 'Chưa lấy vị trí';

  // ==========================================================
  // TỌA ĐỘ MẶC ĐỊNH
  // ==========================================================

  static const LatLng defaultLocation = LatLng(
    10.780371,
    106.661280,
  );

  // ==========================================================
  // LẤY GPS
  // ==========================================================

  Future<void> getCurrentLocation({
    bool moveMap = true,
  }) async {
    if (isLoadingLocation) return;

    setState(() {
      isLoadingLocation = true;
      locationMessage = 'Đang lấy vị trí...';
    });

    try {
      // Kiểm tra GPS
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        setState(() {
          isLoadingLocation = false;
          locationMessage = 'GPS đang tắt';
        });
        return;
      }

      // Kiểm tra quyền
      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        setState(() {
          isLoadingLocation = false;
          locationMessage =
              'Chưa được cấp quyền vị trí';
        });
        return;
      }

      // Lấy vị trí
      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      setState(() {
        currentPosition = position;
        isLoadingLocation = false;

        locationMessage =
            '${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}';
      });

      // Đưa bản đồ đến vị trí GPS
      if (moveMap) {
        mapController.move(
          LatLng(
            position.latitude,
            position.longitude,
          ),
          17,
        );
      }

      debugPrint(
        'GPS: ${position.latitude}, '
        '${position.longitude}',
      );
    } catch (e) {
      setState(() {
        isLoadingLocation = false;
        locationMessage =
            'Không lấy được vị trí';
      });

      debugPrint('GPS Error: $e');
    }
  }

  // ==========================================================
  // VỊ TRÍ HIỆN TẠI
  // ==========================================================

  LatLng get mapCenter {
    if (currentPosition != null) {
      return LatLng(
        currentPosition!.latitude,
        currentPosition!.longitude,
      );
    }

    return defaultLocation;
  }

  // ==========================================================
  // BUILD
  // ==========================================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF4F7FB),

      body: SafeArea(
        child: Column(
          children: [

            // ==================================================
            // TOP BAR
            // ==================================================

            Container(
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                14,
                18,
                12,
              ),
              color: Colors.white,

              child: Row(
                children: [

                  Container(
                    width: 44,
                    height: 44,

                    decoration:
                        BoxDecoration(
                      color:
                          const Color(
                        0xFFE8F1FF,
                      ),
                      borderRadius:
                          BorderRadius.circular(
                        14,
                      ),
                    ),

                    child: const Icon(
                      Icons.traffic,
                      color:
                          Color(0xFF1677FF),
                      size: 27,
                    ),
                  ),

                  const SizedBox(width: 12),

                  const Expanded(
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,

                      children: [

                        Text(
                          'Giao Thông',
                          style:
                              TextStyle(
                            fontSize: 20,
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        Text(
                          'Trợ lý lái xe thông minh',
                          style:
                              TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // ==================================================
                  // THÔNG BÁO
                  // ==================================================

                  IconButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const NotificationPage(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.notifications_none,
                    ),
                  ),

                  // ==================================================
                  // TÀI KHOẢN
                  // ==================================================

                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              const AccountPage(),
                        ),
                      );
                    },
                    child: const CircleAvatar(
                      radius: 20,
                      backgroundColor:
                          Color(0xFF1677FF),
                      child: Icon(
                        Icons.person,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ==================================================
            // MAIN
            // ==================================================

            Expanded(
              child:
                  SingleChildScrollView(
                child: Column(
                  children: [

                    // ==================================================
                    // SEARCH
                    // ==================================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .fromLTRB(
                        16,
                        16,
                        16,
                        10,
                      ),

                      child: Container(
                        height: 50,

                        padding:
                            const EdgeInsets
                                .symmetric(
                          horizontal: 16,
                        ),

                        decoration:
                            BoxDecoration(
                          color:
                              Colors.white,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            16,
                          ),
                        ),

                        child: const Row(
                          children: [

                            Icon(
                              Icons.search,
                              color:
                                  Colors.grey,
                            ),

                            SizedBox(width: 10),

                            Text(
                              'Bạn muốn đi đâu?',
                              style:
                                  TextStyle(
                                color:
                                    Colors.grey,
                                fontSize: 14,
                              ),
                            ),

                            Spacer(),

                            Icon(
                              Icons.mic_none,
                              color:
                                  Color(
                                0xFF1677FF,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // ==================================================
                    // BẢN ĐỒ
                    // ==================================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                      ),

                      child: Container(
                        height: 390,

                        decoration:
                            BoxDecoration(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            22,
                          ),

                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withOpacity(
                                0.08,
                              ),
                              blurRadius: 12,
                            ),
                          ],
                        ),

                        child: ClipRRect(
                          borderRadius:
                              BorderRadius
                                  .circular(
                            22,
                          ),

                          child:
                              FlutterMap(
                            mapController:
                                mapController,

                            options: MapOptions(
                              initialCenter: mapCenter,
                              initialZoom: 17,

                              // Không cho zoom quá xa
                              // để tránh bản đồ lặp nhiều thế giới
                              minZoom: 8,
                              maxZoom: 23,

                              interactionOptions:
                                  const InteractionOptions(
                                flags:
                                    InteractiveFlag.all,
                              ),
                            ),

                            children: [

                              // ==================================================
                              // OPENSTREETMAP
                              // ==================================================

                              TileLayer(
                                urlTemplate:
                                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',

                                userAgentPackageName:
                                    'com.giaothong.traffic_app',
                              ),

                              // ==================================================
                              // GPS MARKER
                              // ==================================================

                              if (currentPosition !=
                                  null)
                                MarkerLayer(
                                  markers: [

                                    Marker(
                                      point:
                                          LatLng(
                                        currentPosition!
                                            .latitude,
                                        currentPosition!
                                            .longitude,
                                      ),

                                      width: 50,
                                      height: 50,

                                      child:
                                          Container(
                                        decoration:
                                            BoxDecoration(
                                          color:
                                              const Color(
                                            0xFF1677FF,
                                          ),
                                          shape:
                                              BoxShape
                                                  .circle,
                                          border:
                                              Border.all(
                                            color:
                                                Colors.white,
                                            width: 5,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color:
                                                  const Color(
                                                0xFF1677FF,
                                              ).withOpacity(
                                                0.35,
                                              ),
                                              blurRadius:
                                                  20,
                                              spreadRadius:
                                                  8,
                                            ),
                                          ],
                                        ),

                                        child:
                                            const Icon(
                                          Icons
                                              .navigation,
                                          color:
                                              Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                              // ==================================================
                              // LOCATION LABEL
                              // ==================================================

                              Positioned(
                                left: 14,
                                top: 14,

                                child:
                                    Container(
                                  padding:
                                      const EdgeInsets
                                          .symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),

                                  decoration:
                                      BoxDecoration(
                                    color:
                                        Colors.white,
                                    borderRadius:
                                        BorderRadius
                                            .circular(
                                      12,
                                    ),
                                  ),

                                  child: Row(
                                    children: [

                                      const Icon(
                                        Icons
                                            .location_on,
                                        color:
                                            Color(
                                          0xFF1677FF,
                                        ),
                                        size: 18,
                                      ),

                                      const SizedBox(
                                        width: 5,
                                      ),

                                      Text(
                                        locationMessage,
                                        style:
                                            const TextStyle(
                                          fontSize: 11,
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                              // ==================================================
                              // GPS BUTTON
                              // ==================================================

                              Positioned(
                                right: 14,
                                bottom: 14,

                                child:
                                    FloatingActionButton(
                                  heroTag:
                                      'location',

                                  mini: true,

                                  backgroundColor:
                                      Colors.white,

                                  foregroundColor:
                                      const Color(
                                    0xFF1677FF,
                                  ),

                                  onPressed:
                                      () {
                                    getCurrentLocation(
                                      moveMap: true,
                                    );
                                  },

                                  child:
                                      isLoadingLocation
                                          ? const SizedBox(
                                              width:
                                                  18,
                                              height:
                                                  18,
                                              child:
                                                  CircularProgressIndicator(
                                                strokeWidth:
                                                    2,
                                              ),
                                            )
                                          : const Icon(
                                              Icons
                                                  .my_location,
                                            ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // CẢNH BÁO
                    // ==================================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                      ),

                      child: Container(
                        padding:
                            const EdgeInsets
                                .all(15),

                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFFFFF7E6,
                          ),

                          borderRadius:
                              BorderRadius
                                  .circular(
                            18,
                          ),

                          border:
                              Border.all(
                            color:
                                const Color(
                              0xFFFFC107,
                            ),
                          ),
                        ),

                        child: Row(
                          children: [

                            Container(
                              width: 46,
                              height: 46,

                              decoration:
                                  BoxDecoration(
                                color:
                                    const Color(
                                  0xFFFFC107,
                                ),
                                borderRadius:
                                    BorderRadius
                                        .circular(
                                  14,
                                ),
                              ),

                              child:
                                  const Icon(
                                Icons
                                    .warning_amber_rounded,
                                color:
                                    Colors.white,
                                size: 28,
                              ),
                            ),

                            const SizedBox(
                                width: 12),

                            const Expanded(
                              child:
                                  Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment
                                        .start,

                                children: [

                                  Text(
                                    'Cảnh báo giao thông',
                                    style:
                                        TextStyle(
                                      fontWeight:
                                          FontWeight
                                              .bold,
                                      fontSize: 15,
                                    ),
                                  ),

                                  SizedBox(
                                      height: 4),

                                  Text(
                                    'Phát hiện biển báo giới hạn tốc độ 40 km/h',
                                    style:
                                        TextStyle(
                                      fontSize: 12,
                                      color:
                                          Colors.black87,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const Icon(
                              Icons
                                  .chevron_right,
                              color:
                                  Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 14),

                    // ==================================================
                    // FEATURES
                    // ==================================================

                    Padding(
                      padding:
                          const EdgeInsets
                              .symmetric(
                        horizontal: 16,
                      ),

                      child: Row(
                        children: [

                          // ==================================================
                          // DẪN ĐƯỜNG
                          // ==================================================

                          Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      const NavigationSearchPage(),
                                ),
                              );
                            },
                            child: featureCard(
                              icon: Icons.route,
                              title: 'Dẫn đường',
                              subtitle: 'Tìm đường',
                            ),
                          ),
                        ),

                          const SizedBox(
                              width: 10),

                          // ==================================================
                          // ĐỊA ĐIỂM YÊU THÍCH
                          // ==================================================

                          Expanded(
                            child:
                                GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const FavoritePage(),
                                  ),
                                );
                              },
                              child:
                                  featureCard(
                                icon:
                                    Icons.star_rounded,
                                title:
                                    'Địa điểm',
                                subtitle:
                                    'Yêu thích',
                              ),
                            ),
                          ),

                          const SizedBox(
                              width: 10),

                          // ==================================================
                          // LỊCH SỬ
                          // ==================================================

                          Expanded(
                            child:
                                GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder:
                                        (context) =>
                                            const HistoryPage(),
                                  ),
                                );
                              },
                              child:
                                  featureCard(
                                icon:
                                    Icons.history,
                                title:
                                    'Lịch sử',
                                subtitle:
                                    'Cảnh báo',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                        height: 20),
                  ],
                ),
              ),
            ),

            // ==================================================
            // BOTTOM NAVIGATION
            // ==================================================

            Container(
              padding:
                  const EdgeInsets
                      .symmetric(
                horizontal: 8,
                vertical: 8,
              ),

              decoration:
                  const BoxDecoration(
                color: Colors.white,

                border: Border(
                  top: BorderSide(
                    color:
                        Color(0xFFE8E8E8),
                  ),
                ),
              ),

              child:
                  NavigationBar(
                onDestinationSelected:
                  (index) {

                  // Nhận diện AI
                  if (index == 1) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AiCameraPage(),
                      ),
                    );
                  }

                  // Cảnh báo
                  if (index == 2) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const HistoryPage(),
                      ),
                    );
                  }

                  // Tài khoản
                  if (index == 3) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            const AccountPage(),
                      ),
                    );
                  }
                },

                selectedIndex: 0,

                destinations: [

                  // ==================================================
                  // BẢN ĐỒ
                  // ==================================================

                  NavigationDestination(
                    icon: Icon(
                      Icons.map_outlined,
                    ),
                    selectedIcon:
                        Icon(Icons.map),
                    label: 'Bản đồ',
                  ),

                  // ==================================================
                  // NHẬN DIỆN
                  // ==================================================

                  NavigationDestination(
                    icon: Icon(
                      Icons
                          .camera_alt_outlined,
                    ),
                    selectedIcon:
                        Icon(
                      Icons.camera_alt,
                    ),
                    label: 'Nhận diện',
                  ),

                  // ==================================================
                  // CẢNH BÁO
                  // ==================================================

                  NavigationDestination(
                    icon: Icon(
                      Icons
                          .notifications_none,
                    ),
                    selectedIcon:
                        Icon(
                      Icons.notifications,
                    ),
                    label: 'Cảnh báo',
                  ),

                  // ==================================================
                  // TÀI KHOẢN
                  // ==================================================

                  NavigationDestination(
                    icon: Icon(
                      Icons.person_outline,
                    ),
                    selectedIcon:
                        Icon(Icons.person),
                    label: 'Tài khoản',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================
  // FEATURE CARD
  // ==========================================================

  Widget featureCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding:
          const EdgeInsets.all(12),

      decoration:
          BoxDecoration(
        color: Colors.white,
        borderRadius:
            BorderRadius.circular(16),
      ),

      child: Column(
        children: [

          Icon(
            icon,
            color:
                const Color(0xFF1677FF),
            size: 27,
          ),

          const SizedBox(height: 7),

          Text(
            title,
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.bold,
              fontSize: 12,
            ),
          ),

          const SizedBox(height: 2),

          Text(
            subtitle,
            style:
                const TextStyle(
              color: Colors.grey,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }
}