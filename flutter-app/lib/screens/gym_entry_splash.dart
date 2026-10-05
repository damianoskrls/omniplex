import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../l10n/tr.dart';

/// Removes the logo splash pushed by [showGymEntrySplash].
/// Call this before the parent replaces the shell, otherwise the route stays
/// on top of the next screen and the gym never appears.
void dismissGymEntrySplash(NavigatorState nav) {
  if (nav.canPop()) nav.pop();
}

/// Covers the screen with the gym logo while the gym session is opening.
/// Stays up until the route is removed. The caller does the loading underneath.
Future<void> showGymEntrySplash(
  BuildContext context, {
  required String name,
  String? logoUrl,
}) {
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: Duration.zero,
    reverseTransitionDuration: Duration.zero,
    pageBuilder: (_, _, _) => PopScope(
      canPop: false,
      child: GymEntrySplashView(name: name, logoUrl: logoUrl),
    ),
  ));
}

class GymEntrySplashView extends StatelessWidget {
  const GymEntrySplashView({super.key, required this.name, this.logoUrl});

  final String name;
  final String? logoUrl;

  @override
  Widget build(BuildContext context) {
    final logo = logoUrl;
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0A),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (logo != null && logo.isNotEmpty)
                Container(
                  constraints: const BoxConstraints(maxWidth: 320, minHeight: 96, maxHeight: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 24)],
                  ),
                  child: Image.network(
                    logo,
                    fit: BoxFit.contain,
                    width: 280,
                    height: 140,
                    errorBuilder: (_, _, _) => _mark(name),
                  ),
                )
              else
                _mark(name),
              const SizedBox(height: 18),
              Text(
                tr(name),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
              ),
              const SizedBox(height: 28),
              const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _mark(String gymName) {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tr(gymName.isEmpty ? 'G' : gymName.characters.first.toUpperCase()),
        style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: const Color(0xFF7B3EAD)),
      ),
    );
  }
}
