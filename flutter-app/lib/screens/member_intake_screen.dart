import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class MemberIntakeScreen extends StatefulWidget {
  const MemberIntakeScreen({super.key, required this.apiBase, required this.token, required this.bizId});

  static bool _prompted = false;

  static Future<void> promptIfNeeded(BuildContext context) async {
    if (_prompted) return;
    final auth = context.read<AuthService>();
    final user = auth.user;
    if (user == null || user.isStaff) return;
    _prompted = true;
    final base = auth.config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
    try {
      final res = await http.get(
        Uri.parse('$base/api/member/${auth.config.businessId}'),
        headers: {'Authorization': 'Bearer ${auth.api.token ?? ''}'},
      );
      if (!context.mounted || res.statusCode != 200) return;
      final body = jsonDecode(res.body);
      final signed = body is Map && body['health'] is Map && body['health']['signed_at'] != null;
      if (body is Map && body['intake_completed'] == true && signed) return;
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => MemberIntakeScreen(
          apiBase: '$base/api',
          token: auth.api.token ?? '',
          bizId: auth.config.businessId,
        ),
      ));
    } catch (_) {}
  }

  final String apiBase;
  final String token;
  final String bizId;

  @override
  State<MemberIntakeScreen> createState() => _MemberIntakeScreenState();
}

class _MemberIntakeScreenState extends State<MemberIntakeScreen> {
  int _step = 0;
  bool _loading = true;
  bool _saving = false;
  String? _error;
  List<Map<String, String>> _goals = [];
  String _goal = 'general';
  String _experience = 'beginner';
  int _visits = 3;
  final _motivation = TextEditingController();
  final _goalText = TextEditingController();
  bool _hasConditions = false;
  bool _takesMedication = false;
  final _conditions = TextEditingController();
  final _medication = TextEditingController();
  String? _documentName;
  String? _photoUrl;
  String? _signedAt;
  bool _agreed = false;
  final _points = <Offset?>[];
  final _padKey = GlobalKey();

  String get _root => '${widget.apiBase}/member/${widget.bizId}';

  Map<String, String> get _headers => {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _motivation.dispose();
    _goalText.dispose();
    _conditions.dispose();
    _medication.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final res = await http.get(Uri.parse(_root), headers: {'Authorization': 'Bearer ${widget.token}'});
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) {
        _error = body['error']?.toString() ?? 'Σφάλμα';
      } else {
        final goals = (body['goals'] as List?) ?? [];
        _goals = goals.whereType<Map>().map((g) => {
              'id': g['id'].toString(),
              'label': g['label'].toString(),
            }).toList();
        final intake = body['intake'];
        if (intake is Map) {
          _goal = intake['fitness_goal']?.toString() ?? _goal;
          _experience = intake['experience']?.toString() ?? _experience;
          _visits = (intake['visits_per_week'] as num?)?.toInt() ?? _visits;
          _motivation.text = intake['motivation']?.toString() ?? '';
          _goalText.text = intake['goal_text']?.toString() ?? '';
        }
        final health = body['health'];
        if (health is Map) {
          _hasConditions = health['has_conditions'] == 1 || health['has_conditions'] == true;
          _takesMedication = health['takes_medication'] == 1 || health['takes_medication'] == true;
          _conditions.text = health['conditions_text']?.toString() ?? '';
          _medication.text = health['medication_text']?.toString() ?? '';
          _documentName = health['document_name']?.toString();
          _photoUrl = health['photo_url']?.toString();
          _signedAt = health['signed_at']?.toString();
        }
        if (intake is Map && intake['completed_at'] != null) _step = 1;
      }
    } catch (_) {
      _error = 'Σφάλμα σύνδεσης';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveIntake() async {
    setState(() => _saving = true);
    try {
      final res = await http.put(
        Uri.parse('$_root/intake'),
        headers: _headers,
        body: jsonEncode({
          'fitness_goal': _goal,
          'motivation': _motivation.text,
          'goal_text': _goalText.text,
          'experience': _experience,
          'visits_per_week': _visits,
        }),
      );
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body);
        throw body['error']?.toString() ?? 'Αποτυχία';
      }
      if (mounted) setState(() => _step = 1);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  String get _origin => widget.apiBase.replaceAll(RegExp(r'/api$'), '');

  Future<void> _pickPhoto(ImageSource source) async {
    final file = await ImagePicker().pickImage(source: source, imageQuality: 85, maxWidth: 1200);
    if (file == null) return;
    setState(() => _saving = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_root/health/photo'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.files.add(await http.MultipartFile.fromPath(
        'photo',
        file.path,
        contentType: MediaType('image', 'jpeg'),
        filename: 'photo.jpg',
      ));
      final res = await http.Response.fromStream(await request.send());
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) throw body['error']?.toString() ?? 'Αποτυχία φωτογραφίας';
      final url = body['health']?['photo_url']?.toString();
      if (mounted) setState(() => _photoUrl = url);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _signAndClose() async {
    if (_photoUrl == null || _photoUrl!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Βάλε πρώτα μια φωτογραφία σου')));
      return;
    }
    if (!_agreed || _points.whereType<Offset>().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Υπόγραψε και αποδέξου την ηλεκτρονική υπογραφή')));
      return;
    }
    setState(() => _saving = true);
    try {
      final saved = await http.put(
        Uri.parse('$_root/health'),
        headers: _headers,
        body: jsonEncode({
          'has_conditions': _hasConditions,
          'conditions_text': _conditions.text,
          'takes_medication': _takesMedication,
          'medication_text': _medication.text,
        }),
      );
      if (saved.statusCode != 200) {
        final body = jsonDecode(saved.body);
        throw body['error']?.toString() ?? 'Αποτυχία';
      }
      final boundary = _padKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final dataUrl = 'data:image/png;base64,${base64Encode(bytes!.buffer.asUint8List())}';
      final res = await http.post(
        Uri.parse('$_root/health/sign'),
        headers: _headers,
        body: jsonEncode({'signature_data': dataUrl}),
      );
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) throw body['error']?.toString() ?? 'Αποτυχία υπογραφής';
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _pickDocument() async {
    final file = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file == null) return;
    setState(() => _saving = true);
    try {
      final request = http.MultipartRequest('POST', Uri.parse('$_root/health/document'));
      request.headers['Authorization'] = 'Bearer ${widget.token}';
      request.files.add(await http.MultipartFile.fromPath(
        'document',
        file.path,
        contentType: MediaType('image', 'jpeg'),
        filename: file.name,
      ));
      final streamed = await request.send();
      final res = await http.Response.fromStream(streamed);
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body);
        throw body['error']?.toString() ?? 'Αποτυχία ανεβάσματος';
      }
      final body = jsonDecode(res.body);
      final name = body['health']?['document_name']?.toString();
      if (mounted) setState(() => _documentName = name ?? file.name);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text(_step == 0 ? 'Πρώτη εγγραφή' : 'Κάρτα υγείας')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _step == 0 ? _intakeFields() : _healthFields(),
                ),
    );
  }

  List<Widget> _intakeFields() {
    return [
      const Text(
        'Πες μας γιατί έρχεσαι και τι θέλεις να πετύχεις. Το βλέπει μόνο το γυμναστήριο.',
        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      const SizedBox(height: 16),
      const Text('Στόχος', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _goals.map((g) {
          final on = _goal == g['id'];
          return ChoiceChip(
            label: Text(g['label']!),
            selected: on,
            onSelected: (_) => setState(() => _goal = g['id']!),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      TextField(
        controller: _motivation,
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Γιατί έρχεσαι;',
          hintText: 'π.χ. θέλω να ξεκινήσω γυμναστική μετά από καιρό',
        ),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _goalText,
        style: const TextStyle(color: Colors.white),
        maxLines: 3,
        decoration: const InputDecoration(
          labelText: 'Τι στόχο έχεις;',
          hintText: 'π.χ. να χάσω 5 κιλά ή να τρέξω 5 χιλιόμετρα',
        ),
      ),
      const SizedBox(height: 16),
      const Text('Εμπειρία', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Wrap(
        spacing: 8,
        children: const [
          ('beginner', 'Αρχάριος'),
          ('some', 'Κάποια εμπειρία'),
          ('regular', 'Γυμνάζομαι τακτικά'),
        ].map((item) {
          return ChoiceChip(
            label: Text(item.$2),
            selected: _experience == item.$1,
            onSelected: (_) => setState(() => _experience = item.$1),
          );
        }).toList(),
      ),
      const SizedBox(height: 16),
      Text('Φορές την εβδομάδα: $_visits', style: const TextStyle(color: Colors.white)),
      Slider(
        value: _visits.toDouble(),
        min: 1,
        max: 7,
        divisions: 6,
        label: '$_visits',
        onChanged: (v) => setState(() => _visits = v.round()),
      ),
      const SizedBox(height: 8),
      FilledButton(
        onPressed: _saving ? null : _saveIntake,
        child: Text(_saving ? 'Αποθήκευση…' : 'Συνέχεια στην κάρτα υγείας'),
      ),
    ];
  }

  List<Widget> _healthFields() {
    return [
      const Text(
        'Κάρτα υγείας ασκούμενου. Αν έχεις χαρτί γιατρού, ανέβασε φωτογραφία.',
        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
      ),
      SwitchListTile(
        value: _hasConditions,
        onChanged: (v) => setState(() => _hasConditions = v),
        title: const Text('Έχω κάποιο πρόβλημα υγείας', style: TextStyle(color: Colors.white)),
      ),
      if (_hasConditions)
        TextField(
          controller: _conditions,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Τι σε απασχολεί;'),
        ),
      SwitchListTile(
        value: _takesMedication,
        onChanged: (v) => setState(() => _takesMedication = v),
        title: const Text('Παίρνω φάρμακα', style: TextStyle(color: Colors.white)),
      ),
      if (_takesMedication)
        TextField(
          controller: _medication,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Ποια φάρμακα;'),
        ),
      const SizedBox(height: 12),
      if (_photoUrl != null && _photoUrl!.isNotEmpty)
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network('$_origin$_photoUrl', height: 160, width: 120, fit: BoxFit.cover),
        ),
      const SizedBox(height: 8),
      Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickPhoto(ImageSource.camera),
              icon: const Icon(Icons.photo_camera_outlined),
              label: const Text('Βγάλε φωτο'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: _saving ? null : () => _pickPhoto(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('Ανέβασε φωτο'),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      OutlinedButton.icon(
        onPressed: _saving ? null : _pickDocument,
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(_documentName == null ? 'Φωτογραφία εγγράφου γιατρού' : _documentName!),
      ),
      const SizedBox(height: 16),
      const Text('Ηλεκτρονική υπογραφή', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
      if (_signedAt != null)
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Text('Υπάρχει ήδη υπογραφή. Μπορείς να την ανανεώσεις.', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
        ),
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
      TextButton(onPressed: () => setState(_points.clear), child: const Text('Εκκαθάριση')),
      CheckboxListTile(
        value: _agreed,
        onChanged: (v) => setState(() => _agreed = v ?? false),
        contentPadding: EdgeInsets.zero,
        title: const Text(
          'Δηλώνω ότι τα στοιχεία είναι αληθή και αποδέχομαι την ηλεκτρονική υπογραφή της κάρτας υγείας.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        controlAffinity: ListTileControlAffinity.leading,
      ),
      FilledButton(
        onPressed: _saving ? null : _signAndClose,
        child: Text(_saving ? 'Αποθήκευση…' : 'Υπογραφή και αποθήκευση'),
      ),
    ];
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
