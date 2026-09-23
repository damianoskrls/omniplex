import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';
import '../services/global_auth_service.dart';

class GymProfileScreen extends StatefulWidget {
  const GymProfileScreen({
    super.key,
    this.gymName = 'Fitness Club Athens',
    this.slug,
    this.globalAuth,
    this.onLoggedIn,
  });
  final String gymName;
  final String? slug;
  final GlobalAuthService? globalAuth;
  final VoidCallback? onLoggedIn;

  @override
  State<GymProfileScreen> createState() => _GymProfileScreenState();
}

class _GymProfileScreenState extends State<GymProfileScreen> {
  int _tab = 0;
  final _tabs = ['Overview', 'Schedule', 'Memberships', 'Reviews'];

  final _hours = [
    ('Monday', '06:00 - 23:00', false),
    ('Tuesday', '06:00 - 23:00', false),
    ('Wednesday', '06:00 - 23:00', true),
    ('Thursday', '06:00 - 23:00', false),
    ('Friday', '06:00 - 23:00', false),
    ('Saturday', '08:00 - 20:00', false),
    ('Sunday', '08:00 - 20:00', false),
  ];

  final _facilities = [
    (Icons.fitness_center, 'Free Weights'),
    (Icons.local_fire_department_outlined, 'Sauna'),
    (Icons.shower, 'Showers'),
    (Icons.local_parking, 'Parking'),
    (Icons.door_back_door_outlined, 'Locker Rooms'),
    (Icons.directions_run, 'Cardio Zone'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _buildHeroHeader()),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 16),
                      _buildGymTitle(),
                      const SizedBox(height: 24),
                      _buildTabBar(),
                      const SizedBox(height: 28),
                      _buildAbout(),
                      const SizedBox(height: 28),
                      _buildFacilities(),
                      const SizedBox(height: 28),
                      _buildOpeningHours(),
                      const SizedBox(height: 28),
                      _buildPhotos(),
                      const SizedBox(height: 28),
                      _buildLocation(),
                      const SizedBox(height: 100), // bottom CTA space
                    ],
                  ),
                ),
              ),
            ],
          ),
          // Bottom CTA bar
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomBar(context),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader() {
    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(color: const Color(0xFF1A1B20)),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withValues(alpha: 0.5),
                  kBg.withValues(alpha: 0.95),
                ],
                stops: const [0.0, 1.0],
              ),
            ),
          ),
          // Top bar
          Positioned(
            left: 20, right: 20, top: 56,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _glassBtn(
                  onTap: () => Navigator.maybePop(context),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                ),
                Row(
                  children: [
                    _glassBtn(child: const Icon(Icons.bookmark_border, color: Colors.white, size: 20)),
                    const SizedBox(width: 10),
                    _glassBtn(child: const Icon(Icons.share_outlined, color: Colors.white, size: 20)),
                  ],
                ),
              ],
            ),
          ),
          // Logo
          Positioned(
            left: 20, bottom: -36,
            child: Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: kCard,
                shape: BoxShape.circle,
                border: Border.all(color: kBg, width: 4),
              ),
              child: const Icon(Icons.fitness_center, color: kGray, size: 32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _glassBtn({required Widget child, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: const Color(0xCC16171B),
          shape: BoxShape.circle,
          border: Border.all(color: kBorder),
        ),
        child: Center(child: child),
      ),
    );
  }

  Widget _buildGymTitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 40), // space for logo overlap
        Text(widget.gymName, style: GoogleFonts.spaceGrotesk(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.6)),
        const SizedBox(height: 6),
        Row(
          children: [
            const Icon(Icons.star, color: Colors.white, size: 14),
            const SizedBox(width: 4),
            Text('4.8', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
            const SizedBox(width: 8),
            Text('(320 reviews)', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
          ],
        ),
        const SizedBox(height: 5),
        Row(
          children: [
            const Icon(Icons.location_on_outlined, color: kGray, size: 14),
            const SizedBox(width: 6),
            Text('Kolonaki, Athens · 1.2 km away', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
          ],
        ),
      ],
    );
  }

  Widget _buildTabBar() {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        children: List.generate(_tabs.length, (i) {
          final active = _tab == i;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _tab = i),
              child: Container(
                decoration: BoxDecoration(
                  color: active ? kLime : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(_tabs[i], style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: active ? kBg : kGray)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildAbout() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('About', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.45)),
        const SizedBox(height: 8),
        Text(
          'Fitness Club Athens is a premium strength and conditioning facility in the heart of Kolonaki. With top-tier equipment, expert coaches, and a vibrant community, we offer CrossFit, strength training, and boxing programs for all levels — from beginners to competitive athletes.',
          style: GoogleFonts.manrope(fontSize: 14, color: kGray, height: 1.625)),
      ],
    );
  }

  Widget _buildFacilities() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Facilities & Amenities', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.45)),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.7,
          children: _facilities.map((f) => Container(
            decoration: BoxDecoration(
              color: kCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(f.$1, color: Colors.white, size: 18),
                const SizedBox(height: 6),
                Text(f.$2, style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: Colors.white), textAlign: TextAlign.center),
              ],
            ),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildOpeningHours() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Opening Hours', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.45)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: List.generate(_hours.length, (i) {
              final h = _hours[i];
              final isToday = h.$3;
              return Container(
                decoration: BoxDecoration(
                  color: isToday ? kLime.withValues(alpha: 0.10) : Colors.transparent,
                  border: i < _hours.length - 1
                      ? const Border(bottom: BorderSide(color: Color(0xFF26272C)))
                      : null,
                ),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        if (isToday) ...[
                          Container(
                            width: 6, height: 6,
                            decoration: const BoxDecoration(
                              color: kLime, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                        ],
                        Text(h.$1, style: GoogleFonts.manrope(
                          fontSize: 14,
                          fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                          color: isToday ? kLime : kGray)),
                      ],
                    ),
                    Text(h.$2, style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                      color: isToday ? kLime : kGray)),
                  ],
                ),
              );
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotos() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.zero,
          child: Text('Photos', style: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.45)),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 128,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: 3,
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemBuilder: (_, i) => Container(
              width: 128, height: 128,
              decoration: BoxDecoration(
                color: const Color(0xFF1A1B20),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLocation() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Location', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.45)),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // Map placeholder
              Container(
                height: 160,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [const Color(0xFF1C1D22), kCard],
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 44, height: 44,
                    decoration: BoxDecoration(
                      color: kLime.withValues(alpha: 0.20),
                      shape: BoxShape.circle,
                    ),
                    child: Container(
                      width: 32, height: 32,
                      margin: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: kLime, shape: BoxShape.circle),
                      child: const Icon(Icons.location_on, color: kBg, size: 16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('15 Skoufa Street', style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        Text('Kolonaki, Athens 10673', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                      ],
                    ),
                    Row(
                      children: [
                        Text('Get Directions', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w700, color: kCyan)),
                        const SizedBox(width: 6),
                        const Icon(Icons.open_in_new, color: kCyan, size: 12),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomBar(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Row(
        children: [
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder2),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today_outlined, color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Book Drop-in', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.badge_outlined, color: kBg, size: 16),
                  const SizedBox(width: 8),
                  Text('View Memberships', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kBg)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
