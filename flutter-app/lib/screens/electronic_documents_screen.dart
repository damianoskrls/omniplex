import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';

class ElectronicDocumentsScreen extends StatefulWidget {
  const ElectronicDocumentsScreen.gym({super.key, required this.apiBase, required this.token})
      : global = false;

  const ElectronicDocumentsScreen.global({super.key, required this.apiBase, required this.token})
      : global = true;

  final String apiBase;
  final String token;
  final bool global;

  @override
  State<ElectronicDocumentsScreen> createState() => _ElectronicDocumentsScreenState();
}

class _ElectronicDocumentsScreenState extends State<ElectronicDocumentsScreen> {
  List<Map<String, dynamic>> _docs = [];
  bool _loading = true;

  String get _listPath => widget.global ? '/global/me/documents' : '/gdpr/mine';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(
        Uri.parse('${widget.apiBase}$_listPath'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body);
        _docs = (body as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Ηλεκτρονικές εγγραφές')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _docs.isEmpty
                  ? ListView(children: const [
                      SizedBox(height: 80),
                      Center(child: Text('Δεν υπάρχουν έγγραφα για υπογραφή', style: TextStyle(color: AppColors.textSecondary))),
                    ])
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _docs.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final doc = _docs[i];
                        final signed = doc['signed_at'] != null;
                        return ListTile(
                          tileColor: AppColors.surface,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          title: Text(doc['title']?.toString() ?? 'Έγγραφο', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                          subtitle: Text(
                            '${doc['gym_name'] ?? ''} · ${signed ? 'Υπογεγραμμένο' : 'Εκκρεμεί'}',
                            style: const TextStyle(color: AppColors.textSecondary),
                          ),
                          trailing: Icon(signed ? Icons.verified_outlined : Icons.draw_outlined, color: signed ? AppColors.lime : Colors.white70),
                          onTap: () async {
                            await Navigator.push(context, MaterialPageRoute(
                              builder: (_) => _DocumentSignPage(
                                apiBase: widget.apiBase,
                                token: widget.token,
                                global: widget.global,
                                id: doc['id'].toString(),
                                alreadySigned: signed,
                              ),
                            ));
                            _load();
                          },
                        );
                      },
                    ),
            ),
    );
  }
}

class _DocumentSignPage extends StatefulWidget {
  const _DocumentSignPage({
    required this.apiBase,
    required this.token,
    required this.global,
    required this.id,
    required this.alreadySigned,
  });

  final String apiBase;
  final String token;
  final bool global;
  final String id;
  final bool alreadySigned;

  @override
  State<_DocumentSignPage> createState() => _DocumentSignPageState();
}

class _DocumentSignPageState extends State<_DocumentSignPage> {
  Map<String, dynamic>? _doc;
  String? _error;
  bool _agreed = false;
  bool _sending = false;
  final _points = <Offset?>[];
  final _padKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.global ? '/global/me/documents/${widget.id}' : '/gdpr/mine/${widget.id}';
    try {
      final res = await http.get(
        Uri.parse('${widget.apiBase}$path'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) {
        _error = body['error']?.toString() ?? 'Σφάλμα';
      } else {
        _doc = Map<String, dynamic>.from(body as Map);
      }
    } catch (_) {
      _error = 'Σφάλμα σύνδεσης';
    }
    if (mounted) setState(() {});
  }

  Future<void> _submit() async {
    if (_points.whereType<Offset>().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Υπόγραψε στο πλαίσιο')));
      return;
    }
    setState(() => _sending = true);
    try {
      final boundary = _padKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dataUrl = 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
      final path = widget.global ? '/global/me/documents/${widget.id}/sign' : '/gdpr/mine/${widget.id}/sign';
      final res = await http.post(
        Uri.parse('${widget.apiBase}$path'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'signature_data': dataUrl}),
      );
      if (!mounted) return;
      if (res.statusCode == 200) {
        Navigator.pop(context);
      } else {
        final body = jsonDecode(res.body);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(body['error']?.toString() ?? 'Αποτυχία')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Αποτυχία υπογραφής')));
      }
    }
    if (mounted) setState(() => _sending = false);
  }

  @override
  Widget build(BuildContext context) {
    final doc = _doc;
    final signed = widget.alreadySigned || doc?['signed_at'] != null;
    final text = (doc?['gdpr_text'] ?? doc?['body'] ?? '').toString();
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(doc?['title']?.toString() ?? 'Έγγραφο')),
      body: _error != null
          ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
          : doc == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(doc['gym_name']?.toString() ?? '', style: const TextStyle(color: AppColors.textSecondary)),
                    const SizedBox(height: 8),
                    Text(doc['full_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 18)),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14)),
                      child: Text(text.replaceAll('**', ''), style: const TextStyle(color: Colors.white70, height: 1.5)),
                    ),
                    if (!signed) ...[
                      const SizedBox(height: 16),
                      const Text('Υπογραφή', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      RepaintBoundary(
                        key: _padKey,
                        child: GestureDetector(
                          onPanStart: (d) => setState(() => _points.add(d.localPosition)),
                          onPanUpdate: (d) => setState(() => _points.add(d.localPosition)),
                          onPanEnd: (_) => setState(() => _points.add(null)),
                          child: Container(
                            height: 140,
                            width: double.infinity,
                            color: Colors.white,
                            child: CustomPaint(painter: _SigPainter(_points)),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => setState(_points.clear),
                        child: const Text('Εκκαθάριση'),
                      ),
                      CheckboxListTile(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        title: const Text(
                          'Διάβασα το κείμενο, συναινώ στην επεξεργασία των δεδομένων μου και αποδέχομαι την ηλεκτρονική υπογραφή.',
                          style: TextStyle(color: Colors.white70, fontSize: 13),
                        ),
                        controlAffinity: ListTileControlAffinity.leading,
                      ),
                      FilledButton(
                        onPressed: _sending || !_agreed ? null : _submit,
                        child: Text(_sending ? 'Αποστολή…' : 'Υπογραφή'),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.only(top: 20),
                        child: Text('Το έγγραφο έχει υπογραφεί.', style: TextStyle(color: Colors.white)),
                      ),
                  ],
                ),
    );
  }
}

class _SigPainter extends CustomPainter {
  _SigPainter(this.points);
  final List<Offset?> points;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF111111)
      ..strokeWidth = 2.4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (a != null && b != null) canvas.drawLine(a, b, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SigPainter oldDelegate) => true;
}
