import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart' show Share, XFile;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

import '../config/tenant_config.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class WalletCardScreen extends StatefulWidget {
  const WalletCardScreen({super.key, required this.token, required this.fullName, required this.memberId});
  final String token;
  final String fullName;
  final String? memberId;

  @override
  State<WalletCardScreen> createState() => _WalletCardScreenState();
}

class _WalletCardScreenState extends State<WalletCardScreen> {
  final GlobalKey _cardKey = GlobalKey();
  bool _saving = false;

  Future<Uint8List?> _captureCard() async {
    try {
      final boundary = _cardKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (_) { return null; }
  }

  Future<void> _saveToGallery() async {
    setState(() => _saving = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) throw Exception('Αποτυχία δημιουργίας εικόνας');
      await Gal.putImageBytes(bytes, name: 'member_card_${DateTime.now().millisecondsSinceEpoch}.png');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Η κάρτα αποθηκεύτηκε στη γκαλερί'),
            backgroundColor: Color(0xFF16A34A),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _shareCard() async {
    setState(() => _saving = true);
    try {
      final bytes = await _captureCard();
      if (bytes == null) throw Exception('Αποτυχία δημιουργίας εικόνας');
      final tmp = await getTemporaryDirectory();
      final file = File('${tmp.path}/member_card.png');
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([XFile(file.path)], text: 'Η κάρτα μέλους μου');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<TenantConfig>();

    Color primary;
    try {
      primary = Color(int.parse(config.primaryColor.replaceAll('#', '0xFF')));
    } catch (_) {
      primary = AppColors.lime;
    }

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Wallet Card')),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),

            // The card — wrapped in RepaintBoundary for capture
            RepaintBoundary(
              key: _cardKey,
              child: _WalletCard(
                token: widget.token,
                fullName: widget.fullName,
                memberId: widget.memberId,
                gymName: config.appName,
                logoUrl: config.logoUrl,
                primary: primary,
              ),
            ),

            const SizedBox(height: 32),

            // Instructions
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'Αποθήκευσε την κάρτα στη γκαλερί σου και πρόσθεσέ τη στο Wallet.',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
            ),

            const SizedBox(height: 24),

            // Action buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: _ActionBtn(
                      label: 'Αποθήκευση',
                      icon: Icons.download_outlined,
                      color: primary,
                      loading: _saving,
                      onTap: _saveToGallery,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ActionBtn(
                      label: 'Κοινοποίηση',
                      icon: Icons.ios_share_outlined,
                      color: AppColors.surface,
                      textColor: AppColors.textPrimary,
                      loading: _saving,
                      onTap: _shareCard,
                    ),
                  ),
                ],
              ),
            ),

            // iOS Wallet hint
            if (Platform.isIOS) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.wallet, size: 16, color: AppColors.textSecondary),
                    const SizedBox(width: 6),
                    const Text(
                      'Μετά την αποθήκευση, άνοιξε τη φωτογραφία → Μοιραστείτε → Wallet',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WalletCard extends StatelessWidget {
  const _WalletCard({
    required this.token,
    required this.fullName,
    required this.memberId,
    required this.gymName,
    required this.primary,
    this.logoUrl,
  });

  final String token;
  final String fullName;
  final String? memberId;
  final String gymName;
  final String? logoUrl;
  final Color primary;

  Color _contrastColor(Color bg) {
    final l = 0.2126 * _lin(bg.r / 255) +
              0.7152 * _lin(bg.g / 255) +
              0.0722 * _lin(bg.b / 255);
    return l > 0.35 ? const Color(0xFF111111) : Colors.white;
  }

  double _lin(double v) => v <= 0.04045 ? v / 12.92 : ((v + 0.055) / 1.055) * ((v + 0.055) / 1.055);

  @override
  Widget build(BuildContext context) {
    final fg = _contrastColor(primary);
    final fgFaded = fg.withValues(alpha: 0.65);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: AspectRatio(
        aspectRatio: 1.586, // standard card ratio
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primary,
                Color.lerp(primary, Colors.black, 0.3)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: primary.withValues(alpha: 0.4),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Stack(
            children: [
              // Decorative circle top-right
              Positioned(
                right: -30, top: -30,
                child: Container(
                  width: 130, height: 130,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                  ),
                ),
              ),
              Positioned(
                right: 20, top: 10,
                child: Container(
                  width: 70, height: 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
              ),

              // Card content
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top row: gym name + logo
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            gymName,
                            style: TextStyle(
                              color: fg,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        // Gym logo or icon
                        Container(
                          width: 36, height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: logoUrl != null && logoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(logoUrl!, fit: BoxFit.contain,
                                      errorBuilder: (_, __, ___) => _gymIcon(fg)),
                                )
                              : _gymIcon(fg),
                        ),
                      ],
                    ),

                    const Spacer(),

                    // QR code — white container
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: QrImageView(
                            data: token,
                            version: QrVersions.auto,
                            size: 80,
                            backgroundColor: Colors.white,
                            eyeStyle: const QrEyeStyle(
                              eyeShape: QrEyeShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                            dataModuleStyle: const QrDataModuleStyle(
                              dataModuleShape: QrDataModuleShape.square,
                              color: Color(0xFF1A1A2E),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('ΜΕΛΟΣ', style: TextStyle(
                                  color: fgFaded, fontSize: 9, letterSpacing: 1.5)),
                              const SizedBox(height: 4),
                              Text(fullName, style: TextStyle(
                                  color: fg, fontSize: 15, fontWeight: FontWeight.w800)),
                              if (memberId != null && memberId!.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Text('ID · ${memberId!.substring(0, memberId!.length.clamp(0, 8)).toUpperCase()}',
                                    style: TextStyle(
                                        color: fgFaded, fontSize: 10, letterSpacing: 1)),
                              ],
                            ],
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
      ),
    );
  }

  Widget _gymIcon(Color fg) => Icon(Icons.fitness_center, color: fg, size: 20);
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    required this.loading,
    this.textColor,
  });
  final String label;
  final IconData icon;
  final Color color;
  final Color? textColor;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final tc = textColor ?? Colors.white;
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(14),
          border: textColor != null ? Border.all(color: AppColors.border) : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(width: 18, height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: tc))
            else ...[
              Icon(icon, size: 18, color: tc),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: tc, fontWeight: FontWeight.w700, fontSize: 14)),
            ],
          ],
        ),
      ),
    );
  }
}
