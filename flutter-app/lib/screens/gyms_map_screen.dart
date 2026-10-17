import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart';
import '../l10n/tr.dart';

const _kBg     = Color(0xFF090A0F);
const _kCard   = Color(0xFF14161F);
const _kBorder = Color(0xFF2B2E3D);
const _kText   = Color(0xFFF5F5FA);
const _kGray   = Color(0xFFA7ABBE);
const _kAccent = Color(0xFF9A9DFF);

class GymsMapScreen extends StatefulWidget {
  const GymsMapScreen({
    super.key,
    required this.gyms,
    this.userLat,
    this.userLng,
    this.onOpenGym,
  });

  final List<Map<String, dynamic>> gyms;
  final double? userLat;
  final double? userLng;
  final void Function(Map<String, dynamic>)? onOpenGym;

  @override
  State<GymsMapScreen> createState() => _GymsMapScreenState();
}

class _GymsMapScreenState extends State<GymsMapScreen> {
  Map<String, dynamic>? _selected;
  late final MapController _mapCtrl;

  @override
  void initState() {
    super.initState();
    _mapCtrl = MapController();
  }

  @override
  void dispose() {
    _mapCtrl.dispose();
    super.dispose();
  }

  double? _coord(dynamic raw) {
    if (raw is num) return raw.toDouble();
    if (raw is String) return double.tryParse(raw);
    return null;
  }

  List<Map<String, dynamic>> get _mappable => widget.gyms.where((g) {
    return _coord(g['latitude']) != null && _coord(g['longitude']) != null;
  }).toList();

  LatLng get _center {
    if (widget.userLat != null && widget.userLng != null) {
      return LatLng(widget.userLat!, widget.userLng!);
    }
    if (_mappable.isNotEmpty) {
      return LatLng(
        _coord(_mappable.first['latitude'])!,
        _coord(_mappable.first['longitude'])!,
      );
    }
    return const LatLng(37.983, 23.727); // Athens default
  }

  @override
  Widget build(BuildContext context) {
    final pins = _mappable;

    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Map
          FlutterMap(
            mapController: _mapCtrl,
            options: MapOptions(
              initialCenter: _center,
              initialZoom: 14,
              onTap: (_, __) => setState(() => _selected = null),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.omniplex.app',
              ),
              MarkerLayer(
                markers: [
                  if (widget.userLat != null && widget.userLng != null)
                    Marker(
                      point: LatLng(widget.userLat!, widget.userLng!),
                      width: 20, height: 20,
                      child: Container(
                        decoration: BoxDecoration(
                          color: _kAccent,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 2),
                          boxShadow: [BoxShadow(
                            color: _kAccent.withValues(alpha: 0.4), blurRadius: 8)],
                        ),
                      ),
                    ),
                  for (final gym in pins)
                    Marker(
                      point: LatLng(
                        _coord(gym['latitude'])!, _coord(gym['longitude'])!),
                      width: 42, height: 42,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selected = gym);
                          _mapCtrl.move(
                            LatLng(_coord(gym['latitude'])!, _coord(gym['longitude'])!),
                            15,
                          );
                        },
                        child: _GymPin(
                          selected: _selected == gym,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),

          // Top bar
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 42, height: 42,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
                      ),
                      child: const Icon(Icons.arrow_back_rounded, color: _kText, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                        boxShadow: [BoxShadow(
                          color: Colors.black.withValues(alpha: 0.4), blurRadius: 8)],
                      ),
                      child: Center(
                        child: Text(
                          tr('${pins.length} χώροι στον χάρτη'),
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w600, color: _kText),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Selected gym card
          if (_selected != null)
            Positioned(
              left: 16, right: 16, bottom: 32,
              child: _GymCard(
                gym: _selected!,
                onOpen: widget.onOpenGym == null
                    ? null
                    : () => widget.onOpenGym!(_selected!),
              ),
            ),
        ],
      ),
    );
  }
}

class _GymPin extends StatelessWidget {
  const _GymPin({required this.selected});
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: selected ? 42 : 36,
      height: selected ? 42 : 36,
      decoration: BoxDecoration(
        color: selected ? _kAccent : const Color(0xFF565CE4),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [BoxShadow(
          color: (selected ? _kAccent : const Color(0xFF565CE4)).withValues(alpha: 0.5),
          blurRadius: selected ? 12 : 6,
        )],
      ),
      child: const Icon(Icons.fitness_center_rounded, color: Colors.white, size: 16),
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.gym, this.onOpen});
  final Map<String, dynamic> gym;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    final name      = gym['app_name'] as String? ?? gym['name'] as String? ?? '';
    final area      = gym['area'] as String? ?? gym['city'] as String? ?? '';
    final distKm    = (gym['distance_km'] as num?);
    final distStr   = distKm != null
        ? (distKm < 1 ? '${(distKm * 1000).round()} m' : '${distKm.toStringAsFixed(1)} km')
        : null;
    final rating    = (gym['rating'] as num?)?.toStringAsFixed(1);
    final hasDropIn = gym['has_drop_in'] as bool? ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _kBorder),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.5), blurRadius: 20)],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name,
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
                const SizedBox(height: 3),
                Row(
                  children: [
                    if (area.isNotEmpty) ...[
                      const Icon(Icons.location_on_outlined, size: 12, color: _kGray),
                      const SizedBox(width: 3),
                      Text(area,
                        style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
                    ],
                    if (distStr != null) ...[
                      if (area.isNotEmpty)
                        Text(' · ', style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
                      Text(distStr,
                        style: GoogleFonts.inter(fontSize: 12, color: _kGray)),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    if (rating != null) ...[
                      const Icon(Icons.star_rounded, color: Color(0xFFF5C542), size: 13),
                      const SizedBox(width: 3),
                      Text(rating,
                        style: GoogleFonts.inter(fontSize: 12, color: _kText)),
                      const SizedBox(width: 8),
                    ],
                    if (hasDropIn)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                        decoration: BoxDecoration(
                          color: const Color(0xFF17332B),
                          borderRadius: BorderRadius.circular(6)),
                        child: Text(tr('Μεμονωμένη'),
                          style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: const Color(0xFF8DE2BB))),
                      ),
                  ],
                ),
              ],
            ),
          ),
          if (onOpen != null) ...[
            const SizedBox(width: 12),
            GestureDetector(
              onTap: onOpen,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF565CE4),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(tr('Άνοιγμα'),
                  style: GoogleFonts.inter(
                    fontSize: 13, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
