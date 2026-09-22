import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../widgets/omni_design.dart';

class QrCheckinScreen extends StatefulWidget {
  const QrCheckinScreen({super.key, this.gymName});
  final String? gymName;

  @override
  State<QrCheckinScreen> createState() => _QrCheckinScreenState();
}

class _QrCheckinScreenState extends State<QrCheckinScreen>
    with SingleTickerProviderStateMixin {
  final _ctrl = MobileScannerController();
  bool _processing = false;
  bool _torchOn = false;

  late final AnimationController _scanAnim;
  late final Animation<double> _scanPos;

  @override
  void initState() {
    super.initState();
    _scanAnim = AnimationController(vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat(reverse: true);
    _scanPos = CurvedAnimation(parent: _scanAnim, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _scanAnim.dispose();
    _ctrl.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) async {
    if (_processing) return;
    final barcode = capture.barcodes.firstOrNull;
    if (barcode?.rawValue == null) return;

    setState(() => _processing = true);
    await _ctrl.stop();

    if (mounted) {
      Navigator.pushReplacement(context,
        MaterialPageRoute(builder: (_) => QrSuccessScreen(
          gymName: widget.gymName ?? 'Gym',
          rawValue: barcode!.rawValue!,
        )));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Camera feed
          MobileScanner(controller: _ctrl, onDetect: _onDetect),

          // Dark overlay with vignette
          Container(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.center,
                radius: 1.0,
                colors: [
                  Colors.transparent,
                  kBg.withValues(alpha: 0.2),
                  kBg.withValues(alpha: 0.85),
                ],
                stops: const [0.0, 0.45, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Column(
              children: [
                // Top bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 56, 20, 8),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _GlassButton(
                        child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                        onTap: () => Navigator.maybePop(context),
                      ),
                      Text('Scan to Enter', style: GoogleFonts.spaceGrotesk(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.45)),
                      _GlassButton(
                        child: Icon(
                          _torchOn ? Icons.flash_on : Icons.flash_off,
                          color: Colors.white, size: 20),
                        onTap: () {
                          setState(() => _torchOn = !_torchOn);
                          _ctrl.toggleTorch();
                        },
                      ),
                    ],
                  ),
                ),

                // Subtitle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    'Scan the QR code at the gym entrance to check in.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: kGray, height: 1.4),
                  ),
                ),

                // Scanner viewfinder
                const Spacer(),
                SizedBox(
                  width: 256, height: 256,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      // Corner brackets
                      CustomPaint(painter: _ScannerCornersPainter()),

                      // Lime glow center
                      Center(
                        child: Container(
                          width: 208, height: 208,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            gradient: RadialGradient(
                              colors: [
                                kLime.withValues(alpha: 0.05),
                                Colors.transparent,
                              ],
                              stops: const [0.0, 0.7],
                            ),
                          ),
                        ),
                      ),

                      // Animated scan line
                      AnimatedBuilder(
                        animation: _scanPos,
                        builder: (_, __) {
                          final y = 24 + (_scanPos.value * (256 - 48));
                          return Positioned(
                            left: 12, right: 12,
                            top: y,
                            child: Container(
                              height: 2,
                              decoration: BoxDecoration(
                                color: kLime.withValues(alpha: 0.9),
                                borderRadius: BorderRadius.circular(9999),
                                boxShadow: [
                                  BoxShadow(color: kLime.withValues(alpha: 0.7), blurRadius: 12, spreadRadius: 2),
                                  BoxShadow(color: kLime.withValues(alpha: 0.3), blurRadius: 24, spreadRadius: 4),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Bottom controls
                Padding(
                  padding: const EdgeInsets.only(bottom: 40),
                  child: Column(
                    children: [
                      // Gym name pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(9999),
                          border: Border.all(color: kBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on_outlined, color: Colors.white, size: 14),
                            const SizedBox(width: 8),
                            Text(widget.gymName ?? 'Select Gym', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Flash/settings button
                      Container(
                        width: 64, height: 64,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1F2024),
                          shape: BoxShape.circle,
                          border: Border.all(color: kBorder2),
                        ),
                        child: IconButton(
                          icon: Icon(_torchOn ? Icons.flash_on : Icons.flash_off,
                            color: Colors.white, size: 22),
                          onPressed: () {
                            setState(() => _torchOn = !_torchOn);
                            _ctrl.toggleTorch();
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  const _GlassButton({required this.child, required this.onTap});
  final Widget child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44, height: 44,
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.5),
          shape: BoxShape.circle,
          border: Border.all(color: kBorder),
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _ScannerCornersPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    const arm = 48.0;
    const thick = 4.0;
    const radius = 16.0;

    final paint = Paint()
      ..color = kLime
      ..strokeWidth = thick
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glow = Paint()
      ..color = kLime.withValues(alpha: 0.6)
      ..strokeWidth = thick + 8
      ..style = PaintingStyle.stroke
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    final corners = [
      // TL
      [Offset(0, arm), Offset(0, radius), Offset(arm, 0)],
      // TR
      [Offset(size.width - arm, 0), Offset(size.width - radius, 0),
        Offset(size.width, arm)],
      // BL
      [Offset(0, size.height - arm), Offset(0, size.height - radius),
        Offset(arm, size.height)],
      // BR
      [Offset(size.width - arm, size.height), Offset(size.width - radius, size.height),
        Offset(size.width, size.height - arm)],
    ];

    for (final pts in corners) {
      final path = Path()
        ..moveTo(pts[0].dx, pts[0].dy)
        ..lineTo(pts[1].dx, pts[1].dy)
        ..lineTo(pts[2].dx, pts[2].dy);
      canvas.drawPath(path, glow);
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_ScannerCornersPainter old) => false;
}

// ── QR Success screen ─────────────────────────────────────────────────────────
class QrSuccessScreen extends StatefulWidget {
  const QrSuccessScreen({super.key, required this.gymName, required this.rawValue});
  final String gymName;
  final String rawValue;

  @override
  State<QrSuccessScreen> createState() => _QrSuccessScreenState();
}

class _QrSuccessScreenState extends State<QrSuccessScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _scale = CurvedAnimation(parent: _ctrl, curve: Curves.elasticOut);
    _fade  = CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);

    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    });
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: OmniBgPainter()),
          const OmniCornerBrackets(),
          FadeTransition(
            opacity: _fade,
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ScaleTransition(
                      scale: _scale,
                      child: Container(
                        width: 96, height: 96,
                        decoration: BoxDecoration(
                          color: kLime.withValues(alpha: 0.12),
                          shape: BoxShape.circle,
                          border: Border.all(color: kLime.withValues(alpha: 0.4), width: 2),
                          boxShadow: [
                            BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 40),
                          ],
                        ),
                        child: const Icon(Icons.check, color: kLime, size: 40),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text('Access Granted', style: GoogleFonts.spaceGrotesk(
                      fontSize: 30, fontWeight: FontWeight.w700,
                      color: Colors.white, letterSpacing: -0.75)),
                    const SizedBox(height: 12),
                    Text(widget.gymName, style: GoogleFonts.manrope(
                      fontSize: 16, color: kGray, height: 1.5)),
                    const SizedBox(height: 8),
                    Text('Welcome! Enjoy your workout.',
                      style: GoogleFonts.manrope(fontSize: 14, color: kDim)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
