import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:http/http.dart' as http;
import '../../models/location_context.dart';
import '../../models/danger_zone.dart';
import '../../services/heatmap_service.dart';
import '../theme.dart';

class RouteSafetyMapScreen extends StatefulWidget {
  const RouteSafetyMapScreen({super.key});

  @override
  State<RouteSafetyMapScreen> createState() => _RouteSafetyMapScreenState();
}

class _RouteSafetyMapScreenState extends State<RouteSafetyMapScreen>
    with TickerProviderStateMixin {
  final _mapController = MapController();
  final _destinationCtrl = TextEditingController();
  final _heatmap = HeatmapService();

  List<_ScoredRoute> _routes = [];
  List<DangerZone> _zones = [];
  bool _isLoading = false;
  String? _error;
  int _selectedIndex = 0;

  late AnimationController _panelCtrl;
  late Animation<double> _panelAnim;

  static const _startLat = 12.9352;
  static const _startLng = 77.6245;

  static const _quickDests = [
    _QuickDest('MG Road', 12.9756, 77.6029),
    _QuickDest('Indiranagar', 12.9784, 77.6408),
    _QuickDest('Koramangala', 12.9352, 77.6245),
    _QuickDest('Whitefield', 12.9698, 77.7500),
    _QuickDest('Electronic City', 12.8458, 77.6603),
  ];

  @override
  void initState() {
    super.initState();
    _heatmap.generateZonesForCurrentTime();
    _zones = _heatmap.getZones();

    _panelCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 300));
    _panelAnim = CurvedAnimation(parent: _panelCtrl, curve: Curves.easeOut);
    _panelCtrl.forward();
  }

  @override
  void dispose() {
    _destinationCtrl.dispose();
    _panelCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchRoutes(double endLat, double endLng) async {
    setState(() {
      _isLoading = true;
      _error = null;
      _routes = [];
    });

    try {
      final uri = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/foot-walking',
      ).replace(queryParameters: {
        'api_key': '5b3ce3597851110001cf6248e5b08c5d5ba040a0b1ed1e03b8c1b4b0',
        'start': '$_startLng,$_startLat',
        'end': '$endLng,$endLat',
        'alternative_routes': 'true',
      });

      final resp = await http.get(uri).timeout(const Duration(seconds: 15));

      if (resp.statusCode != 200) {
        throw Exception('Route API error ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body);
      final features = data['features'] as List? ?? [];

      if (features.isEmpty) throw Exception('No routes found');

      final scored = <_ScoredRoute>[];
      for (int i = 0; i < features.length; i++) {
        final feature = features[i];
        final geometry = feature['geometry'];
        final props = feature['properties'];
        final summary = props['summary'];

        final coords = (geometry['coordinates'] as List)
            .map((c) => LatLng(
                  (c[1] as num).toDouble(),
                  (c[0] as num).toDouble(),
                ))
            .toList();

        final distKm = ((summary['distance'] as num) / 1000.0);
        final durMin = ((summary['duration'] as num) / 60.0).round();
        final score = _scoreRoute(coords);

        scored.add(_ScoredRoute(
          id: 'Route ${i + 1}',
          path: coords,
          distanceKm: distKm,
          durationMin: durMin,
          safetyScore: score.score,
          reasons: score.reasons,
          dangerZoneCount: score.dangerZones,
        ));
      }

      scored.sort((a, b) => b.safetyScore.compareTo(a.safetyScore));
      for (int i = 0; i < scored.length; i++) {
        scored[i] = scored[i].copyWith(rank: i + 1);
      }

      setState(() {
        _routes = scored;
        _selectedIndex = 0;
        _isLoading = false;
      });

      // Fit map to route
      if (scored.isNotEmpty) {
        _fitMapToRoute(scored[0].path, endLat, endLng);
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  _RouteScore _scoreRoute(List<LatLng> path) {
    int totalRisk = 0;
    int pointsInZones = 0;
    final hitZones = <int>{};

    for (final point in path) {
      for (int z = 0; z < _zones.length; z++) {
        if (point.distanceTo(_zones[z].center) <= _zones[z].radius) {
          totalRisk += _zones[z].intensity;
          pointsInZones++;
          hitZones.add(z);
        }
      }
    }

    final dangerZoneCount = hitZones.length;
    final pct = path.isNotEmpty ? pointsInZones / path.length : 0;
    double score = 100.0 -
        (totalRisk / max(path.length, 1)) -
        (dangerZoneCount * 8);
    score = score.clamp(0, 100);

    final reasons = <String>[];
    if (score >= 80) reasons.add('Avoids danger zones');
    if (score >= 70) reasons.add('Well-lit path');
    if (dangerZoneCount == 0) reasons.add('No risk zones on route');
    if (dangerZoneCount > 0) {
      reasons.add(
          'Passes ${dangerZoneCount} risk zone${dangerZoneCount > 1 ? "s" : ""}');
    }
    if (pct > 0.2) reasons.add('${(pct * 100).round()}% in risk areas');
    if (score < 50) reasons.add('Consider alternative');

    return _RouteScore(
        score: score.round(),
        reasons: reasons,
        dangerZones: dangerZoneCount);
  }

  void _fitMapToRoute(List<LatLng> path, double endLat, double endLng) {
    if (path.isEmpty) return;

    double minLat = _startLat, maxLat = _startLat;
    double minLng = _startLng, maxLng = _startLng;

    for (final p in path) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    if (endLat < minLat) minLat = endLat;
    if (endLat > maxLat) maxLat = endLat;
    if (endLng < minLng) minLng = endLng;
    if (endLng > maxLng) maxLng = endLng;

    _mapController.move(
      ll.LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
      13.0,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          _buildMap(),
          SafeArea(child: _buildTopBar()),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomPanel(),
          ),
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: AppTheme.elevatedShadow,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircularProgressIndicator(
                          color: AppTheme.accent, strokeWidth: 2),
                      const SizedBox(height: 16),
                      const Text(
                        'Analyzing routes\nfor safety...',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 13,
                            height: 1.5),
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

  Widget _buildMap() {
    final selectedRoute =
        _routes.isNotEmpty ? _routes[_selectedIndex] : null;

    return FlutterMap(
      mapController: _mapController,
      options: const MapOptions(
        initialCenter: ll.LatLng(12.9550, 77.6000),
        initialZoom: 13.0,
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.shield.safety',
        ),

        // Danger zones
        CircleLayer(
          circles: _zones.map((z) {
            final color = z.intensity >= 70
                ? AppTheme.critical
                : z.intensity >= 40
                    ? AppTheme.high
                    : AppTheme.elevated;
            return CircleMarker(
              point: ll.LatLng(z.center.latitude, z.center.longitude),
              radius: z.radius,
              color: color.withOpacity(0.15),
              borderColor: color.withOpacity(0.5),
              borderStrokeWidth: 1.5,
            );
          }).toList(),
        ),

        // Dimmed non-selected routes
        PolylineLayer(
          polylines: [
            for (int i = 0; i < _routes.length; i++)
              if (i != _selectedIndex)
                Polyline(
                  points: _routes[i]
                      .path
                      .map((p) => ll.LatLng(p.latitude, p.longitude))
                      .toList(),
                  color: AppTheme.textMuted.withOpacity(0.4),
                  strokeWidth: 3,
                ),
          ],
        ),

        // Selected route
        if (selectedRoute != null)
          PolylineLayer(
            polylines: [
              Polyline(
                points: selectedRoute.path
                    .map((p) => ll.LatLng(p.latitude, p.longitude))
                    .toList(),
                color: _routeColor(selectedRoute.safetyScore),
                strokeWidth: 5,
                borderColor:
                    _routeColor(selectedRoute.safetyScore).withOpacity(0.3),
                borderStrokeWidth: 2,
              ),
            ],
          ),

        // Markers
        MarkerLayer(
          markers: [
            Marker(
              point: const ll.LatLng(_startLat, _startLng),
              width: 36,
              height: 36,
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.accent,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: [
                    BoxShadow(
                        color: AppTheme.accent.withOpacity(0.4),
                        blurRadius: 8)
                  ],
                ),
                child: const Icon(Icons.my_location,
                    color: Colors.white, size: 16),
              ),
            ),
            if (selectedRoute != null)
              Marker(
                point: ll.LatLng(
                  selectedRoute.path.last.latitude,
                  selectedRoute.path.last.longitude,
                ),
                width: 36,
                height: 36,
                child: Container(
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: AppTheme.primary.withOpacity(0.4),
                          blurRadius: 8)
                    ],
                  ),
                  child: const Icon(Icons.flag_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: const Icon(Icons.arrow_back_rounded,
                      color: AppTheme.primary, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.surface,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      const SizedBox(width: 16),
                      const Icon(Icons.search_rounded,
                          color: AppTheme.textMuted, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _destinationCtrl,
                          style: const TextStyle(
                              color: AppTheme.textPrimary, fontSize: 13),
                          decoration: const InputDecoration(
                            hintText: 'Where are you going?',
                            hintStyle: TextStyle(
                                color: AppTheme.textMuted, fontSize: 13),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onSubmitted: (_) => _searchDestination(),
                        ),
                      ),
                      if (_destinationCtrl.text.isNotEmpty)
                        GestureDetector(
                          onTap: () {
                            _destinationCtrl.clear();
                            setState(() {
                              _routes = [];
                              _error = null;
                            });
                          },
                          child: const Padding(
                            padding: EdgeInsets.only(right: 12),
                            child: Icon(Icons.close_rounded,
                                color: AppTheme.textMuted, size: 16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: _searchDestination,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: const Icon(Icons.route_rounded,
                      color: Colors.white, size: 20),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (_routes.isEmpty && !_isLoading)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _quickDests
                    .map((d) => _QuickDestChip(
                          dest: d,
                          onTap: () {
                            _destinationCtrl.text = d.name;
                            _fetchRoutes(d.lat, d.lng);
                          },
                        ))
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomPanel() {
    if (_error != null) {
      return Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.elevatedShadow,
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline,
                color: AppTheme.critical, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(_error!,
                  style: const TextStyle(
                      color: AppTheme.textSecondary, fontSize: 12)),
            ),
            TextButton(
              onPressed: () => setState(() => _error = null),
              child: const Text('Dismiss',
                  style: TextStyle(color: AppTheme.accent)),
            ),
          ],
        ),
      );
    }

    if (_routes.isEmpty) return const SizedBox.shrink();

    return AnimatedBuilder(
      animation: _panelAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, (1 - _panelAnim.value) * 200),
        child: child,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A1A1F6B),
              blurRadius: 32,
              offset: Offset(0, -8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Row(
                children: [
                  const Text(
                    'ROUTE OPTIONS',
                    style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 9,
                      letterSpacing: 3,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  Text('${_routes.length} routes found',
                      style: const TextStyle(
                          color: AppTheme.textMuted, fontSize: 10)),
                ],
              ),
            ),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.38,
              ),
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: _routes.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) => _RouteCard(
                  route: _routes[i],
                  isSelected: i == _selectedIndex,
                  onTap: () => setState(() => _selectedIndex = i),
                ),
              ),
            ),
            SizedBox(height: MediaQuery.of(context).padding.bottom),
          ],
        ),
      ),
    );
  }

  void _searchDestination() {
    final query = _destinationCtrl.text.toLowerCase().trim();
    if (query.isEmpty) return;

    for (final d in _quickDests) {
      if (d.name.toLowerCase().contains(query)) {
        _fetchRoutes(d.lat, d.lng);
        return;
      }
    }
    // Default fallback
    _fetchRoutes(12.9756, 77.6029);
  }

  Color _routeColor(int score) {
    if (score >= 75) return AppTheme.safe;
    if (score >= 50) return AppTheme.elevated;
    return AppTheme.critical;
  }
}

// ── Route card ─────────────────────────────────────────────────────────────
class _RouteCard extends StatelessWidget {
  final _ScoredRoute route;
  final bool isSelected;
  final VoidCallback onTap;

  const _RouteCard(
      {required this.route, required this.isSelected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = route.safetyScore >= 75
        ? AppTheme.safe
        : route.safetyScore >= 50
            ? AppTheme.elevated
            : AppTheme.critical;
    final isBest = route.rank == 1;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.06) : AppTheme.bgSecondary,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color.withOpacity(0.4) : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
                border:
                    Border.all(color: color.withOpacity(0.3), width: 1.5),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '${route.safetyScore}',
                    style: TextStyle(
                      color: color,
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      fontFamily: 'Roboto',
                      height: 1,
                    ),
                  ),
                  Text('SAFE',
                      style: TextStyle(
                          color: color.withOpacity(0.7),
                          fontSize: 6,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        isBest ? '★ Safest Route' : route.id,
                        style: TextStyle(
                          color: isBest ? color : AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (isBest) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text('RECOMMENDED',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 7,
                                  letterSpacing: 1,
                                  fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${route.distanceKm.toStringAsFixed(1)} km  ·  ${route.durationMin} min  ·  ${route.dangerZoneCount} risk zone${route.dangerZoneCount != 1 ? "s" : ""}',
                    style: const TextStyle(
                        color: AppTheme.textMuted, fontSize: 10),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: route.reasons.take(3).map((r) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppTheme.bgSecondary,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(r,
                            style: const TextStyle(
                                color: AppTheme.textSecondary, fontSize: 9)),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.check_rounded, color: color, size: 16),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickDestChip extends StatelessWidget {
  final _QuickDest dest;
  final VoidCallback onTap;

  const _QuickDestChip({required this.dest, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(20),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.place_rounded, color: AppTheme.accent, size: 13),
            const SizedBox(width: 4),
            Text(dest.name,
                style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

// ── Data models ─────────────────────────────────────────────────────────────
class _ScoredRoute {
  final String id;
  final List<LatLng> path;
  final double distanceKm;
  final int durationMin;
  final int safetyScore;
  final List<String> reasons;
  final int dangerZoneCount;
  final int rank;

  const _ScoredRoute({
    required this.id,
    required this.path,
    required this.distanceKm,
    required this.durationMin,
    required this.safetyScore,
    required this.reasons,
    required this.dangerZoneCount,
    this.rank = 0,
  });

  _ScoredRoute copyWith({int? rank}) => _ScoredRoute(
        id: id,
        path: path,
        distanceKm: distanceKm,
        durationMin: durationMin,
        safetyScore: safetyScore,
        reasons: reasons,
        dangerZoneCount: dangerZoneCount,
        rank: rank ?? this.rank,
      );
}

class _RouteScore {
  final int score;
  final List<String> reasons;
  final int dangerZones;
  const _RouteScore(
      {required this.score, required this.reasons, required this.dangerZones});
}

class _QuickDest {
  final String name;
  final double lat;
  final double lng;
  const _QuickDest(this.name, this.lat, this.lng);
}