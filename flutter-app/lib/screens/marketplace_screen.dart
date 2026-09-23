import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const _kBorder26 = Color(0xFF262626);
  static const _kGray6B = Color(0xFF6B7280);
  static const _kGray9C = Color(0xFF9CA3AF);
  static const _kDark16 = Color(0xFF161616);

  int _activeFilter = 0;
  final _filters = ['ALL', 'SUPPLEMENTS', 'APPAREL', 'ACCESSORIES'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(bottom: 96),
            child: Column(
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
                  child: Column(
                    children: [
                      _buildSearchAndFilters(),
                      const SizedBox(height: 32),
                      _buildProductGrid(),
                      const SizedBox(height: 32),
                      _buildPromoBanner(),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: _buildBottomNav()),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return SafeArea(
      child: Container(
        color: kBg.withValues(alpha: 0.80),
        padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 40, height: 40,
              decoration: BoxDecoration(
                color: _kDark16,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
              ),
              child: const Center(child: Icon(Icons.chevron_left, color: Colors.white, size: 20)),
            ),
            Text('MARKETPLACE', style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w800,
              color: Colors.white, letterSpacing: 2.0)),
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kDark16,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                  ),
                  child: const Center(child: Icon(Icons.shopping_cart_outlined, color: Colors.white, size: 18)),
                ),
                Positioned(
                  top: -4, right: -4,
                  child: Container(
                    width: 20, height: 20,
                    decoration: const BoxDecoration(color: kCyan, shape: BoxShape.circle),
                    child: Center(
                      child: Text('3', style: GoogleFonts.manrope(
                        fontSize: 10, fontWeight: FontWeight.w700, color: kBg)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Column(
      children: [
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: _kDark16,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 16),
              const Icon(Icons.search, color: Color(0xFF9CA3AF), size: 18),
              const SizedBox(width: 12),
              Text('Search gear, supplements...', style: GoogleFonts.manrope(
                fontSize: 14, color: _kGray9C)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 38,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: _filters.length,
            separatorBuilder: (context2, index2) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final active = _activeFilter == i;
              return GestureDetector(
                onTap: () => setState(() => _activeFilter = i),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(
                    color: active ? kLime : _kDark16,
                    borderRadius: BorderRadius.circular(9999),
                    border: active ? null : Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    boxShadow: active ? [BoxShadow(
                      color: kLime.withValues(alpha: 0.20), blurRadius: 10)] : null,
                  ),
                  child: Text(_filters[i], style: GoogleFonts.manrope(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: active ? kBg : _kGray9C, letterSpacing: 0.55)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildProductGrid() {
    final products = [
      _Product('Iso-Whey Pro\nMax 2.2kg', 'SUPPLEMENTS', '€45.00', true),
      _Product('Signature Elite\nTech Tee', 'APPAREL', '€25.00', false),
      _Product('Stealth Shaker\n700ml', 'ACCESSORIES', '€12.00', false),
      _Product('Pro-Series\nLeather Belt', 'EQUIPMENT', '€55.00', false),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 0.62,
      ),
      itemCount: products.length,
      itemBuilder: (_, i) => _buildProductCard(products[i]),
    );
  }

  Widget _buildProductCard(_Product p) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0x66262626), Color(0x99161616)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Container(
                height: 176,
                color: const Color(0xFF161616),
                child: Center(
                  child: Icon(Icons.inventory_2_outlined,
                    color: _kBorder26, size: 48),
                ),
              ),
              if (p.isBestseller)
                Positioned(
                  top: 12, left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: kCyan.withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: kCyan.withValues(alpha: 0.30)),
                    ),
                    child: Text('Bestseller', style: GoogleFonts.manrope(
                      fontSize: 9, fontWeight: FontWeight.w700,
                      color: kCyan, letterSpacing: -0.45)),
                  ),
                ),
            ],
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.category, style: GoogleFonts.manrope(
                    fontSize: 10, fontWeight: FontWeight.w700, color: _kGray6B)),
                  const SizedBox(height: 4),
                  Text(p.name, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700,
                    color: Colors.white, height: 1.25)),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(p.price, style: GoogleFonts.spaceGrotesk(
                        fontSize: 18, fontWeight: FontWeight.w700, color: kLime)),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                        ),
                        child: const Icon(Icons.add, color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _kDark16,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
                    ),
                    child: Text('VIEW', style: GoogleFonts.manrope(
                      fontSize: 10, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: 1.0),
                      textAlign: TextAlign.center),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPromoBanner() {
    return Container(
      height: 128,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1A00), Color(0xFF1A2A00)],
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                color: kBg.withValues(alpha: 0.40),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('20% OFF ALL\nPROTEIN THIS WEEK', style: GoogleFonts.spaceGrotesk(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: Colors.white, height: 1.25)),
                const SizedBox(height: 4),
                Text('USE CODE: OMNIPLEX20', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: kLime, letterSpacing: 1.0)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: kBg.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: Color(0xFF262626))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildNavItem(Icons.home_rounded, 'HOME', false),
          _buildNavItem(Icons.storefront_outlined, 'SHOP', true),
          _buildNavItem(Icons.calendar_today, 'SCHEDULE', false),
          _buildNavItem(Icons.fitness_center_outlined, 'WORKOUTS', false),
          _buildProfileNav(),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, bool active) {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: active ? kLime : _kGray6B, size: 22),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: active ? kLime : _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }

  Widget _buildProfileNav() {
    return SizedBox(
      width: 60,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: _kGray6B),
              color: const Color(0xFF3A3C42),
            ),
            child: const Icon(Icons.person, color: Colors.white, size: 14),
          ),
          const SizedBox(height: 4),
          Text('PROFILE', style: GoogleFonts.manrope(
            fontSize: 9, fontWeight: FontWeight.w700,
            color: _kGray6B, letterSpacing: 0.9)),
        ],
      ),
    );
  }
}

class _Product {
  final String name;
  final String category;
  final String price;
  final bool isBestseller;
  const _Product(this.name, this.category, this.price, this.isBestseller);
}
