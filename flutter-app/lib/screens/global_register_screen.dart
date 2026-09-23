import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import 'role_selection_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

class GlobalRegisterScreen extends StatefulWidget {
  const GlobalRegisterScreen({
    super.key,
    required this.globalAuth,
    required this.onRegistered,
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

  final _nameCtrl    = TextEditingController();
  final _emailCtrl   = TextEditingController();
  final _phoneCtrl   = TextEditingController();
  final _passCtrl    = TextEditingController();
  final _confirmCtrl = TextEditingController();
  final _gymSearchCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  bool _passObscure    = true;
  bool _confirmObscure = true;

  List<Map<String, dynamic>> _gymResults  = [];
  bool _gymSearching = false;
  final List<Map<String, dynamic>> _selectedGyms = [];

  @override
  void initState() {
    super.initState();
    if (widget.preselectedGym != null) {
      _selectedGyms.add(widget.preselectedGym!);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passCtrl.dispose();
    _confirmCtrl.dispose(); _gymSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _searchGyms(String q) async {
    if (q.trim().length < 2) { setState(() => _gymResults = []); return; }
    setState(() => _gymSearching = true);
    try {
      final uri = Uri.parse('$_apiBase/global/discovery/gyms')
          .replace(queryParameters: {'q': q.trim()});
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
      if (!_selectedGyms.any((g) => g['id'] == gym['id'])) _selectedGyms.add(gym);
      _gymResults = [];
      _gymSearchCtrl.clear();
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
      final token = widget.globalAuth.token;
      for (final gym in _selectedGyms) {
        try {
          await http.post(
            Uri.parse('$_apiBase/global/join-requests'),
            headers: {'Content-Type': 'application/json', 'Authorization': 'Bearer $token'},
            body: jsonEncode({'business_id': gym['id']}),
          );
        } catch (_) {}
      }

      if (!mounted) return;
      // Show role selection for new users
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (roleCtx) => RoleSelectionScreen(
            onContinue: (_) {
              Navigator.of(roleCtx).popUntil((r) => r.isFirst);
              widget.onRegistered();
            },
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Color _parseColor(String? hex) {
    if (hex == null) return _kLime;
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return _kLime; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(children: [
          // Top bar
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Container(
                  width: 40, height: 40,
                  decoration: BoxDecoration(
                    color: _kCard,
                    shape: BoxShape.circle,
                    border: Border.all(color: _kBorder),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 18),
                ),
              ),
              const Spacer(),
              Text('OmniPlex', style: GoogleFonts.manrope(
                fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
              const Spacer(),
              const SizedBox(width: 40),
            ]),
          ),

          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
              children: [
                Text('Δημιουργία\nΛογαριασμού',
                  style: GoogleFonts.manrope(
                    fontSize: 28, fontWeight: FontWeight.w700,
                    color: Colors.white, letterSpacing: -0.7, height: 1.1)),
                const SizedBox(height: 8),
                Text('Εγγράψου δωρεάν και ανακάλυψε γυμναστήρια.',
                  style: GoogleFonts.manrope(fontSize: 14, color: _kGray, height: 1.5)),
                const SizedBox(height: 28),

                if (_error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: Text(_error!,
                      style: GoogleFonts.manrope(color: Colors.redAccent, fontSize: 13)),
                  ),
                  const SizedBox(height: 16),
                ],

                _fieldLabel('Ονοματεπώνυμο'),
                const SizedBox(height: 8),
                _inputField(ctrl: _nameCtrl, hint: 'Γιώργης Παπαδόπουλος'),
                const SizedBox(height: 14),

                _fieldLabel('Email'),
                const SizedBox(height: 8),
                _inputField(ctrl: _emailCtrl, hint: 'email@example.com',
                    type: TextInputType.emailAddress),
                const SizedBox(height: 14),

                _fieldLabel('Κινητό (προαιρετικό)'),
                const SizedBox(height: 8),
                _inputField(ctrl: _phoneCtrl, hint: '69XXXXXXXX',
                    type: TextInputType.phone),
                const SizedBox(height: 14),

                _fieldLabel('Κωδικός'),
                const SizedBox(height: 8),
                _inputField(
                  ctrl: _passCtrl, hint: '••••••••', obscure: _passObscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _passObscure = !_passObscure),
                    icon: Icon(_passObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: _kGray, size: 18)),
                ),
                const SizedBox(height: 14),

                _fieldLabel('Επιβεβαίωση κωδικού'),
                const SizedBox(height: 8),
                _inputField(
                  ctrl: _confirmCtrl, hint: '••••••••', obscure: _confirmObscure,
                  suffix: IconButton(
                    onPressed: () => setState(() => _confirmObscure = !_confirmObscure),
                    icon: Icon(_confirmObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                      color: _kGray, size: 18)),
                ),
                const SizedBox(height: 28),

                // Gyms section
                Text('Γυμναστήρια',
                  style: GoogleFonts.manrope(
                    fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const SizedBox(height: 4),
                Text(
                  widget.preselectedGym != null
                    ? 'Θα σταλεί αίτημα εγγραφής στο επιλεγμένο γυμναστήριο.'
                    : 'Είσαι ήδη μέλος κάπου; Πρόσθεσέ το για αυτόματη σύνδεση.',
                  style: GoogleFonts.manrope(fontSize: 12, color: _kGray, height: 1.5)),
                const SizedBox(height: 12),

                // Selected gyms chips
                ..._selectedGyms.map((g) {
                  final color = _parseColor(g['primary_color'] as String?);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: _kCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _kBorder),
                    ),
                    child: Row(children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8)),
                        child: Center(child: Text(
                          (g['app_name'] as String? ?? g['name'] as String? ?? '?')[0].toUpperCase(),
                          style: GoogleFonts.manrope(
                            color: color, fontWeight: FontWeight.w800, fontSize: 14))),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        g['app_name'] as String? ?? g['name'] as String? ?? '',
                        style: GoogleFonts.manrope(
                          color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14))),
                      GestureDetector(
                        onTap: () => setState(() => _selectedGyms.removeWhere((x) => x['id'] == g['id'])),
                        child: const Icon(Icons.close_rounded, color: _kGray, size: 18)),
                    ]),
                  );
                }),

                // Gym search
                if (widget.preselectedGym == null) ...[
                  TextField(
                    controller: _gymSearchCtrl,
                    style: GoogleFonts.manrope(color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: 'Αναζήτηση γυμναστηρίου...',
                      hintStyle: GoogleFonts.manrope(color: _kGray, fontSize: 14),
                      prefixIcon: _gymSearching
                        ? const Padding(padding: EdgeInsets.all(12),
                            child: SizedBox(width: 16, height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: _kLime)))
                        : const Icon(Icons.search_rounded, color: _kGray, size: 18),
                      filled: true, fillColor: _kCard,
                      contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kBorder)),
                      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kBorder)),
                      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(color: _kLime)),
                    ),
                    onChanged: _searchGyms,
                  ),
                  if (_gymResults.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Container(
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kBorder),
                      ),
                      child: Column(
                        children: _gymResults.take(5).map((g) => InkWell(
                          onTap: () => _addGym(g),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(children: [
                              const Icon(Icons.fitness_center_rounded, size: 16, color: _kGray),
                              const SizedBox(width: 10),
                              Expanded(child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(g['app_name'] as String? ?? g['name'] as String? ?? '',
                                    style: GoogleFonts.manrope(
                                      color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                                  if ((g['city'] as String?)?.isNotEmpty == true)
                                    Text(g['city'] as String,
                                      style: GoogleFonts.manrope(color: _kGray, fontSize: 11)),
                                ],
                              )),
                              const Icon(Icons.add_rounded, color: _kLime, size: 18),
                            ]),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ],

                const SizedBox(height: 32),

                GestureDetector(
                  onTap: _loading ? null : _register,
                  child: Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: _kLime,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: _loading
                      ? const SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(strokeWidth: 2.5, color: _kBg))
                      : Text('Δημιουργία Λογαριασμού',
                          style: GoogleFonts.manrope(
                            fontSize: 15, fontWeight: FontWeight.w700, color: _kBg)),
                  ),
                ),
                const SizedBox(height: 20),
                Center(
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('Έχεις ήδη λογαριασμό; ',
                      style: GoogleFonts.manrope(fontSize: 14, color: _kGray)),
                    GestureDetector(
                      onTap: () => Navigator.maybePop(context),
                      child: Text('Σύνδεση',
                        style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700, color: _kLime,
                          decoration: TextDecoration.underline,
                          decorationColor: _kLime)),
                    ),
                  ]),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Widget _fieldLabel(String text) => Text(text, style: GoogleFonts.manrope(
    fontSize: 13, fontWeight: FontWeight.w600, color: _kGray));

  Widget _inputField({
    required TextEditingController ctrl,
    required String hint,
    TextInputType type = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: ctrl,
      keyboardType: type,
      obscureText: obscure,
      style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(color: _kGray),
        suffixIcon: suffix,
        filled: true,
        fillColor: _kCard,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorder)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kBorder)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _kLime)),
      ),
    );
  }
}
