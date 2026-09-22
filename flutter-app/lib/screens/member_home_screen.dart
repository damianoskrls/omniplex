import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../widgets/omni_design.dart';
import 'my_gyms_screen.dart';
import 'qr_checkin_screen.dart';

class MemberHomeScreen extends StatefulWidget {
  const MemberHomeScreen({super.key});

  @override
  State<MemberHomeScreen> createState() => _MemberHomeScreenState();
}

class _MemberHomeScreenState extends State<MemberHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: IndexedStack(
        index: _tab,
        children: [
          _HomeTab(onTabChange: (i) => setState(() => _tab = i)),
          const _PlaceholderTab(label: 'Search'),
          const _PlaceholderTab(label: 'Schedule'),
          MyGymsScreen(onTabChange: (i) => setState(() => _tab = i)),
          const _PlaceholderTab(label: 'Profile'),
        ],
      ),
      bottomNavigationBar: _BottomBar(
        currentIndex: _tab,
        onTap: (i) => setState(() => _tab = i),
      ),
    );
  }
}

class _HomeTab extends StatelessWidget {
  const _HomeTab({this.onTabChange});
  final ValueChanged<int>? onTabChange;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    final firstName = user?.fullName.split(' ').first ?? 'there';
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMM d').format(now);
    final hour = now.hour;
    final greeting = hour < 12 ? 'Good morning' : hour < 17 ? 'Good afternoon' : 'Good evening';

    return Stack(
      fit: StackFit.expand,
      children: [
        // Lime top gradient
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
        // Cyan right gradient
        Positioned(
          right: 0, top: 384, width: 160, height: 160,
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [kCyan.withValues(alpha: 0.08), Colors.transparent],
                stops: const [0.0, 0.7],
              ),
            ),
          ),
        ),

        SafeArea(
          bottom: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 56, 20, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(context, dateLabel, greeting, firstName),
                const SizedBox(height: 28),
                _buildMyGym(context),
                const SizedBox(height: 28),
                _buildNextClass(),
                const SizedBox(height: 28),
                _buildQuickActions(context),
                const SizedBox(height: 28),
                _buildThisWeek(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(BuildContext context, String dateLabel, String greeting, String firstName) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel, style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: kGray, letterSpacing: 0.05)),
            const SizedBox(height: 4),
            Text('$greeting,', style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.5)),
            Text('$firstName 👋', style: GoogleFonts.spaceGrotesk(
              fontSize: 20, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.5)),
          ],
        ),
        Row(
          children: [
            // Notification bell
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kCard,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: Stack(
                children: [
                  const Center(child: Icon(Icons.notifications_outlined, color: Colors.white, size: 20)),
                  Positioned(
                    right: 10, top: 8,
                    child: Container(
                      width: 8, height: 8,
                      decoration: BoxDecoration(
                        color: kLime,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.9), blurRadius: 8)],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Avatar
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kLime, width: 2),
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xFF2A2B30),
                child: Icon(Icons.person, color: Colors.white, size: 20),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMyGym(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('My Gym', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: kBorder),
          ),
          clipBehavior: Clip.hardEdge,
          child: Column(
            children: [
              // Gym photo header
              SizedBox(
                height: 160,
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
                            kBg.withValues(alpha: 0.15),
                            kBg.withValues(alpha: 0.4),
                            kBg.withValues(alpha: 0.92),
                          ],
                          stops: const [0.0, 0.6, 1.0],
                        ),
                      ),
                    ),
                    // Gym logo + name
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
                              Text('Fitness Club Athens', style: GoogleFonts.spaceGrotesk(
                                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                              Text('24 Syngrou Avenue', style: GoogleFonts.manrope(
                                fontSize: 12, color: kGray)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Active badge
                    Positioned(
                      right: 16, top: 16,
                      child: Container(
                        height: 32,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(9999),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.check, size: 10, color: kBg),
                            const SizedBox(width: 4),
                            Text('Active', style: GoogleFonts.spaceGrotesk(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: kBg, letterSpacing: 0.3)),
                          ],
                        ),
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
                    Row(
                      children: [
                        Text('Valid until ', style: GoogleFonts.manrope(
                          fontSize: 12, color: kGray)),
                        Text('Oct 28', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(color: kBorder, height: 1),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined, color: kGray, size: 12),
                        const SizedBox(width: 8),
                        Text('Next booking: 18:30 · CrossFit', style: GoogleFonts.manrope(
                          fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: kBorder2),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.open_in_new, color: Colors.white, size: 12),
                                const SizedBox(width: 8),
                                Text('Open Gym', style: GoogleFonts.spaceGrotesk(
                                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: () => Navigator.push(context,
                            MaterialPageRoute(builder: (_) => const QrCheckinScreen(gymName: 'Fitness Club Athens'))),
                          child: Container(
                            width: 48, height: 48,
                            decoration: BoxDecoration(
                              color: kLime,
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.4), blurRadius: 10)],
                            ),
                            child: const Icon(Icons.qr_code_scanner, color: kBg, size: 20),
                          ),
                        ),
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

  Widget _buildNextClass() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 25, 20, 20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEXT CLASS', style: GoogleFonts.manrope(
            fontSize: 11, fontWeight: FontWeight.w700,
            color: kCyan, letterSpacing: 1.1)),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('18:30', style: GoogleFonts.spaceGrotesk(
                    fontSize: 36, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.9, height: 1)),
                  const SizedBox(height: 4),
                  Text('CrossFit', style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text('Fitness Club Athens', style: GoogleFonts.manrope(
                    fontSize: 12, color: kGray)),
                ],
              ),
              Container(
                width: 64, height: 64,
                decoration: BoxDecoration(
                  color: const Color(0xFF0F2429),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: kCyan.withValues(alpha: 0.3)),
                ),
                child: const Icon(Icons.local_fire_department_outlined, color: kCyan, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: kBorder, height: 1),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: kBorder2),
                    ),
                    child: const CircleAvatar(
                      backgroundColor: Color(0xFF2A2B30),
                      child: Icon(Icons.person, color: Colors.white, size: 16),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text('Coach Maria', style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
              Container(
                height: 44,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: kLime,
                  borderRadius: BorderRadius.circular(9999),
                ),
                child: Center(
                  child: Text('View Booking', style: GoogleFonts.spaceGrotesk(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: kBg, letterSpacing: 0.3)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    final actions = [
      (Icons.fitness_center, 'Book a Class', const Color(0xFF1D2410), kLime.withValues(alpha: 0.3)),
      (Icons.search, 'Discover Gyms', const Color(0xFF0F2429), kCyan.withValues(alpha: 0.3)),
      (Icons.card_membership, 'Buy Package', const Color(0xFF1F2024), kBorder2),
      (Icons.badge_outlined, 'Memberships', const Color(0xFF1F2024), kBorder2),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Quick Actions', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 1.6,
          children: actions.map((a) {
            return Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: kCard,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: kBorder),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44, height: 30,
                    decoration: BoxDecoration(
                      color: a.$3,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: a.$4),
                    ),
                    child: Icon(a.$1, color: Colors.white, size: 16),
                  ),
                  const Spacer(),
                  Text(a.$2, style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
                ],
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildThisWeek() {
    final now = DateTime.now();
    // Week starting Monday
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('This Week', style: GoogleFonts.spaceGrotesk(
          fontSize: 16, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.4)),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Column(
            children: [
              // Day row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(7, (i) {
                  final d = monday.add(Duration(days: i));
                  final isToday = d.day == now.day;
                  return Column(
                    children: [
                      Text(days[i], style: GoogleFonts.manrope(
                        fontSize: 10,
                        fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                        color: isToday ? kLime : kGray)),
                      const SizedBox(height: 6),
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: isToday ? kLime : Colors.transparent,
                          shape: BoxShape.circle,
                          boxShadow: isToday ? [
                            BoxShadow(color: kLime.withValues(alpha: 0.5), blurRadius: 7),
                          ] : null,
                        ),
                        child: Center(
                          child: Text('${d.day}', style: GoogleFonts.manrope(
                            fontSize: 12,
                            fontWeight: isToday ? FontWeight.w700 : FontWeight.w600,
                            color: isToday ? kBg : kGray)),
                        ),
                      ),
                    ],
                  );
                }),
              ),
              const SizedBox(height: 12),
              const Divider(color: kBorder, height: 1),
              const SizedBox(height: 12),
              _scheduleRow(kLime, '18:30 CrossFit', 'Fitness Club Athens'),
              const SizedBox(height: 12),
              _scheduleRow(kCyan, '20:00 Yoga', 'Urban Fitness'),
              const SizedBox(height: 12),
              Container(
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: kBorder2),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('View Full Schedule', style: GoogleFonts.spaceGrotesk(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.35)),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward, color: Colors.white, size: 14),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _scheduleRow(Color dot, String title, String subtitle) {
    return Row(
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(
            color: dot,
            shape: BoxShape.circle,
            boxShadow: [BoxShadow(color: dot.withValues(alpha: 0.8), blurRadius: 8)],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
              Text(subtitle, style: GoogleFonts.manrope(
                fontSize: 12, color: kGray)),
            ],
          ),
        ),
        const Icon(Icons.chevron_right, color: kGray, size: 16),
      ],
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.currentIndex, required this.onTap});
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final items = [
      (Icons.home_outlined, 'Home'),
      (Icons.search, 'Search'),
      (Icons.calendar_month_outlined, 'Schedule'),
      (Icons.fitness_center, 'My Gyms'),
      (Icons.person_outline, 'Profile'),
    ];

    return Container(
      decoration: BoxDecoration(
        color: kCard,
        border: const Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(items.length, (i) {
              final active = currentIndex == i;
              return GestureDetector(
                onTap: () => onTap(i),
                child: SizedBox(
                  width: 56,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: active ? kLime.withValues(alpha: 0.1) : Colors.transparent,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(items[i].$1,
                          color: active ? kLime : kGray, size: 22),
                      ),
                      const SizedBox(height: 4),
                      Text(items[i].$2, style: GoogleFonts.spaceGrotesk(
                        fontSize: 10, fontWeight: FontWeight.w700,
                        color: active ? kLime : kGray,
                        letterSpacing: 0.2)),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Center(
        child: Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
      ),
    );
  }
}
