import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import '../services/eonet_service.dart';
import '../services/open_meteo_service.dart';
import '../services/geocoding_service.dart';
import '../widgets/fire_risk_badge.dart';
import '../widgets/map_controls.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final MapController _mapController = MapController();
  LatLng? _myLatLng;
  LatLng _center = const LatLng(20, 78); // default India
  List<EonetEvent> _events = [];
  FireRisk? _risk;
  String? _error;
  bool _loading = true;
  bool _exploreGlobal = false;
  int _days = 7;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final pos = await _getPosition();
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _myLatLng = me;
        _center = me;
      });

      await _refreshData(center: me);
      _mapController.move(me, 6.5);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _refreshData({LatLng? center}) async {
    final c = center ?? _center;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final risk = await OpenMeteoService().getRisk(c.latitude, c.longitude);
      final bbox = _exploreGlobal ? null : EonetService.makeBBox(c, 8.0);
      final events = await EonetService().fetchWildfires(
        bbox: bbox,
        days: _days,
        limit: 500,
      );
      setState(() {
        _center = c;
        _risk = risk;
        _events = events;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<Position> _getPosition() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services are disabled.');
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied)
        throw Exception('Location permissions are denied.');
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    }
    return Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.medium,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFFFA54F), Color(0xFFEF4444)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        title: GestureDetector(
          onTap: _openSearch,
          child: Container(
            height: 42,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white24),
            ),
            child: Row(
              children: const [
                Icon(Icons.search, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text('Search a place (city, park, country)...'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          PopupMenuButton<int>(
            tooltip: 'Filters',
            itemBuilder: (context) => [
              PopupMenuItem(value: 3, child: Text('Show last 3 days')),
              PopupMenuItem(value: 7, child: Text('Show last 7 days')),
              PopupMenuItem(value: 14, child: Text('Show last 14 days')),
            ],
            onSelected: (v) async {
              setState(() => _days = v);
              await _refreshData(center: _center);
            },
            icon: const Icon(Icons.filter_alt_outlined),
          ),
          IconButton(
            tooltip: 'Safety Tips',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showTips(context),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? _ErrorView(message: _error!)
          : Stack(
              children: [
                _buildMap(theme),
                Positioned(
                  left: 12,
                  right: 12,
                  bottom: 16,
                  child: _risk == null
                      ? const SizedBox.shrink()
                      : _RiskCard(
                          risk: _risk!,
                          onRefresh: () async {
                            await _refreshData(center: _center);
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Risk updated')),
                              );
                            }
                          },
                        ),
                ),
                MapControls(
                  onLocate: () async {
                    try {
                      final pos = await Geolocator.getCurrentPosition();
                      final me = LatLng(pos.latitude, pos.longitude);
                      _mapController.move(me, 7.0);
                      await _refreshData(center: me);
                    } catch (_) {}
                  },
                  onZoomIn: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom + 1,
                    );
                  },
                  onZoomOut: () {
                    _mapController.move(
                      _mapController.camera.center,
                      _mapController.camera.zoom - 1,
                    );
                  },
                  exploreMode: _exploreGlobal,
                  onToggleExplore: (v) async {
                    setState(() => _exploreGlobal = v);
                    await _refreshData(center: _center);
                  },
                  onSearch: _openSearch,
                ),
              ],
            ),
    );
  }

  Widget _buildMap(ThemeData theme) {
    final markers = <Marker>[
      if (_myLatLng != null)
        Marker(
          point: _myLatLng!,
          width: 44,
          height: 44,
          child: const Icon(Icons.my_location, size: 30),
        ),
      ..._events.map(
        (e) => Marker(
          point: LatLng(e.lat, e.lon),
          width: 46,
          height: 46,
          child: Tooltip(
            message:
                '${e.title}\n${DateFormat('MMM d, HH:mm').format(e.date.toLocal())}',
            child: const Icon(Icons.local_fire_department, size: 32),
          ),
        ),
      ),
    ];

    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _center,
        initialZoom: 4,
        interactionOptions: const InteractionOptions(
          flags: ~InteractiveFlag.rotate,
        ),
      ),
      children: [
        TileLayer(
          urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
          subdomains: const ['a', 'b', 'c'],
          userAgentPackageName: 'wildfire_early_warning',
          retinaMode: true,
          // Required attribution
          // attributionBuilder: (_) => const Align(
          //   alignment: Alignment.bottomRight,
          //   child: Padding(
          //     padding: EdgeInsets.all(4.0),
          //     child: Text('© OpenStreetMap contributors'),
          //   ),
          // ),
        ),
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 60,
            spiderfyCircleRadius: 60,
            size: const Size(48, 48),
            zoomToBoundsOnClick: true,

            markers: markers,
            showPolygon: false,
            builder: (context, cluster) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.orange.shade400.withOpacity(0.9),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    cluster.length.toString(),

                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Future<void> _openSearch() async {
    final controller = TextEditingController();
    final svc = GeocodingService();
    List<GeocodingResult> results = [];
    await showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setM) {
            Future<void> run() async {
              final q = controller.text.trim();
              final r = await svc.search(q);
              setM(() => results = r);
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 12,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Search place',
                    style: Theme.of(ctx).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => run(),
                    decoration: InputDecoration(
                      hintText: 'City, park, country...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  if (results.isEmpty)
                    const Text('Type a query and press search.'),
                  if (results.isNotEmpty)
                    ...results.map(
                      (r) => ListTile(
                        leading: const Icon(Icons.place_outlined),
                        title: Text(r.displayName),
                        onTap: () async {
                          Navigator.of(ctx).pop();
                          final target = LatLng(r.lat, r.lon);
                          _mapController.move(target, 6.5);
                          await _refreshData(center: target);
                        },
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return const _TipsSheet();
      },
    );
  }
}

class _RiskCard extends StatelessWidget {
  final FireRisk risk;
  final Future<void> Function() onRefresh;
  const _RiskCard({required this.risk, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            FireRiskBadge(level: risk.level, score: risk.score),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    risk.label,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Now • ${risk.summary}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    risk.details,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(onPressed: onRefresh, icon: const Icon(Icons.refresh)),
          ],
        ),
      ),
    );
  }
}

class _TipsSheet extends StatelessWidget {
  const _TipsSheet();

  @override
  Widget build(BuildContext context) {
    final bullets = [
      'Prepare a “go bag”: water, masks (N95/FFP2), medications, important docs.',
      'Keep windows/vents closed during heavy smoke; use a HEPA filter if available.',
      'If you see fire nearby: call local emergency number; do not rely on apps alone.',
      'Know multiple evacuation routes; avoid roads with active fire markers.',
      'Clear dry brush and leaves around your home/farm perimeter.',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Wildfire Safety Tips',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            ...bullets.map(
              (b) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(child: Text(b)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Data sources: NASA EONET (events) & Open-Meteo (weather). Indicative risk only—follow official alerts.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
