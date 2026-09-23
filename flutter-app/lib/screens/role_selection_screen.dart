import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);
const _kCyan   = Color(0xFF3EE6FF);

enum _Role { member, staff }

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key, required this.onContinue});

  /// Called with true=member, false=staff
  final void Function(bool isMember) onContinue;

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  _Role _selected = _Role.member;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: Stack(
        children: [
          // Background glow
          Positioned(
            top: 0, left: 0,
            child: SizedBox(
              width: 375, height: 300,
              child: CustomPaint(painter: _LimeGlowPainter()),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Container(
                          width: 44, height: 44,
                          decoration: BoxDecoration(
                            color: _kCard,
                            shape: BoxShape.circle,
                            border: Border.all(color: _kBorder),
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        ),
                      ),
                      Row(children: [
                        Container(
                          width: 32, height: 32,
                          decoration: BoxDecoration(
                            color: _kLime,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: SvgPicture.asset(
                            'assets/icons/discovery_logo_bolt.svg',
                            width: 12, height: 12),
                        ),
                        const SizedBox(width: 6),
                        Text('OmniPlex',
                          style: GoogleFonts.manrope(
                            fontSize: 16, fontWeight: FontWeight.w700,
                            color: Colors.white)),
                      ]),
                      const SizedBox(width: 44), // balance
                    ],
                  ),
                ),

                // Progress bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: Row(children: [
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: _kLime,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: _kBorder,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ]),
                ),

                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 40, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Πώς θα χρησιμοποιήσεις\nτο OmniPlex;',
                          style: GoogleFonts.manrope(
                            fontSize: 28, fontWeight: FontWeight.w700,
                            color: Colors.white, letterSpacing: -0.7, height: 1.1)),
                        const SizedBox(height: 10),
                        Text('Μπορείς να προσθέσεις ρόλο ανά πάσα στιγμή από το προφίλ σου.',
                          style: GoogleFonts.manrope(fontSize: 14, color: _kGray, height: 1.5)),
                        const SizedBox(height: 32),

                        // Member option
                        _roleOption(
                          role: _Role.member,
                          icon: Icons.fitness_center_rounded,
                          iconBg: const Color(0xFF1A2A0A),
                          iconColor: _kLime,
                          title: 'Μέλος',
                          description: 'Ανακάλυψε γυμναστήρια, κάνε κρατήσεις μαθημάτων και διαχειρίσου συνδρομές.',
                        ),
                        const SizedBox(height: 12),

                        // Staff option
                        _roleOption(
                          role: _Role.staff,
                          icon: Icons.assignment_outlined,
                          iconBg: const Color(0xFF0A1A2A),
                          iconColor: _kCyan,
                          title: 'Προσωπικό',
                          description: 'Διαχειρίσου μαθήματα, ραντεβού και το πρόγραμμά σου.',
                        ),

                        const SizedBox(height: 24),

                        // Info note
                        Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: _kCard,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _kBorder),
                          ),
                          child: Row(children: [
                            const Icon(Icons.info_outline_rounded,
                              color: _kGray, size: 16),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Ο ρόλος σου καθορίζει τον προεπιλεγμένο πίνακα ελέγχου και τα δικαιώματα εντός του OmniPlex.',
                                style: GoogleFonts.manrope(
                                  fontSize: 12, color: _kGray, height: 1.5)),
                            ),
                          ]),
                        ),
                      ],
                    ),
                  ),
                ),

                // Continue button
                Padding(
                  padding: EdgeInsets.fromLTRB(20, 20, 20,
                    MediaQuery.of(context).padding.bottom + 24),
                  child: GestureDetector(
                    onTap: () => widget.onContinue(_selected == _Role.member),
                    child: Container(
                      height: 56,
                      decoration: BoxDecoration(
                        color: _kLime,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('Συνέχεια',
                          style: GoogleFonts.manrope(
                            fontSize: 15, fontWeight: FontWeight.w700,
                            color: _kBg, letterSpacing: 0.3)),
                        const SizedBox(width: 8),
                        const Icon(Icons.arrow_forward_rounded, color: _kBg, size: 18),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _roleOption({
    required _Role role,
    required IconData icon,
    required Color iconBg,
    required Color iconColor,
    required String title,
    required String description,
  }) {
    final selected = _selected == role;
    return GestureDetector(
      onTap: () => setState(() => _selected = role),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _kLime.withValues(alpha: 0.06) : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? _kLime : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              const SizedBox(height: 3),
              Text(description, style: GoogleFonts.manrope(
                fontSize: 12, color: _kGray, height: 1.45)),
            ]),
          ),
          const SizedBox(width: 12),
          AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 24, height: 24,
            decoration: BoxDecoration(
              color: selected ? _kLime : Colors.transparent,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? _kLime : _kGray,
                width: 1.5,
              ),
            ),
            child: selected
              ? const Icon(Icons.check_rounded, color: Color(0xFF0A0A0A), size: 14)
              : null,
          ),
        ]),
      ),
    );
  }
}

class _LimeGlowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.topCenter,
        radius: 1.0,
        colors: [
          const Color(0xFFC6FF3D).withValues(alpha: 0.08),
          const Color(0xFFC6FF3D).withValues(alpha: 0.0),
        ],
        stops: const [0.0, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_) => false;
}
