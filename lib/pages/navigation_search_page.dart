import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../models/favorite_model.dart';
import '../services/favorite_service.dart';
import 'navigation_page.dart';

class NavigationSearchPage extends StatefulWidget {
  const NavigationSearchPage({super.key});

  @override
  State<NavigationSearchPage> createState() =>
      _NavigationSearchPageState();
}

class _NavigationSearchPageState
    extends State<NavigationSearchPage> {
  final TextEditingController _searchController =
      TextEditingController();

  final FavoriteService _favoriteService =
      FavoriteService();

  Timer? _debounce;

  List<Map<String, dynamic>> _results = [];

  List<FavoriteModel> _favorites = [];

  bool _isSearching = false;
  bool _hasSearched = false;

  @override
  void initState() {
    super.initState();

    _loadFavorites();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD FAVORITES
  // ============================================================

  Future<void> _loadFavorites() async {
    final User? user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final List<FavoriteModel> favorites =
          await _favoriteService
              .getFavorites()
              .first;

      if (!mounted) return;

      setState(() {
        _favorites = favorites;
      });
    } catch (e) {
      debugPrint(
        'Không thể tải địa điểm yêu thích: $e',
      );
    }
  }

  // ============================================================
  // SEARCH WHILE TYPING
  // ============================================================

  void _onSearchChanged(String value) {
    _debounce?.cancel();

    final String query = value.trim();

    if (query.isEmpty) {
      setState(() {
        _results = [];
        _hasSearched = false;
        _isSearching = false;
      });

      return;
    }

    // Hiển thị Favorite ngay lập tức
    _showFavoriteSuggestions(query);

    // Chờ người dùng ngừng gõ một chút
    _debounce = Timer(
      const Duration(milliseconds: 900),
      () {
        if (query.length >= 3) {
          _searchPlaces(query);
        }
      },
    );
  }

  // ============================================================
  // FAVORITE SUGGESTIONS
  // ============================================================

  void _showFavoriteSuggestions(
    String query,
  ) {
    final String normalizedQuery =
        query.toLowerCase();

    final List<Map<String, dynamic>>
        favoriteResults = [];

    for (final FavoriteModel favorite
        in _favorites) {
      final String name =
          favorite.name.toLowerCase();

      final String address =
          favorite.address.toLowerCase();

      if (name.contains(normalizedQuery) ||
          address.contains(normalizedQuery)) {
        favoriteResults.add({
          'name': favorite.name,
          'display_name':
              favorite.address.isNotEmpty
                  ? favorite.address
                  : 'Địa điểm yêu thích',
          'lat': favorite.latitude.toString(),
          'lon': favorite.longitude.toString(),
          'type': 'favorite',
          'isFavorite': true,
        });
      }
    }

    setState(() {
      _results = favoriteResults;
      _hasSearched = true;
    });
  }

  // ============================================================
  // SEARCH OPENSTREETMAP
  // ============================================================

  Future<void> _searchPlaces(
    String query,
  ) async {
    if (!mounted) return;

    setState(() {
      _isSearching = true;
      _hasSearched = true;
    });

    try {
      final Uri url = Uri.https(
        'nominatim.openstreetmap.org',
        '/search',
        {
          'q': query,
          'format': 'jsonv2',
          'limit': '8',
          'countrycodes': 'vn',
          'accept-language': 'vi',
          'addressdetails': '1',
        },
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent':
              'GiaoThongThongMinh/1.0',
        },
      );

      if (response.statusCode != 200) {
        throw Exception(
          'HTTP ${response.statusCode}',
        );
      }

      final List<dynamic> data =
          jsonDecode(response.body);

      final List<Map<String, dynamic>>
          remoteResults = data
              .map(
                (item) => {
                  ...Map<String, dynamic>.from(
                    item,
                  ),
                  'isFavorite': false,
                },
              )
              .toList();

      // Favorite trước, OSM sau
      final List<Map<String, dynamic>>
          mergedResults = [
        ..._getMatchingFavorites(query),
        ...remoteResults,
      ];

      // Loại bỏ kết quả OSM bị trùng quá giống nhau
      final List<Map<String, dynamic>>
          uniqueResults = [];

      final Set<String> seen =
          <String>{};

      for (final result in mergedResults) {
        final String key =
            '${result['name']}_${result['lat']}_${result['lon']}';

        if (!seen.contains(key)) {
          seen.add(key);
          uniqueResults.add(result);
        }
      }

      if (!mounted) return;

      setState(() {
        _results = uniqueResults;
      });
    } catch (e) {
      debugPrint(
        'Lỗi tìm kiếm địa điểm: $e',
      );

      if (!mounted) return;

      // Nếu API lỗi vẫn giữ Favorite
      setState(() {
        _results =
            _getMatchingFavorites(query);
      });
    } finally {
      if (!mounted) return;

      setState(() {
        _isSearching = false;
      });
    }
  }

  List<Map<String, dynamic>>
      _getMatchingFavorites(
    String query,
  ) {
    final String normalizedQuery =
        query.toLowerCase();

    return _favorites
        .where(
          (favorite) {
            return favorite.name
                    .toLowerCase()
                    .contains(
                      normalizedQuery,
                    ) ||
                favorite.address
                    .toLowerCase()
                    .contains(
                      normalizedQuery,
                    );
          },
        )
        .map(
          (favorite) {
            return {
              'name': favorite.name,
              'display_name':
                  favorite.address,
              'lat':
                  favorite.latitude.toString(),
              'lon':
                  favorite.longitude.toString(),
              'type': 'favorite',
              'isFavorite': true,
            };
          },
        )
        .toList();
  }

  // ============================================================
  // SELECT PLACE
  // ============================================================

  void _selectPlace(
    Map<String, dynamic> place,
  ) {
    final double? latitude =
        double.tryParse(
      place['lat']?.toString() ?? '',
    );

    final double? longitude =
        double.tryParse(
      place['lon']?.toString() ?? '',
    );

    if (latitude == null ||
        longitude == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Không lấy được tọa độ địa điểm',
          ),
        ),
      );

      return;
    }

    final String name =
        place['name']?.toString().trim() ??
            '';

    final String displayName =
        name.isNotEmpty
            ? name
            : _getShortName(
                place['display_name']
                        ?.toString() ??
                    'Địa điểm',
              );

    final String address =
        place['display_name']
                ?.toString() ??
            '';

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            NavigationPage(
          destinationLatitude:
              latitude,
          destinationLongitude:
              longitude,
          destinationName:
              displayName,
          destinationAddress:
              address,
        ),
      ),
    );
  }

  String _getShortName(
    String displayName,
  ) {
    final List<String> parts =
        displayName.split(',');

    if (parts.isEmpty) {
      return displayName;
    }

    return parts.first.trim();
  }

  // ============================================================
  // ICON
  // ============================================================

  IconData _getPlaceIcon(
    Map<String, dynamic> place,
  ) {
    if (place['isFavorite'] == true) {
      return Icons.star;
    }

    final String type =
        place['type']?.toString() ?? '';

    switch (type) {
      case 'restaurant':
        return Icons.restaurant;

      case 'cafe':
        return Icons.local_cafe;

      case 'school':
      case 'university':
        return Icons.school;

      case 'hospital':
        return Icons.local_hospital;

      case 'hotel':
        return Icons.hotel;

      case 'shop':
      case 'supermarket':
        return Icons.store;

      case 'park':
        return Icons.park;

      case 'bank':
        return Icons.account_balance;

      case 'fuel':
        return Icons.local_gas_station;

      default:
        return Icons.location_on;
    }
  }

  String _getPlaceType(
    Map<String, dynamic> place,
  ) {
    if (place['isFavorite'] == true) {
      return '⭐ Địa điểm yêu thích';
    }

    final String type =
        place['type']?.toString() ?? '';

    switch (type) {
      case 'restaurant':
        return 'Nhà hàng';

      case 'cafe':
        return 'Quán cà phê';

      case 'school':
        return 'Trường học';

      case 'university':
        return 'Trường đại học';

      case 'hospital':
        return 'Bệnh viện';

      case 'hotel':
        return 'Khách sạn';

      case 'shop':
        return 'Cửa hàng';

      case 'supermarket':
        return 'Siêu thị';

      case 'park':
        return 'Công viên';

      case 'bank':
        return 'Ngân hàng';

      case 'fuel':
        return 'Trạm xăng';

      default:
        return 'Địa điểm trên bản đồ';
    }
  }

  // ============================================================
  // RESULT CARD
  // ============================================================

  Widget _buildResult(
    Map<String, dynamic> place,
  ) {
    final String name =
        place['name']?.toString().trim() ??
            '';

    final String displayName =
        name.isNotEmpty
            ? name
            : _getShortName(
                place['display_name']
                        ?.toString() ??
                    'Địa điểm',
              );

    final String address =
        place['display_name']
                ?.toString() ??
            '';

    final bool isFavorite =
        place['isFavorite'] == true;

    return Card(
      margin: const EdgeInsets.only(
        bottom: 10,
      ),
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius:
            BorderRadius.circular(16),
        side: BorderSide(
          color: Colors.grey.shade200,
        ),
      ),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(16),
        onTap: () {
          _selectPlace(place);
        },
        child: Padding(
          padding:
              const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration:
                    BoxDecoration(
                  color: isFavorite
                      ? const Color(
                          0xFFFFF4D6,
                        )
                      : const Color(
                          0xFFEAF2FF,
                        ),
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                ),
                child: Icon(
                  _getPlaceIcon(place),
                  color: isFavorite
                      ? Colors.orange
                      : const Color(
                          0xFF1677FF,
                        ),
                  size: 25,
                ),
              ),

              const SizedBox(width: 12),

              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      displayName,
                      maxLines: 2,
                      overflow:
                          TextOverflow.ellipsis,
                      style:
                          const TextStyle(
                        fontSize: 16,
                        fontWeight:
                            FontWeight.w700,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      _getPlaceType(place),
                      style: TextStyle(
                        fontSize: 12,
                        color:
                            isFavorite
                                ? Colors.orange
                                : Colors
                                    .blueGrey
                                    .shade500,
                        fontWeight:
                            FontWeight.w600,
                      ),
                    ),

                    const SizedBox(height: 5),

                    Text(
                      address.isNotEmpty
                          ? address
                          : 'Không có địa chỉ',
                      maxLines: 3,
                      overflow:
                          TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        color:
                            Colors.grey.shade700,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

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

  // ============================================================
  // UI
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      backgroundColor:
          const Color(0xFFF7F9FC),

      appBar: AppBar(
        backgroundColor:
            Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back,
          ),
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: const Text(
          'Dẫn đường',
          style: TextStyle(
            fontWeight:
                FontWeight.w700,
          ),
        ),
      ),

      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding:
                const EdgeInsets.fromLTRB(
              16,
              8,
              16,
              16,
            ),
            child: TextField(
              controller:
                  _searchController,
              autofocus: true,
              onChanged:
                  _onSearchChanged,
              textInputAction:
                  TextInputAction.search,
              onSubmitted: (_) {
                final String query =
                    _searchController.text
                        .trim();

                if (query.length >= 2) {
                  _searchPlaces(query);
                }
              },
              decoration:
                  InputDecoration(
                hintText:
                    'Bạn muốn đi đâu?',
                prefixIcon:
                    const Icon(
                  Icons.search,
                  color:
                      Color(0xFF1677FF),
                ),
                suffixIcon:
                    _searchController
                            .text
                            .isNotEmpty
                        ? IconButton(
                            icon:
                                const Icon(
                              Icons.clear,
                            ),
                            onPressed: () {
                              _searchController
                                  .clear();

                              setState(() {
                                _results = [];
                                _hasSearched =
                                    false;
                              });
                            },
                          )
                        : null,
                filled: true,
                fillColor:
                    const Color(
                  0xFFF1F4F8,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    16,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
              ),
            ),
          ),

          Expanded(
            child: _isSearching &&
                    _results.isEmpty
                ? const Center(
                    child:
                        CircularProgressIndicator(),
                  )
                : _results.isNotEmpty
                    ? ListView.builder(
                        padding:
                            const EdgeInsets.all(
                          16,
                        ),
                        itemCount:
                            _results.length,
                        itemBuilder:
                            (
                          context,
                          index,
                        ) {
                          return _buildResult(
                            _results[index],
                          );
                        },
                      )
                    : Center(
                        child: Padding(
                          padding:
                              const EdgeInsets.all(
                            30,
                          ),
                          child: Column(
                            mainAxisSize:
                                MainAxisSize.min,
                            children: [
                              Icon(
                                _hasSearched
                                    ? Icons
                                        .location_off
                                    : Icons
                                        .search,
                                size: 64,
                                color:
                                    Colors.grey
                                        .shade400,
                              ),
                              const SizedBox(
                                height: 16,
                              ),
                              Text(
                                _hasSearched
                                    ? 'Không tìm thấy địa điểm phù hợp'
                                    : 'Bắt đầu nhập tên địa điểm',
                                textAlign:
                                    TextAlign.center,
                                style:
                                    TextStyle(
                                  fontSize: 15,
                                  color:
                                      Colors.grey
                                          .shade600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}