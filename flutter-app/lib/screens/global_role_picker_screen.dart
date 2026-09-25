import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import 'global_profile_details_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

enum GlobalRole { client, trainer }

class GlobalRolePickerScreen extends StatefulWidget {
  const GlobalRolePickerScreen({
    super.key,
    required this.globalAuth,
    required this.onDone,
    this.skipDetails = false,
  });

  final GlobalAuthService globalAuth;
  /// Called after profile details are saved; passes the chosen role
  final void Function(GlobalRole role) onDone;
  /// When true, skip the profile details step (for returning users)
  final bool skipDetails;

  @override
  State<GlobalRolePickerScreen> createState() => _GlobalRolePickerScreenState();
}

class _GlobalRolePickerScreenState extends State<GlobalRolePickerScreen> {
  GlobalRole? _selected;

  Future<void> _next() async {
    final role = _selected;
    if (role == null) return;
    if (widget.skipDetails) {
      await widget.globalAuth.setPreferredRole(
        role == GlobalRole.trainer ? 'staff' : 'member',
      );
      if (mounted) widget.onDone(role);
    } else {
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => GlobalProfileDetailsScreen(
          globalAuth: widget.globalAuth,
          role: role,
          onDone: () => widget.onDone(role),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(28, 0, 28, 36),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 32),

              // Back
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  alignment: Alignment.center,
                  child: const Icon(Icons.arrow_back_rounded,
                    color: Colors.white, size: 18),
                ),
              ),

              const SizedBox(height: 32),

              Text(widget.skipDetails ? 'ΕΠΙΛΟΓΗ ΡΟΛΟΥ' : 'Βήμα 1 από 2',
                style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600,
                  color: _kGray, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              Text('Πώς θα\nχρησιμοποιήσεις\nτο OmniPlex;',
                style: GoogleFonts.manrope(
                  fontSize: 30, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.75, height: 1.15)),
              const SizedBox(height: 8),
              Text('Επέλεξε τον ρόλο σου για να σε κατευθύνουμε\nσωστά.',
                style: GoogleFonts.manrope(
                  fontSize: 14, color: _kGray, height: 1.55)),

              const SizedBox(height: 36),

              // Card: Ασκούμενος
              _RoleCard(
                icon: Icons.fitness_center_rounded,
                iconColor: _kLime,
                title: 'Ασκούμενος',
                subtitle: 'Θέλω να βρω γυμναστήριο, να κάνω κρατήσεις\nκαι να παρακολουθώ την πρόοδό μου.',
                selected: _selected == GlobalRole.client,
                onTap: () => setState(() => _selected = GlobalRole.client),
              ),

              const SizedBox(height: 14),

              // Card: Γυμναστής
              _RoleCard(
                icon: Icons.sports_rounded,
                iconColor: const Color(0xFF3EE6FF),
                title: 'Γυμναστής / Professional',
                subtitle: 'Εργάζομαι σε γυμναστήριο ή είμαι personal\ntrainer και θέλω να συνδεθώ με το χώρο μου.',
                selected: _selected == GlobalRole.trainer,
                onTap: () => setState(() => _selected = GlobalRole.trainer),
              ),

              const Spacer(),

              // Continue button
              GestureDetector(
                onTap: _selected != null ? _next : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 56,
                  decoration: BoxDecoration(
                    color: _selected != null ? _kLime : _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _selected != null ? _kLime : _kBorder,
                    ),
                    boxShadow: _selected != null ? [
                      BoxShadow(
                        color: _kLime.withValues(alpha: 0.28),
                        blurRadius: 16, offset: const Offset(0, 6)),
                    ] : null,
                  ),
                  alignment: Alignment.center,
                  child: Text('Συνέχεια',
                    style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: _selected != null ? _kBg : _kGray)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  const _RoleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: selected
            ? iconColor.withValues(alpha: 0.07)
            : _kCard,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? iconColor : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: selected ? 0.15 : 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              alignment: Alignment.center,
              child: Icon(icon, color: iconColor, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                    style: GoogleFonts.manrope(
                      fontSize: 15, fontWeight: FontWeight.w700,
                      color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(subtitle,
                    style: GoogleFonts.manrope(
                      fontSize: 12, color: _kGray, height: 1.5)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 22, height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? iconColor : Colors.transparent,
                border: Border.all(
                  color: selected ? iconColor : _kBorder, width: 1.5),
              ),
              alignment: Alignment.center,
              child: selected
                ? const Icon(Icons.check_rounded,
                    color: Color(0xFF0A0A0A), size: 13)
                : null,
            ),
          ],
        ),
      ),
    );
  }
}
