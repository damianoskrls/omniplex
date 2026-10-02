import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../l10n/tr.dart';


const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

/// Full-screen intro shown when opening a gym: its photo, then logo and name.
Future<void> showGymEntrySplash(
  BuildContext context, {
  required String name,
  required String slug,
  String? logoUrl,
  String? coverUrl,
}) {
  return Navigator.of(context).push(PageRouteBuilder(
    opaque: true,
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (_, _, _) => _GymEntrySplash(
      name: name,
      slug: slug,
      logoUrl: logoUrl,
      coverUrl: coverUrl,
    ),
  ));
}

class _GymEntrySplash extends StatefulWidget {
  const _GymEntrySplash({
    required this.name,
    required this.slug,
    this.logoUrl,
    this.coverUrl,
  });

  final String name;
  final String slug;
  final String? logoUrl;
  final String? coverUrl;

  @override
  State<_GymEntrySplash> createState() => _GymEntrySplashState();
}

class _GymEntrySplashState extends State<_GymEntrySplash> {
  String? _logo;
  String? _cover;

  @override
  void initState() {
    super.initState();
    _logo = widget.logoUrl;
    _cover = widget.coverUrl;
    _load();
  }

  Future<void> _load() async {
    if ((_cover == null || _cover!.isEmpty) && widget.slug.isNotEmpty) {
      try {
        final res = await http.get(Uri.parse('$_apiBase/global/discovery/gyms/${widget.slug}'));
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          _cover = body['cover_url'] as String? ?? _cover;
          _logo = (body['logo_url'] as String?) ?? _logo;
          if (mounted) setState(() {});
        }
      } catch (_) {}
    }
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final cover = _cover;
    final logo = _logo;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (cover != null && cover.isNotEmpty)
            Image.network(cover, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink())
          else
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF1A1A22), Color(0xFF0A0A0A)],
                ),
              ),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0x66000000), Color(0xE6000000)],
              ),
            ),
          ),
          Center(
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
                      errorBuilder: (_, _, _) => _mark(),
                    ),
                  )
                else
                  _mark(),
                const SizedBox(height: 18),
                Text(
                  tr(widget.name),
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _mark() {
    return Container(
      width: 88,
      height: 88,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        tr(widget.name.isEmpty ? 'G' : widget.name.characters.first.toUpperCase()),
        style: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w800, color: const Color(0xFF7B3EAD)),
      ),
    );
  }
}
