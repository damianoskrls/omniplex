import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';
import 'login_screen.dart';

class DiscoveryHomeScreen extends StatefulWidget {
  const DiscoveryHomeScreen({super.key});

  @override
  State<DiscoveryHomeScreen> createState() => _DiscoveryHomeScreenState();
}

class _DiscoveryHomeScreenState extends State<DiscoveryHomeScreen> {
  int _selectedFilter = 0;
  final _filters = ['CrossFit', 'Yoga', 'Pilates', 'Strength'];

  final _gyms = [
    _GymData(
      name: 'Fitness Club Athens',
      distance: '1.2 km',
      rating: '4.8',
      categories: 'CrossFit · Strength · Yoga',
      price: '€45',
    ),
    _GymData(
      name: 'Urban Fitness',
      distance: '2.4 km',
      rating: '4.6',
      categories: 'Pilates · Boxing · Cardio',
      price: '€39',
    ),
    _GymData(
      name: 'Iron Works Gym',
      distance: '3.1 km',
      rating: '4.9',
      categories: 'Strength · CrossFit · Powerlifting',
      price: '€52',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Top lime gradient
          Positioned(
            left: 0, top: 0, width: double.infinity, height: 256,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    kLime.withValues(alpha: 0.10),
                    kLime.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.6],
                ),
              ),
            ),
          ),
          // Cyan right glow
          Positioned(
            right: 0, top: 160, width: 160, height: 160,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kCyan.withValues(alpha: 0.10), Colors.transparent],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),

          SafeArea(
            bottom: true,
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 56, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTopBar(context),
                  const SizedBox(height: 32),
                  _buildHero(),
                  const SizedBox(height: 24),
                  _buildSearchBar(),
                  const SizedBox(height: 24),
                  _buildFilterChips(),
                  const SizedBox(height: 36),
                  _buildSectionHeader(),
                  const SizedBox(height: 16),
                  ..._gyms.map((g) => Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _GymCard(data: g),
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.fitness_center, color: kBg, size: 18),
            ),
            const SizedBox(width: 8),
            Text('OmniPlex', style: GoogleFonts.spaceGrotesk(
              fontSize: 18, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.45)),
          ],
        ),
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const LoginScreen())),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Text('Log in', style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700,
              color: kLime, letterSpacing: 0.35)),
          ),
        ),
      ],
    );
  }

  Widget _buildHero() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Find your\nperfect gym.', style: GoogleFonts.spaceGrotesk(
          fontSize: 32, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.8, height: 1.1)),
        const SizedBox(height: 10),
        Text('Discover gyms, classes and memberships\nnear you.',
          style: GoogleFonts.manrope(
            fontSize: 14, color: kGray, height: 1.625)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const Icon(Icons.search, color: kGray, size: 18),
          const SizedBox(width: 12),
          Text('Search gyms, classes or activities',
            style: GoogleFonts.manrope(fontSize: 14, color: kGray)),
        ],
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(_filters.length, (i) {
          final active = _selectedFilter == i;
          return Padding(
            padding: EdgeInsets.only(right: i < _filters.length - 1 ? 10 : 0),
            child: GestureDetector(
              onTap: () => setState(() => _selectedFilter = i),
              child: Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: kCard,
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: active ? kCyan.withValues(alpha: 0.4) : kBorder),
                ),
                child: Center(
                  child: Text(_filters[i], style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: active ? kCyan : Colors.white)),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildSectionHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text('Gyms near you', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.45)),
        Text('See all', style: GoogleFonts.spaceGrotesk(
          fontSize: 12, fontWeight: FontWeight.w700,
          color: kLime, letterSpacing: 0.3)),
      ],
    );
  }
}

class _GymData {
  final String name;
  final String distance;
  final String rating;
  final String categories;
  final String price;
  const _GymData({
    required this.name, required this.distance, required this.rating,
    required this.categories, required this.price,
  });
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.data});
  final _GymData data;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 15, offset: const Offset(0, 10)),
        ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Photo header
          SizedBox(
            height: 176,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Container(color: const Color(0xFF1E1F24)),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        kBg.withValues(alpha: 0.7),
                      ],
                      stops: const [0.5, 1.0],
                    ),
                  ),
                ),
                // Gym logo (overlapping bottom)
                Positioned(
                  left: 16, bottom: -24,
                  child: Container(
                    width: 56, height: 56,
                    decoration: BoxDecoration(
                      color: kCard,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: kBg, width: 2),
                    ),
                    child: const Icon(Icons.fitness_center, color: kGray, size: 24),
                  ),
                ),
              ],
            ),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 36, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(data.name, style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 5),
                Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(data.rating, style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    const SizedBox(width: 8),
                    Container(
                      width: 4, height: 4,
                      decoration: BoxDecoration(
                        color: kBorder2, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Text(data.distance, style: GoogleFonts.manrope(
                      fontSize: 12, color: kGray)),
                  ],
                ),
                const SizedBox(height: 5),
                Text(data.categories, style: GoogleFonts.manrope(
                  fontSize: 12, color: kGray)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text.rich(TextSpan(children: [
                      TextSpan(text: 'From ', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                      TextSpan(text: data.price, style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: kLime)),
                      TextSpan(text: '/month', style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                    ])),
                    Container(
                      height: 40,
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      decoration: BoxDecoration(
                        color: kLime,
                        borderRadius: BorderRadius.circular(9999),
                      ),
                      child: Center(
                        child: Text('View Gym', style: GoogleFonts.spaceGrotesk(
                          fontSize: 12, fontWeight: FontWeight.w700,
                          color: kBg, letterSpacing: 0.3)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
