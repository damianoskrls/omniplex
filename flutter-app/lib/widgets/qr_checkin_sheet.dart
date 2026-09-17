import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/auth_service.dart';
import '../screens/qr_checkin_screen.dart';
import '../l10n/app_strings.dart';

/// Shows a bottom sheet asking the user whether to scan or show their QR code.
Future<void> showQrCheckinSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => const _QrCheckinSheet(),
  );
}

class _QrCheckinSheet extends StatefulWidget {
  const _QrCheckinSheet();

  @override
  State<_QrCheckinSheet> createState() => _QrCheckinSheetState();
}

class _QrCheckinSheetState extends State<_QrCheckinSheet> {
  bool _showMyQr = false;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return AnimatedSize(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF16161E),
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        child: _showMyQr ? _MyQrView(onBack: () => setState(() => _showMyQr = false)) : _ChoiceView(
          onScan: () {
            Navigator.pop(context);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const QrCheckinScreen()),
            );
          },
          onShowQr: () => setState(() => _showMyQr = true),
        ),
      ),
    );
  }
}

class _ChoiceView extends StatelessWidget {
  const _ChoiceView({required this.onScan, required this.onShowQr});
  final VoidCallback onScan;
  final VoidCallback onShowQr;

  @override
  Widget build(BuildContext context) {
    final s = AppStrings.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 20),
          decoration: BoxDecoration(
            color: Colors.white12,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Text(
          s.qrTitle,
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(child: _OptionCard(
              icon: Icons.qr_code_scanner_rounded,
              label: s.qrScanOption,
              desc: s.qrScanDesc,
              onTap: onScan,
            )),
            const SizedBox(width: 12),
            Expanded(child: _OptionCard(
              icon: Icons.qr_code_rounded,
              label: s.qrShowOption,
              desc: s.qrShowDesc,
              accent: true,
              onTap: onShowQr,
            )),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.label,
    required this.desc,
    required this.onTap,
    this.accent = false,
  });

  final IconData icon;
  final String label;
  final String desc;
  final VoidCallback onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFB8F55E);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: accent ? lime.withValues(alpha: 0.08) : const Color(0xFF1E1E2A),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: accent ? lime.withValues(alpha: 0.35) : Colors.white.withValues(alpha: 0.07),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: accent ? lime.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accent ? lime : Colors.white70, size: 22),
            ),
            const SizedBox(height: 14),
            Text(label, style: TextStyle(
              color: accent ? lime : Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            )),
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
              height: 1.4,
            )),
          ],
        ),
      ),
    );
  }
}

class _MyQrView extends StatelessWidget {
  const _MyQrView({required this.onBack});
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    final user = auth.user!;
    final s = AppStrings.of(context);
    const lime = Color(0xFFB8F55E);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 36, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: Colors.white12, borderRadius: BorderRadius.circular(2)),
        ),
        Row(
          children: [
            GestureDetector(
              onTap: onBack,
              child: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white54, size: 18),
            ),
            const SizedBox(width: 12),
            Text(s.qrShowOption, style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            )),
          ],
        ),
        const SizedBox(height: 28),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: lime.withValues(alpha: 0.20),
                blurRadius: 40,
                spreadRadius: 4,
              ),
            ],
          ),
          child: QrImageView(
            data: user.id,
            version: QrVersions.auto,
            size: 220,
            backgroundColor: Colors.white,
            eyeStyle: const QrEyeStyle(
              eyeShape: QrEyeShape.square,
              color: Color(0xFF0F0F12),
            ),
            dataModuleStyle: const QrDataModuleStyle(
              dataModuleShape: QrDataModuleShape.square,
              color: Color(0xFF0F0F12),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          s.qrMemberId,
          style: const TextStyle(color: Colors.white38, fontSize: 12, letterSpacing: 1.5),
        ),
        const SizedBox(height: 4),
        Text(
          '#${user.id.toUpperCase().replaceAll('-', '').substring(0, 8)}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.qrPresent,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white30, fontSize: 12, height: 1.5),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
