import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import 'global_register_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

class GlobalLoginScreen extends StatefulWidget {
  const GlobalLoginScreen({
    super.key,
    required this.globalAuth,
    VoidCallback? onDone,
    VoidCallback? onLoggedIn,
    this.preselectedGym,
  }) : onLoggedIn = onLoggedIn ?? onDone;

  final GlobalAuthService globalAuth;
  final VoidCallback? onLoggedIn;
  final Map<String, dynamic>? preselectedGym;

  @override
  State<GlobalLoginScreen> createState() => _GlobalLoginScreenState();
}

class _GlobalLoginScreenState extends State<GlobalLoginScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  // Email+password login (global)
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _passObscure = true;

  // Staff extra
  bool _isStaff = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Συμπλήρωσε email και κωδικό');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      if (_isStaff) {
        final res = await http.post(
          Uri.parse('$_apiBase/global/staff/login'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'email': email, 'password': pass}),
        );
        if (res.statusCode == 200) {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          await widget.globalAuth.setStaffSession(
            token:    body['token'] as String,
            fullName: body['full_name'] as String? ?? '',
            gyms:     (body['gyms'] as List).cast<Map<String, dynamic>>(),
          );
          if (mounted) {
            Navigator.of(context).popUntil((r) => r.isFirst);
            widget.onLoggedIn?.call();
          }
        } else {
          final body = jsonDecode(res.body) as Map<String, dynamic>;
          setState(() { _error = body['error'] as String? ?? 'Αδυναμία σύνδεσης'; _loading = false; });
        }
      } else {
        await widget.globalAuth.login(email, pass);
        if (mounted) {
          Navigator.of(context).popUntil((r) => r.isFirst);
          widget.onLoggedIn?.call();
        }
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  void _goRegister() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => GlobalRegisterScreen(
          globalAuth: widget.globalAuth,
          onRegistered: widget.onLoggedIn ?? () {},
          preselectedGym: widget.preselectedGym,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Back
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
                // OmniPlex logo text
                Text('OmniPlex', style: GoogleFonts.manrope(
                  fontSize: 16, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                const SizedBox(width: 40),
              ]),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Καλώς ήρθες\nξανά 👋',
                      style: GoogleFonts.manrope(
                        fontSize: 30, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: -0.8, height: 1.1)),
                    const SizedBox(height: 8),
                    Text('Σύνδεσε τον λογαριασμό σου στο OmniPlex.',
                      style: GoogleFonts.manrope(fontSize: 14, color: _kGray, height: 1.5)),
                    const SizedBox(height: 32),

                    // Staff toggle
                    Container(
                      decoration: BoxDecoration(
                        color: _kCard,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: _kBorder),
                      ),
                      padding: const EdgeInsets.all(4),
                      child: Row(children: [
                        _tabBtn('Μέλος', !_isStaff, () => setState(() { _isStaff = false; _error = null; })),
                        _tabBtn('Προσωπικό', _isStaff, () => setState(() { _isStaff = true; _error = null; })),
                      ]),
                    ),
                    const SizedBox(height: 24),

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

                    _fieldLabel('Email'),
                    const SizedBox(height: 8),
                    _inputField(
                      ctrl: _emailCtrl,
                      hint: 'email@example.com',
                      type: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 14),

                    _fieldLabel('Κωδικός'),
                    const SizedBox(height: 8),
                    _inputField(
                      ctrl: _passCtrl,
                      hint: '••••••••',
                      obscure: _passObscure,
                      suffix: IconButton(
                        onPressed: () => setState(() => _passObscure = !_passObscure),
                        icon: Icon(
                          _passObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                          color: _kGray, size: 18),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Submit
                    GestureDetector(
                      onTap: _loading ? null : _login,
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
                          : Text('Σύνδεση',
                              style: GoogleFonts.manrope(
                                fontSize: 16, fontWeight: FontWeight.w700, color: _kBg)),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Register CTA
                    Center(
                      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                        Text('Δεν έχεις λογαριασμό; ',
                          style: GoogleFonts.manrope(fontSize: 14, color: _kGray)),
                        GestureDetector(
                          onTap: _goRegister,
                          child: Text('Εγγραφή',
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
            ),
          ],
        ),
      ),
    );
  }

  Widget _tabBtn(String label, bool active, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 40,
          decoration: BoxDecoration(
            color: active ? _kLime : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(label, style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700,
            color: active ? _kBg : _kGray)),
        ),
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
