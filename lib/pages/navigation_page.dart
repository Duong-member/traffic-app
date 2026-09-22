import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

class NavigationPage extends StatefulWidget {
  final double destinationLatitude;
  final double destinationLongitude;
  final String destinationName;
  final String destinationAddress;

  const NavigationPage({
    super.key,
    required this.destinationLatitude,
    required this.destinationLongitude,
    required this.destinationName,
    this.destinationAddress = '',
  });

  @override
  State<NavigationPage> createState() =>
      _NavigationPageState();
}

class _NavigationPageState
    extends State<NavigationPage> {
  final MapController _mapController =
      MapController();

  StreamSubscription<Position>?
      _positionSubscription;

  Position? _currentPosition;

  List<LatLng> _routePoints = [];

  List<Map<String, dynamic>> _steps = [];

  bool _isLoading = true;
  bool _isNavigating = false;
  bool _hasArrived = false;

  double _distanceMeters = 0;
  double _durationSeconds = 0;

  int _currentStepIndex = 0;

  String _instruction =
      'Bắt đầu di chuyển';

  String _instructionDetail = '';

  IconData _instructionIcon =
      Icons.navigation;

  @override
  void initState() {
    super.initState();

    _initialize();
  }

  @override
  void dispose() {
    _positionSubscription?.cancel();

    super.dispose();
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    final bool locationReady =
        await _checkLocationPermission();

    if (!locationReady) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }

      return;
    }

    try {
      final Position position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _currentPosition =
            position;
      });

      await _loadRoute(position);
    } catch (e) {
      debugPrint(
        'Lỗi lấy vị trí: $e',
      );

      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // ============================================================
  // LOCATION PERMISSION
  // ============================================================

  Future<bool> _checkLocationPermission()
      async {
    bool serviceEnabled =
        await Geolocator
            .isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (mounted) {
        _showMessage(
          'Vui lòng bật GPS trên thiết bị',
        );
      }

      return false;
    }

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
      if (mounted) {
        _showMessage(
          'Ứng dụng cần quyền vị trí để dẫn đường',
        );
      }

      return false;
    }

    return true;
  }

  // ============================================================
  // LOAD ROUTE
  // ============================================================

  Future<void> _loadRoute(
    Position position,
  ) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final double startLatitude =
          position.latitude;

      final double startLongitude =
          position.longitude;

      final double endLatitude =
          widget.destinationLatitude;

      final double endLongitude =
          widget.destinationLongitude;

      final String url =
          'https://router.project-osrm.org/'
          'route/v1/driving/'
          '$startLongitude,$startLatitude;'
          '$endLongitude,$endLatitude'
          '?overview=full'
          '&geometries=geojson'
          '&steps=true';

      final response =
          await http.get(
        Uri.parse(url),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'OSRM HTTP ${response.statusCode}',
        );
      }

      final Map<String, dynamic> data =
          jsonDecode(response.body);

      if (data['code'] != 'Ok') {
        throw Exception(
          data['code']?.toString() ??
              'Không tìm được tuyến đường',
        );
      }

      final Map<String, dynamic> route =
          data['routes'][0];

      final List<dynamic> coordinates =
          route['geometry']['coordinates'];

      final List<LatLng> points =
          coordinates.map(
        (coordinate) {
          return LatLng(
            (coordinate[1] as num)
                .toDouble(),
            (coordinate[0] as num)
                .toDouble(),
          );
        },
      ).toList();

      final List<dynamic> legs =
          route['legs'] ?? [];

      final List<Map<String, dynamic>>
          steps = [];

      if (legs.isNotEmpty) {
        final List<dynamic> rawSteps =
            legs[0]['steps'] ?? [];

        for (final rawStep
            in rawSteps) {
          final Map<String, dynamic>
              step =
              Map<String, dynamic>.from(
            rawStep,
          );

          steps.add(step);
        }
      }

      if (!mounted) return;

      setState(() {
        _routePoints = points;

        _steps = steps;

        _distanceMeters =
            (route['distance'] as num)
                .toDouble();

        _durationSeconds =
            (route['duration'] as num)
                .toDouble();

        _isLoading = false;

        _currentStepIndex = 0;

        _updateInstruction(
          position,
        );
      });

      WidgetsBinding.instance
          .addPostFrameCallback(
        (_) {
          _fitRoute();
        },
      );
    } catch (e) {
      debugPrint(
        'Lỗi lấy route: $e',
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      _showMessage(
        'Không thể tìm tuyến đường',
      );
    }
  }

  // ============================================================
  // START NAVIGATION
  // ============================================================

  Future<void> _startNavigation()
      async {
    if (_isNavigating) return;

    final bool ready =
        await _checkLocationPermission();

    if (!ready) return;

    setState(() {
      _isNavigating = true;
      _hasArrived = false;
    });

    const LocationSettings settings =
        LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 5,
    );

    _positionSubscription =
        Geolocator.getPositionStream(
      locationSettings: settings,
    ).listen(
      (Position position) {
        _handlePositionUpdate(
          position,
        );
      },
      onError: (error) {
        debugPrint(
          'GPS stream error: $error',
        );
      },
    );

    if (_currentPosition != null) {
      _handlePositionUpdate(
        _currentPosition!,
      );
    }

    _showMessage(
      '🚗 Đã bắt đầu dẫn đường',
    );
  }

  // ============================================================
  // STOP NAVIGATION
  // ============================================================

  Future<void> _stopNavigation()
      async {
    await _positionSubscription
        ?.cancel();

    _positionSubscription = null;

    if (!mounted) return;

    setState(() {
      _isNavigating = false;
    });

    _showMessage(
      'Đã tạm dừng dẫn đường',
    );
  }

  // ============================================================
  // GPS UPDATE
  // ============================================================

  void _handlePositionUpdate(
    Position position,
  ) {
    if (!mounted) return;

    setState(() {
      _currentPosition =
          position;
    });

    _updateInstruction(
      position,
    );

    if (_isNavigating) {
      _mapController.move(
        LatLng(
          position.latitude,
          position.longitude,
        ),
        17,
      );
    }

    final double distanceToDestination =
        Geolocator.distanceBetween(
      position.latitude,
      position.longitude,
      widget.destinationLatitude,
      widget.destinationLongitude,
    );

    if (distanceToDestination <= 30 &&
        !_hasArrived) {
      _hasArrived = true;

      _showMessage(
        '⭐ Bạn đã đến nơi!',
      );

      if (mounted) {
        setState(() {
          _instruction =
              'Bạn đã đến nơi';
          _instructionDetail =
              widget.destinationName;
          _instructionIcon =
              Icons.location_on;
        });
      }
    }
  }

  // ============================================================
  // UPDATE INSTRUCTION
  // ============================================================

  void _updateInstruction(
    Position position,
  ) {
    if (_steps.isEmpty) {
      setState(() {
        _instruction =
            'Bắt đầu di chuyển';

        _instructionDetail =
            widget.destinationName;

        _instructionIcon =
            Icons.navigation;
      });

      return;
    }

    int bestIndex =
        _currentStepIndex;

    double bestDistance =
        double.infinity;

    for (
      int i = _currentStepIndex;
      i < _steps.length;
      i++
    ) {
      final Map<String, dynamic>
          step = _steps[i];

      final Map<String, dynamic>
          maneuver =
          Map<String, dynamic>.from(
        step['maneuver'] ?? {},
      );

      final List<dynamic>? location =
          maneuver['location']
              as List<dynamic>?;

      if (location == null ||
          location.length < 2) {
        continue;
      }

      final double longitude =
          (location[0] as num)
              .toDouble();

      final double latitude =
          (location[1] as num)
              .toDouble();

      final double distance =
          Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        latitude,
        longitude,
      );

      if (distance < bestDistance) {
        bestDistance = distance;
        bestIndex = i;
      }
    }

    _currentStepIndex =
        bestIndex;

    final Map<String, dynamic>
        currentStep =
        _steps[_currentStepIndex];

    final Map<String, dynamic>
        maneuver =
        Map<String, dynamic>.from(
      currentStep['maneuver'] ?? {},
    );

    final String type =
        maneuver['type']?.toString() ??
            '';

    final String modifier =
        maneuver['modifier']?.toString() ??
            '';

    final String roadName =
        currentStep['name']
                ?.toString()
                .trim() ??
            '';

    final double stepDistance =
        (currentStep['distance'] as num?)
                ?.toDouble() ??
            0;

    String instruction =
        'Đi thẳng';

    IconData icon =
        Icons.arrow_upward;

    if (type == 'depart') {
      instruction =
          'Bắt đầu di chuyển';
      icon = Icons.navigation;
    } else if (type == 'arrive') {
      instruction =
          'Bạn đã đến nơi';
      icon = Icons.location_on;
    } else if (type == 'turn') {
      if (modifier.contains('left')) {
        instruction =
            'Rẽ trái';
        icon = Icons.turn_left;
      } else if (modifier.contains(
        'right',
      )) {
        instruction =
            'Rẽ phải';
        icon = Icons.turn_right;
      } else if (modifier.contains(
        'uturn',
      )) {
        instruction =
            'Quay đầu';
        icon = Icons.u_turn_left;
      }
    } else if (type == 'roundabout' ||
        type == 'rotary') {
      instruction =
          'Đi vào vòng xoay';
      icon = Icons.roundabout_left;
    } else if (type == 'merge') {
      instruction =
          'Nhập vào làn đường';
      icon = Icons.merge;
    } else if (type == 'new name') {
      instruction =
          'Đi thẳng';
      icon = Icons.arrow_upward;
    }

    String detail = '';

    if (stepDistance >= 1000) {
      detail =
          '${(stepDistance / 1000).toStringAsFixed(1)} km';

    } else {
      detail =
          '${stepDistance.round()} m';
    }

    if (roadName.isNotEmpty) {
      detail =
          '$detail • $roadName';
    }

    if (mounted) {
      setState(() {
        _instruction =
            instruction;

        _instructionDetail =
            detail;

        _instructionIcon =
            icon;
      });
    }
  }

  // ============================================================
  // FIT ROUTE
  // ============================================================

  void _fitRoute() {
    if (_routePoints.isEmpty) {
      return;
    }

    final List<LatLng> points = [
      ..._routePoints,
    ];

    if (_currentPosition != null) {
      points.add(
        LatLng(
          _currentPosition!
              .latitude,
          _currentPosition!
              .longitude,
        ),
      );
    }

    final LatLngBounds bounds =
        LatLngBounds.fromPoints(
      points,
    );

    _mapController.fitCamera(
      CameraFit.bounds(
        bounds: bounds,
        padding:
            const EdgeInsets.all(60),
      ),
    );
  }

  // ============================================================
  // CENTER GPS
  // ============================================================

  void _centerOnGPS() {
    if (_currentPosition == null) {
      return;
    }

    _mapController.move(
      LatLng(
        _currentPosition!
            .latitude,
        _currentPosition!
            .longitude,
      ),
      17,
    );
  }

  // ============================================================
  // FORMAT
  // ============================================================

  String _formatDistance(
    double meters,
  ) {
    if (meters >= 1000) {
      return '${(meters / 1000).toStringAsFixed(1)} km';
    }

    return '${meters.round()} m';
  }

  String _formatDuration(
    double seconds,
  ) {
    final int minutes =
        (seconds / 60).round();

    if (minutes < 60) {
      return '$minutes phút';
    }

    final int hours =
        minutes ~/ 60;

    final int remaining =
        minutes % 60;

    return '${hours} giờ ${remaining} phút';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(
    String message,
  ) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          duration:
              const Duration(
            seconds: 2,
          ),
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final LatLng destination =
        LatLng(
      widget.destinationLatitude,
      widget.destinationLongitude,
    );

    final LatLng initialCenter =
        _currentPosition != null
            ? LatLng(
                _currentPosition!
                    .latitude,
                _currentPosition!
                    .longitude,
              )
            : destination;

    return Scaffold(
      backgroundColor:
          Colors.white,

      appBar: AppBar(
        title: const Text(
          '🗺️ Dẫn đường',
        ),
        centerTitle: true,
        backgroundColor:
            Colors.white,
        elevation: 0,
      ),

      body: Stack(
        children: [
          FlutterMap(
            mapController:
                _mapController,
            options:
                MapOptions(
              initialCenter:
                  initialCenter,
              initialZoom: 15,
              minZoom: 8,
              maxZoom: 23,
            ),
            children: [
              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.giaothong.traffic_app',
              ),

              if (_routePoints
                  .isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points:
                          _routePoints,
                      strokeWidth: 5,
                      color:
                          const Color(
                        0xFF1677FF,
                      ),
                    ),
                  ],
                ),

              MarkerLayer(
                markers: [
                  if (_currentPosition !=
                      null)
                    Marker(
                      point: LatLng(
                        _currentPosition!
                            .latitude,
                        _currentPosition!
                            .longitude,
                      ),
                      width: 54,
                      height: 54,
                      child:
                          Container(
                        decoration:
                            BoxDecoration(
                          color:
                              const Color(
                            0xFF1677FF,
                          ),
                          shape:
                              BoxShape.circle,
                          border:
                              Border.all(
                            color:
                                Colors.white,
                            width: 4,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors
                                  .black
                                  .withOpacity(
                                0.2,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child:
                            const Icon(
                          Icons.navigation,
                          color:
                              Colors.white,
                          size: 28,
                        ),
                      ),
                    ),

                  Marker(
                    point:
                        destination,
                    width: 58,
                    height: 58,
                    child:
                        Container(
                      decoration:
                          BoxDecoration(
                        color:
                            Colors.red,
                        shape:
                            BoxShape.circle,
                        border:
                            Border.all(
                          color:
                              Colors.white,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors
                                .black
                                .withOpacity(
                              0.2,
                            ),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child:
                          const Icon(
                        Icons.star,
                        color:
                            Colors.white,
                        size: 30,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ====================================================
          // TOP INSTRUCTION
          // ====================================================

          Positioned(
            top: 12,
            left: 14,
            right: 14,
            child: Card(
              elevation: 4,
              shape:
                  RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(
                  18,
                ),
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  14,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration:
                          BoxDecoration(
                        color:
                            const Color(
                          0xFFEAF2FF,
                        ),
                        borderRadius:
                            BorderRadius
                                .circular(
                          14,
                        ),
                      ),
                      child:
                          Icon(
                        _instructionIcon,
                        color:
                            const Color(
                          0xFF1677FF,
                        ),
                        size: 27,
                      ),
                    ),

                    const SizedBox(
                      width: 12,
                    ),

                    Expanded(
                      child:
                          Column(
                        crossAxisAlignment:
                            CrossAxisAlignment
                                .start,
                        children: [
                          Text(
                            _instruction,
                            style:
                                const TextStyle(
                              fontSize: 17,
                              fontWeight:
                                  FontWeight
                                      .w700,
                            ),
                          ),

                          const SizedBox(
                            height: 4,
                          ),

                          Text(
                            _instructionDetail
                                    .isNotEmpty
                                ? _instructionDetail
                                : widget
                                    .destinationName,
                            maxLines: 2,
                            overflow:
                                TextOverflow
                                    .ellipsis,
                            style:
                                TextStyle(
                              fontSize: 13,
                              color: Colors
                                  .grey
                                  .shade600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ====================================================
          // GPS BUTTON
          // ====================================================

          Positioned(
            right: 16,
            bottom: 175,
            child: FloatingActionButton(
              heroTag:
                  'gpsButton',
              backgroundColor:
                  Colors.white,
              foregroundColor:
                  const Color(
                0xFF1677FF,
              ),
              onPressed:
                  _centerOnGPS,
              child: const Icon(
                Icons.my_location,
              ),
            ),
          ),

          // ====================================================
          // BOTTOM PANEL
          // ====================================================

          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              decoration:
                  const BoxDecoration(
                color: Colors.white,
                borderRadius:
                    BorderRadius.vertical(
                  top: Radius.circular(
                    24,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color:
                        Colors.black26,
                    blurRadius: 15,
                    offset:
                        Offset(0, -4),
                  ),
                ],
              ),
              padding:
                  const EdgeInsets.fromLTRB(
                18,
                18,
                18,
                20,
              ),
              child:
                  SafeArea(
                top: false,
                child:
                    Column(
                  mainAxisSize:
                      MainAxisSize.min,
                  children: [
                    Text(
                      widget.destinationName,
                      maxLines: 1,
                      overflow:
                          TextOverflow
                              .ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 18,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    if (widget
                        .destinationAddress
                        .isNotEmpty)
                      Padding(
                        padding:
                            const EdgeInsets
                                .only(
                          top: 4,
                        ),
                        child:
                            Text(
                          widget
                              .destinationAddress,
                          maxLines: 2,
                          overflow:
                              TextOverflow
                                  .ellipsis,
                          textAlign:
                              TextAlign
                                  .center,
                          style:
                              TextStyle(
                            fontSize:
                                12,
                            color: Colors
                                .grey
                                .shade600,
                          ),
                        ),
                      ),

                    const SizedBox(
                      height: 14,
                    ),

                    Row(
                      children: [
                        Expanded(
                          child:
                              Column(
                            children: [
                              const Icon(
                                Icons
                                    .directions_car,
                                color:
                                    Color(
                                  0xFF1677FF,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                _formatDistance(
                                  _distanceMeters,
                                ),
                                style:
                                    const TextStyle(
                                  fontSize:
                                      16,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                              Text(
                                'Khoảng cách',
                                style:
                                    TextStyle(
                                  fontSize:
                                      11,
                                  color: Colors
                                      .grey
                                      .shade500,
                                ),
                              ),
                            ],
                          ),
                        ),

                        Container(
                          width: 1,
                          height: 48,
                          color:
                              Colors.grey
                                  .shade300,
                        ),

                        Expanded(
                          child:
                              Column(
                            children: [
                              const Icon(
                                Icons
                                    .access_time,
                                color:
                                    Color(
                                  0xFF1677FF,
                                ),
                              ),
                              const SizedBox(
                                height: 4,
                              ),
                              Text(
                                _formatDuration(
                                  _durationSeconds,
                                ),
                                style:
                                    const TextStyle(
                                  fontSize:
                                      16,
                                  fontWeight:
                                      FontWeight
                                          .w700,
                                ),
                              ),
                              Text(
                                'Thời gian ước tính',
                                style:
                                    TextStyle(
                                  fontSize:
                                      11,
                                  color: Colors
                                      .grey
                                      .shade500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(
                      height: 16,
                    ),

                    SizedBox(
                      width:
                          double.infinity,
                      height: 52,
                      child:
                          ElevatedButton.icon(
                        onPressed:
                            _isLoading
                                ? null
                                : _isNavigating
                                    ? _stopNavigation
                                    : _startNavigation,
                        icon: Icon(
                          _isNavigating
                              ? Icons
                                  .pause
                              : Icons
                                  .navigation,
                        ),
                        label: Text(
                          _isNavigating
                              ? 'TẠM DỪNG DẪN ĐƯỜNG'
                              : 'BẮT ĐẦU DẪN ĐƯỜNG',
                          style:
                              const TextStyle(
                            fontSize:
                                15,
                            fontWeight:
                                FontWeight
                                    .w700,
                          ),
                        ),
                        style:
                            ElevatedButton
                                .styleFrom(
                          backgroundColor:
                              _isNavigating
                                  ? Colors
                                      .orange
                                  : const Color(
                                      0xFF1677FF,
                                    ),
                          foregroundColor:
                              Colors.white,
                          shape:
                              RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius
                                    .circular(
                              16,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          if (_isLoading)
            Container(
              color: Colors.white
                  .withOpacity(
                0.7,
              ),
              child:
                  const Center(
                child:
                    CircularProgressIndicator(),
              ),
            ),
        ],
      ),
    );
  }
}