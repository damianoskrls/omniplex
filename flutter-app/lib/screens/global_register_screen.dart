import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';

class GlobalRegisterScreen extends StatefulWidget {
  const GlobalRegisterScreen({
    super.key,
    required this.globalAuth,
    required this.onRegistered,
    // If provided, gym search is skipped and this gym is pre-selected
    this.preselectedGym,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onRegistered;
  final Map<String, dynamic>? preselectedGym;

  @override
  State<GlobalRegisterScreen> createState() => _GlobalRegisterScreenState();
}

class _GlobalRegisterScreenState extends State<GlobalRegisterScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passCtrl     = TextEditingController();
  final _confirmCtrl  = TextEditingController();
  final _gymSearchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _obscurePass = true;
  bool _obscureConfirm = true;

  // Gym search
  List<Map<String, dynamic>> _gymResults = [];
  bool _gymSearching = false;
  final List<Map<String, dynamic>> _selectedGyms = [];
  final Map<String, String> _joinStatuses = {}; // slug -> status

  @override
  void initState() {
    super.initState();
    if (widget.preselectedGym != null) {
      _selectedGyms.add(widget.preselectedGym!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    _gymSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchGyms(String q) async {
    if (q.trim().length < 2) {
      setState(() => _gymResults = []);
      return;
    }
    setState(() => _gymSearching = true);
    try {
      final uri = Uri.parse('$_apiBase/global/discovery/gyms').replace(queryParameters: {'q': q.trim()});
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        setState(() {
          _gymResults = (jsonDecode(res.body) as List)
              .cast<Map<String, dynamic>>()
              .where((g) => !_selectedGyms.any((s) => s['id'] == g['id']))
              .toList();
        });
      }
    } catch (_) {}
    if (mounted) setState(() => _gymSearching = false);
  }

  void _addGym(Map<String, dynamic> gym) {
    setState(() {
      if (!_selectedGyms.any((g) => g['id'] == gym['id'])) {
        _selectedGyms.add(gym);
      }
      _gymResults = [];
      _gymSearchCtrl.clear();
    });
  }

  void _removeGym(String id) {
    setState(() {
      _selectedGyms.removeWhere((g) => g['id'] == id);
      _joinStatuses.remove(id);
    });
  }

  Future<void> _register() async {
    final name    = _nameCtrl.text.trim();
    final email   = _emailCtrl.text.trim();
    final phone   = _phoneCtrl.text.trim();
    final pass    = _passCtrl.text;
    final confirm = _confirmCtrl.text;

    if (name.isEmpty || email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Συμπλήρωσε όνομα, email και κωδικό');
      return;
    }
    if (pass != confirm) {
      setState(() => _error = 'Οι κωδικοί δεν ταιριάζουν');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Ο κωδικός πρέπει να έχει τουλάχιστον 6 χαρακτήρες');
      return;
    }

    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.register(
        name, email, pass, phone: phone.isNotEmpty ? phone : null,
      );

      // Send join requests for selected gyms
      for (final gym in _selectedGyms) {
        try {
          final status = await _sendJoinRequest(gym['id'] as String);
          _joinStatuses[gym['id'] as String] = status;
        } catch (_) {}
      }

      if (!mounted) return;
      widget.onRegistered();
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<String> _sendJoinRequest(String businessId) async {
    final token = widget.globalAuth.token;
    final res = await http.post(
      Uri.parse('$_apiBase/global/join-requests'),
      headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
      body: jsonEncode({'business_id': businessId}),
    );
    if (res.statusCode == 200 || res.statusCode == 201) {
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      return body['status'] as String? ?? 'pending';
    }
    return 'error';
  }

  Color _parseColor(String? hex) {
    if (hex == null) return AppColors.lime;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return AppColors.lime; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Εγγραφή',
          style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w800, fontSize: 17),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          if (_error != null)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ),

          _buildField(_nameCtrl,  'Ονοματεπώνυμο', Icons.person_outline_rounded),
          const SizedBox(height: 12),
          _buildField(_emailCtrl, 'Email', Icons.email_outlined, type: TextInputType.emailAddress),
          const SizedBox(height: 12),
          _buildField(_phoneCtrl, 'Κινητό (προαιρετικό)', Icons.phone_outlined, type: TextInputType.phone),
          const SizedBox(height: 12),
          _buildField(
            _passCtrl, 'Κωδικός', Icons.lock_outline_rounded,
            obscure: _obscurePass,
            toggleObscure: () => setState(() => _obscurePass = !_obscurePass),
          ),
          const SizedBox(height: 12),
          _buildField(
            _confirmCtrl, 'Επιβεβαίωση κωδικού', Icons.lock_outline_rounded,
            obscure: _obscureConfirm,
            toggleObscure: () => setState(() => _obscureConfirm = !_obscureConfirm),
          ),

          const SizedBox(height: 28),
          const Text(
            'Γυμναστήρια',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 4),
          Text(
            widget.preselectedGym != null
                ? 'Θα σταλεί αίτημα εγγραφής στο επιλεγμένο γυμναστήριο.'
                : 'Αν είσαι ήδη μέλος ή θέλεις να εγγραφείς σε κάποιο γυμναστήριο, πρόσθεσέ το παρακάτω.',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 12),

          // Selected gyms
          ..._selectedGyms.map((g) {
            final color = _parseColor(g['primary_color'] as String?);
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Center(
                      child: Text(
                        (g['app_name'] as String? ?? g['name'] as String? ?? '?')[0].toUpperCase(),
                        style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      g['app_name'] as String? ?? g['name'] as String? ?? '',
                      style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600, fontSize: 14),
                    ),
                  ),
                  IconButton(
                    onPressed: () => _removeGym(g['id'] as String),
                    icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary, size: 18),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
            );
          }),

          // Gym search input — hidden if gym was pre-selected from profile
          if (widget.preselectedGym == null) TextField(
            controller: _gymSearchCtrl,
            style: const TextStyle(color: AppColors.textPrimary, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Αναζήτηση γυμναστηρίου...',
              hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
              prefixIcon: _gymSearching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(width: 16, height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime)),
                    )
                  : const Icon(Icons.search_rounded, color: AppColors.textSecondary, size: 18),
              filled: true,
              fillColor: AppColors.surfaceLight,
              contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.border)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.lime)),
            ),
            onChanged: _searchGyms,
          ),

          // Gym search results — hidden if gym was pre-selected
          if (widget.preselectedGym == null && _gymResults.isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 4),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: _gymResults.take(5).map((g) {
                  return InkWell(
                    onTap: () => _addGym(g),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      child: Row(
                        children: [
                          const Icon(Icons.fitness_center_rounded, size: 16, color: AppColors.textSecondary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  g['app_name'] as String? ?? g['name'] as String? ?? '',
                                  style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                                ),
                                if ((g['city'] as String?)?.isNotEmpty == true)
                                  Text(g['city'] as String, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                              ],
                            ),
                          ),
                          const Icon(Icons.add_rounded, color: AppColors.lime, size: 18),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

          const SizedBox(height: 32),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _loading ? null : _register,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.lime,
                foregroundColor: AppColors.bg,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: _loading
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                  : const Text('Δημιουργία Λογαριασμού', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController ctrl, String hint, IconData icon, {
    TextInputType type = TextInputType.text,
    bool obscure = false,
    VoidCallback? toggleObscure,
  }) {
    return TextField(
      controller: ctrl,
      style: const TextStyle(color: AppColors.textPrimary),
      keyboardType: type,
      obscureText: obscure,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        prefixIcon: Icon(icon, color: AppColors.textSecondary, size: 20),
        suffixIcon: toggleObscure != null
            ? IconButton(
                onPressed: toggleObscure,
                icon: Icon(
                  obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: AppColors.textSecondary, size: 18,
                ),
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceLight,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.lime)),
      ),
    );
  }
}
