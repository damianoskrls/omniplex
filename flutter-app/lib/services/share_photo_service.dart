import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../models/workout_share_details.dart';

class SharePhotoService {
  Future<Uint8List?> loadLogoBytes({
    String logoAssetPath = 'assets/logo.png',
    String? logoUrl,
    String apiBaseUrl = 'http://localhost:3001',
  }) async {
    if (logoUrl != null && logoUrl.isNotEmpty) {
      try {
        final base = apiBaseUrl.replaceAll(RegExp(r'/$'), '');
        final uri = logoUrl.startsWith('http') ? Uri.parse(logoUrl) : Uri.parse('$base$logoUrl');
        final res = await http.get(uri).timeout(const Duration(seconds: 5));
        if (res.statusCode == 200) return res.bodyBytes;
      } catch (_) {}
    }
    try {
      final data = await rootBundle.load(logoAssetPath);
      return data.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }

  Future<File?> composeWorkoutShare({
    required Uint8List photoBytes,
    required WorkoutShareDetails details,
    Uint8List? logoBytes,
  }) async {
    final photo = await _decodeUiImage(photoBytes);
    if (photo == null) return null;

    final w = photo.width;
    final h = photo.height;
    final scale = w / 1080.0;
    final pad = 28.0 * scale;
    final lineGap = 10.0 * scale;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble()));

    canvas.drawImage(photo, Offset.zero, Paint());

    // Top-left gradient (Strava-style readability)
    final topGrad = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(w * 0.85, h * 0.55),
        [
          const Color(0xCC000000),
          const Color(0x66000000),
          const Color(0x00000000),
        ],
        [0.0, 0.45, 1.0],
      );
    canvas.drawRect(Rect.fromLTWH(0, 0, w.toDouble(), h * 0.55), topGrad);

    // Bottom gradient for branding (taller for larger logo)
    final bottomGrad = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, h * 0.62),
        Offset(0, h.toDouble()),
        [const Color(0x00000000), const Color(0xBB000000)],
      );
    canvas.drawRect(Rect.fromLTWH(0, h * 0.62, w.toDouble(), h * 0.38), bottomGrad);

    double y = pad;
    final accent = _colorFromHex(details.accentColorHex);
    y = _drawLabel(canvas, 'ΠΡΟΠΟΝΗΣΗ', pad, y, 18 * scale, accent, letterSpacing: 1.2);
    y += lineGap * 0.4;
    y = _drawLabel(canvas, details.workoutTitle.toUpperCase(), pad, y, 40 * scale, Colors.white, bold: true, maxWidth: w - pad * 2);
    y += lineGap;

    y = _drawLabel(canvas, _capitalize(details.dateLine), pad, y, 26 * scale, Colors.white.withValues(alpha: 0.95));
    y = _drawLabel(canvas, details.timeLine, pad, y, 34 * scale, Colors.white, bold: true);

    // Bottom branding: logo above gym name, measured to avoid overlap
    final gymFontSize = 24 * scale;
    final brandGap = 14 * scale;
    final gymName = details.gymName;
    final gymHeight = _textHeight(gymName, gymFontSize, bold: true, maxWidth: w - pad * 2);
    final gymBottom = h - pad;
    final gymTop = gymBottom - gymHeight;

    if (logoBytes != null) {
      final logoImg = await _decodeUiImage(logoBytes);
      if (logoImg != null) {
        final logoW = (w * 0.26).clamp(88.0, 220.0);
        final logoH = logoW * logoImg.height / logoImg.width;
        final logoTop = gymTop - brandGap - logoH;
        canvas.drawImageRect(
          logoImg,
          Rect.fromLTWH(0, 0, logoImg.width.toDouble(), logoImg.height.toDouble()),
          Rect.fromLTWH(pad, logoTop, logoW, logoH),
          Paint(),
        );
        logoImg.dispose();
      }
    }

    _drawLabel(
      canvas,
      gymName,
      pad,
      gymBottom,
      gymFontSize,
      Colors.white,
      bold: true,
      maxWidth: w - pad * 2,
      bottomAlign: true,
    );

    final picture = recorder.endRecording();
    final composed = await picture.toImage(w, h);
    photo.dispose();

    final pngBytes = await composed.toByteData(format: ui.ImageByteFormat.png);
    composed.dispose();
    if (pngBytes == null) return null;

    final decoded = img.decodeImage(pngBytes.buffer.asUint8List());
    if (decoded == null) return null;
    final jpg = img.encodeJpg(decoded, quality: 92);

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/workout_share_${DateTime.now().millisecondsSinceEpoch}.jpg');
    await file.writeAsBytes(jpg);
    return file;
  }

  Future<File?> watermarkAndSave({
    required Uint8List photoBytes,
    required WorkoutShareDetails details,
    Uint8List? logoBytes,
  }) => composeWorkoutShare(photoBytes: photoBytes, details: details, logoBytes: logoBytes);

  /// Shares only the image file so Instagram Stories can pick it up.
  Future<void> shareWorkoutPhoto(File file, {Rect? sharePositionOrigin}) async {
    await Share.shareXFiles(
      [
        XFile(
          file.path,
          mimeType: 'image/jpeg',
          name: 'workout_share.jpg',
        ),
      ],
      sharePositionOrigin: sharePositionOrigin,
    );
  }

  Future<void> saveToGallery(File file) async {
    final hasAccess = await Gal.hasAccess(toAlbum: true);
    if (!hasAccess) {
      await Gal.requestAccess(toAlbum: true);
    }
    await Gal.putImage(file.path, album: 'Handstand');
  }

  Future<ui.Image?> _decodeUiImage(Uint8List bytes) async {
    try {
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      return frame.image;
    } catch (_) {
      return null;
    }
  }

  double _textHeight(
    String text,
    double fontSize, {
    bool bold = false,
    double maxWidth = double.infinity,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        maxLines: 2,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: Colors.white,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
      ))
      ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth == double.infinity ? 1e9 : maxWidth));
    return paragraph.height;
  }

  double _drawLabel(
    Canvas canvas,
    String text,
    double x,
    double y,
    double fontSize,
    Color color, {
    bool bold = false,
    double letterSpacing = 0,
    double maxWidth = double.infinity,
    bool bottomAlign = false,
  }) {
    final builder = ui.ParagraphBuilder(
      ui.ParagraphStyle(
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        maxLines: 3,
      ),
    )
      ..pushStyle(ui.TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: bold ? FontWeight.w800 : FontWeight.w500,
        letterSpacing: letterSpacing,
      ))
      ..addText(text);

    final paragraph = builder.build()
      ..layout(ui.ParagraphConstraints(width: maxWidth == double.infinity ? 1e9 : maxWidth));

    final height = paragraph.height;
    final drawY = bottomAlign ? y - height : y;
    canvas.drawParagraph(paragraph, Offset(x, drawY));
    return bottomAlign ? y : y + height;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }

  Color _colorFromHex(String hex) {
    var h = hex.replaceAll('#', '');
    if (h.length == 6) h = 'FF$h';
    final value = int.tryParse(h, radix: 16);
    if (value == null) return const Color(0xFFB8F55E);
    return Color(value);
  }
}
