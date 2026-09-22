import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// ── Design tokens ─────────────────────────────────────────────────────────────
const kBg     = Color(0xFF0A0A0A);
const kLime   = Color(0xFFC6FF3D);
const kCyan   = Color(0xFF3EE6FF);
const kGray   = Color(0xFF9A9CA3);
const kDim    = Color(0xFF5A5C63);
const kCard   = Color(0xFF16171B);
const kBorder = Color(0xFF2A2B30);
const kBorder2 = Color(0xFF3A3C42);

// ── Top navigation bar ────────────────────────────────────────────────────────
class OmniTopNav extends StatelessWidget {
  const OmniTopNav({super.key, this.onBack, this.trailing});
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (onBack != null)
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kCard,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
            ),
          )
        else
          const SizedBox(width: 44),
        const OmniLogo(),
        trailing ?? const SizedBox(width: 44),
      ],
    );
  }
}

// ── OMNI PLEX logo ────────────────────────────────────────────────────────────
class OmniLogo extends StatelessWidget {
  const OmniLogo({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 32, height: 32,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 6, height: 6,
                decoration: BoxDecoration(
                  color: kLime,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.9), blurRadius: 10)],
                ),
              ),
              Container(
                width: 24, height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kLime.withValues(alpha: 0.9), width: 1.5),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        RichText(
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.35),
            children: const [
              TextSpan(text: 'OMNI', style: TextStyle(color: Colors.white)),
              TextSpan(text: 'PLEX', style: TextStyle(color: kLime)),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Input field ───────────────────────────────────────────────────────────────
class OmniField extends StatelessWidget {
  const OmniField({
    super.key,
    required this.label,
    required this.child,
    this.prefix,
    this.suffix,
    this.focusNode,
    this.active = false,
  });
  final String label;
  final Widget child;
  final Widget? prefix;
  final Widget? suffix;
  final FocusNode? focusNode;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final focused = active || (focusNode?.hasFocus ?? false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: kGray, letterSpacing: 1.65)),
        const SizedBox(height: 8),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: focused ? kLime : kBorder),
            boxShadow: focused ? [
              BoxShadow(color: kLime.withValues(alpha: 0.12), blurRadius: 0, spreadRadius: 3),
            ] : null,
          ),
          child: Row(
            children: [
              if (prefix != null) prefix!,
              Expanded(child: child),
              if (suffix != null) suffix!,
            ],
          ),
        ),
      ],
    );
  }
}

// ── Phone country prefix ──────────────────────────────────────────────────────
class OmniPhonePrefix extends StatelessWidget {
  const OmniPhonePrefix({super.key, this.code = '+1'});
  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      decoration: const BoxDecoration(
        border: Border(right: BorderSide(color: kBorder)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(code, style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w600,
            color: Colors.white, letterSpacing: 1.07)),
          const SizedBox(width: 8),
          const Icon(Icons.keyboard_arrow_down, color: kGray, size: 16),
        ],
      ),
    );
  }
}

// ── Lime CTA button ───────────────────────────────────────────────────────────
class OmniLimeButton extends StatelessWidget {
  const OmniLimeButton({
    super.key,
    required this.label,
    required this.onTap,
    this.loading = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: kLime,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 12)],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: loading
              ? [const SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: kBg, strokeWidth: 2))]
              : [
                  Text(label, style: GoogleFonts.spaceGrotesk(
                    fontSize: 16, fontWeight: FontWeight.w700,
                    color: kBg, letterSpacing: -0.4)),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward, color: kBg, size: 18),
                ],
        ),
      ),
    );
  }
}

// ── Outline button ────────────────────────────────────────────────────────────
class OmniOutlineButton extends StatelessWidget {
  const OmniOutlineButton({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.iconWidget,
  });
  final String label;
  final VoidCallback onTap;
  final IconData? icon;
  final Widget? iconWidget;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: kBorder2),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (iconWidget != null) iconWidget!
            else if (icon != null) Icon(icon, color: Colors.white, size: 22),
            const SizedBox(width: 12),
            Text(label, style: GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w600, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}

// ── Error banner ──────────────────────────────────────────────────────────────
class OmniErrorBanner extends StatelessWidget {
  const OmniErrorBanner({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2D0F0F),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF5C1A1A)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 16),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: GoogleFonts.manrope(
            fontSize: 13, color: const Color(0xFFEF4444)))),
        ],
      ),
    );
  }
}

// ── Dark background gradient painter ─────────────────────────────────────────
class OmniBgPainter extends CustomPainter {
  const OmniBgPainter({this.cyanOffset});
  final Offset? cyanOffset;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawCircle(
      Offset(size.width / 2, 0),
      size.width * 0.88,
      Paint()
        ..shader = RadialGradient(colors: [
          kLime.withValues(alpha: 0.12),
          kLime.withValues(alpha: 0.04),
          Colors.transparent,
        ], stops: const [0.0, 0.3, 0.55]).createShader(
          Rect.fromCircle(center: Offset(size.width / 2, 0), radius: size.width * 0.88),
        ),
    );
    final cyan = cyanOffset ?? Offset(size.width - 16, 96);
    canvas.drawCircle(
      cyan,
      64,
      Paint()
        ..shader = RadialGradient(colors: [
          kCyan.withValues(alpha: 0.08),
          Colors.transparent,
        ], stops: const [0.0, 0.7]).createShader(
          Rect.fromCircle(center: cyan, radius: 64),
        ),
    );
  }

  @override
  bool shouldRepaint(OmniBgPainter old) => false;
}

// ── Corner brackets ───────────────────────────────────────────────────────────
class OmniCornerBrackets extends StatelessWidget {
  const OmniCornerBrackets({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Stack(
          fit: StackFit.expand,
          children: const [
            Align(alignment: Alignment.topLeft,     child: _Bracket(corner: _BC.topLeft)),
            Align(alignment: Alignment.topRight,    child: _Bracket(corner: _BC.topRight)),
            Align(alignment: Alignment.bottomLeft,  child: _Bracket(corner: _BC.bottomLeft)),
            Align(alignment: Alignment.bottomRight, child: _Bracket(corner: _BC.bottomRight)),
          ],
        ),
      ),
    );
  }
}

enum _BC { topLeft, topRight, bottomLeft, bottomRight }

class _Bracket extends StatelessWidget {
  const _Bracket({required this.corner});
  final _BC corner;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 24, height: 24,
      child: CustomPaint(painter: _BracketPainter(corner: corner)),
    );
  }
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter({required this.corner});
  final _BC corner;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = kBorder
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final showTop    = corner == _BC.topLeft || corner == _BC.topRight;
    final showBottom = corner == _BC.bottomLeft || corner == _BC.bottomRight;
    final showLeft   = corner == _BC.topLeft || corner == _BC.bottomLeft;
    final showRight  = corner == _BC.topRight || corner == _BC.bottomRight;

    if (showTop)    canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
    if (showBottom) canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), paint);
    if (showLeft)   canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    if (showRight)  canvas.drawLine(Offset(size.width, 0), Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

// ── Section label ─────────────────────────────────────────────────────────────
class OmniLabel extends StatelessWidget {
  const OmniLabel(this.text, {super.key});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(text.toUpperCase(), style: GoogleFonts.spaceGrotesk(
      fontSize: 11, color: kGray, letterSpacing: 1.65));
  }
}

// ── Bottom tab bar ────────────────────────────────────────────────────────────
class OmniBottomNav extends StatelessWidget {
  const OmniBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });
  final List<OmniNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 80,
      decoration: const BoxDecoration(
        color: kCard,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            final item = items[i];
            final active = i == currentIndex;
            return GestureDetector(
              onTap: () => onTap(i),
              behavior: HitTestBehavior.opaque,
              child: SizedBox(
                width: 64,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(active ? item.activeIcon : item.icon,
                      color: active ? kLime : kGray, size: 22),
                    const SizedBox(height: 4),
                    Text(item.label, style: GoogleFonts.spaceGrotesk(
                      fontSize: 10,
                      color: active ? kLime : kGray,
                      letterSpacing: 0.5,
                    )),
                    if (active) ...[
                      const SizedBox(height: 4),
                      Container(
                        width: 4, height: 4,
                        decoration: BoxDecoration(
                          color: kLime,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: kLime.withValues(alpha: 0.8), blurRadius: 6)],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class OmniNavItem {
  const OmniNavItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

// ── Chip / pill tag ───────────────────────────────────────────────────────────
class OmniChip extends StatelessWidget {
  const OmniChip({
    super.key,
    required this.label,
    this.active = false,
    this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? kLime.withValues(alpha: 0.12) : kCard,
          borderRadius: BorderRadius.circular(9999),
          border: Border.all(color: active ? kLime.withValues(alpha: 0.5) : kBorder),
        ),
        child: Text(label, style: GoogleFonts.spaceGrotesk(
          fontSize: 11,
          color: active ? kLime : kGray,
          fontWeight: active ? FontWeight.w600 : FontWeight.w400,
          letterSpacing: 0.3,
        )),
      ),
    );
  }
}
