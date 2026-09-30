import 'dart:convert';

import 'package:flutter/material.dart';
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
      if (body is Map && body['intake_completed'] == true) return;
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
        }
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

  Future<void> _saveHealth({bool pop = false}) async {
    setState(() => _saving = true);
    try {
      final res = await http.put(
        Uri.parse('$_root/health'),
        headers: _headers,
        body: jsonEncode({
          'has_conditions': _hasConditions,
          'conditions_text': _conditions.text,
          'takes_medication': _takesMedication,
          'medication_text': _medication.text,
        }),
      );
      if (res.statusCode != 200) {
        final body = jsonDecode(res.body);
        throw body['error']?.toString() ?? 'Αποτυχία';
      }
      if (pop && mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
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
      OutlinedButton.icon(
        onPressed: _saving ? null : _pickDocument,
        icon: const Icon(Icons.upload_file_outlined),
        label: Text(_documentName == null ? 'Φωτογραφία εγγράφου γιατρού' : _documentName!),
      ),
      const SizedBox(height: 16),
      FilledButton(
        onPressed: _saving ? null : () => _saveHealth(pop: true),
        child: Text(_saving ? 'Αποθήκευση…' : 'Αποθήκευση'),
      ),
    ];
  }
}
