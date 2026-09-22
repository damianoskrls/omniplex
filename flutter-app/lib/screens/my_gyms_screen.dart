import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/omni_design.dart';
import 'qr_checkin_screen.dart';

class MyGymsScreen extends StatefulWidget {
  const MyGymsScreen({super.key, this.onTabChange});
  final ValueChanged<int>? onTabChange;

  @override
  State<MyGymsScreen> createState() => _MyGymsScreenState();
}

class _MyGymsScreenState extends State<MyGymsScreen> {
  @override
  Widget build(BuildContext context) {
    context.watch<AuthService>();
    const gyms = <dynamic>[];

    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background
          CustomPaint(painter: OmniBgPainter(
            cyanOffset: Offset(MediaQuery.sizeOf(context).width, 384))),

          SafeArea(
            bottom: false,
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 28),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('My Gyms', style: GoogleFonts.spaceGrotesk(
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.6)),
                          Text('${gyms.length} connected gyms',
                            style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                        ],
                      ),
                      GestureDetector(
                        onTap: () {},
                        child: Container(
                          height: 44,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: kLime, width: 2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.add, color: kLime, size: 16),
                              const SizedBox(width: 8),
                              Text('Add Gym', style: GoogleFonts.spaceGrotesk(
                                fontSize: 12, fontWeight: FontWeight.w700,
                                color: kLime, letterSpacing: 0.3)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Gym list
                Expanded(
                  child: gyms.isEmpty
                      ? _buildEmpty()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                          itemCount: gyms.length + 1,
                          itemBuilder: (ctx, i) {
                            if (i == gyms.length) return _buildAddCard();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 20),
                              child: _GymCard(gym: gyms[i]),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: kCard,
              shape: BoxShape.circle,
              border: Border.all(color: kBorder),
            ),
            child: const Icon(Icons.fitness_center, color: kGray, size: 28),
          ),
          const SizedBox(height: 16),
          Text('No gyms connected', style: GoogleFonts.spaceGrotesk(
            fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
          const SizedBox(height: 8),
          Text('Search and join gyms near you', style: GoogleFonts.manrope(
            fontSize: 14, color: kGray)),
        ],
      ),
    );
  }

  Widget _buildAddCard() {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: kBorder2, width: 2,
            style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kCard,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 8),
            Text('Connect a new gym', style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
            const SizedBox(height: 4),
            Text('Search and join gyms near you', style: GoogleFonts.manrope(
              fontSize: 12, color: kGray)),
          ],
        ),
      ),
    );
  }
}

class _GymCard extends StatelessWidget {
  const _GymCard({required this.gym});
  final dynamic gym;

  @override
  Widget build(BuildContext context) {
    final name = gym.name ?? 'Gym';
    final address = gym.address ?? '';
    final isPending = gym.status == 'pending';
    final membershipLabel = isPending ? 'Pending Approval' : 'Active Membership';
    final membershipColor = isPending ? const Color(0xFFF5A623) : kLime;
    final membershipBg = isPending ? const Color(0xFF1F1A0E) : const Color(0xFF1D2410);

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          // Image + overlay
          SizedBox(
            height: 144,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Gym image or placeholder
                gym.imageUrl != null
                    ? Image.network(gym.imageUrl, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => Container(color: const Color(0xFF1E1F24)))
                    : Container(color: const Color(0xFF1E1F24)),

                // Gradient
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        kBg.withValues(alpha: 0.1),
                        kBg.withValues(alpha: 0.35),
                        kBg.withValues(alpha: 0.92),
                      ],
                      stops: const [0.0, 0.6, 1.0],
                    ),
                  ),
                ),

                // Top-left: gym logo + name
                Positioned(
                  left: 16, top: 16,
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: kCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: kBorder),
                        ),
                        child: const Icon(Icons.fitness_center, color: kGray, size: 20),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(name, style: GoogleFonts.spaceGrotesk(
                            fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                          if (address.isNotEmpty)
                            Text(address, style: GoogleFonts.manrope(
                              fontSize: 12, color: kGray)),
                        ],
                      ),
                    ],
                  ),
                ),

                // Top-right: status badge
                Positioned(
                  right: 16, top: 16,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: membershipBg,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(color: membershipColor.withValues(alpha: 0.3)),
                    ),
                    child: Text(membershipLabel, style: GoogleFonts.spaceGrotesk(
                      fontSize: 11, fontWeight: FontWeight.w700,
                      color: membershipColor, letterSpacing: 0.3)),
                  ),
                ),
              ],
            ),
          ),

          // Card body
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                if (!isPending) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('Expires Oct 28', style: GoogleFonts.manrope(
                        fontSize: 12, color: kGray)),
                      Row(
                        children: [
                          const Icon(Icons.all_inclusive, color: kLime, size: 14),
                          const SizedBox(width: 6),
                          Text('Unlimited', style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w700, color: kLime)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: kBorder, thickness: 1, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: kGray, size: 14),
                      const SizedBox(width: 8),
                      Text('18:30 CrossFit · Tomorrow', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: GestureDetector(
                          onTap: () {},
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kBorder2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fitness_center, color: Colors.white, size: 14),
                                const SizedBox(width: 8),
                                Text('Open Gym', style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      GestureDetector(
                        onTap: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => QrCheckinScreen(gymName: name))),
                        child: Container(
                          width: 48, height: 48,
                          decoration: BoxDecoration(
                            color: kLime,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(color: kLime.withValues(alpha: 0.4), blurRadius: 10),
                            ],
                          ),
                          child: const Icon(Icons.qr_code_scanner, color: kBg, size: 20),
                        ),
                      ),
                    ],
                  ),
                ] else ...[
                  Row(
                    children: [
                      const Icon(Icons.hourglass_empty, color: Color(0xFFF5A623), size: 14),
                      const SizedBox(width: 8),
                      Text('Waiting for gym approval', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: const Color(0xFFF5A623))),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: kBorder, thickness: 1, height: 1),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: Opacity(
                          opacity: 0.5,
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kBorder2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.fitness_center, color: Colors.white, size: 14),
                                const SizedBox(width: 8),
                                Text('Open Gym', style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        width: 48, height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2024),
                          shape: BoxShape.circle,
                          border: Border.all(color: kBorder2),
                        ),
                        child: const Icon(Icons.arrow_forward, color: kGray, size: 20),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
