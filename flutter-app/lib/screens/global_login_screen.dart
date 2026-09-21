import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';

class GlobalLoginScreen extends StatefulWidget {
  const GlobalLoginScreen({
    super.key,
    required this.globalAuth,
    // Accept either callback name for backwards compat
    VoidCallback? onDone,
    VoidCallback? onLoggedIn,
  })  : onLoggedIn = onLoggedIn ?? onDone;

  final GlobalAuthService globalAuth;
  final VoidCallback? onLoggedIn;

  @override
  State<GlobalLoginScreen> createState() => _GlobalLoginScreenState();
}

class _GlobalLoginScreenState extends State<GlobalLoginScreen>
    with SingleTickerProviderStateMixin {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  // Customer tab
  final _emailCtrl = TextEditingController();
  final _passCtrl  = TextEditingController();
  bool _obscure    = true;

  // Staff tab
  final _staffEmailCtrl = TextEditingController();
  final _staffPassCtrl  = TextEditingController();
  bool _staffObscure    = true;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _tabCtrl.dispose();
    _emailCtrl.dispose(); _passCtrl.dispose();
    _staffEmailCtrl.dispose(); _staffPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginCustomer() async {
    final email = _emailCtrl.text.trim();
    final pass  = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Συμπλήρωσε email και κωδικό');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.login(email, pass);
      if (mounted) widget.onLoggedIn?.call();
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  Future<void> _loginStaff() async {
    final email = _staffEmailCtrl.text.trim();
    final pass  = _staffPassCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Συμπλήρωσε email και κωδικό');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final res = await http.post(
        Uri.parse('$_apiBase/global/staff/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': pass}),
      );
      if (res.statusCode == 200) {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        // Store staff token + gyms in GlobalAuthService
        await widget.globalAuth.setStaffSession(
          token:    body['token'] as String,
          fullName: body['full_name'] as String? ?? '',
          gyms:     (body['gyms'] as List).cast<Map<String, dynamic>>(),
        );
        if (mounted) widget.onLoggedIn?.call();
      } else {
        final body = jsonDecode(res.body) as Map<String, dynamic>;
        setState(() { _error = body['error'] as String? ?? 'Αδυναμία σύνδεσης'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Back
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Icon
                    Container(
                      width: 56, height: 56,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF7C5CFC), Color(0xFFE040FB)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Icon(Icons.person_rounded, color: Colors.white, size: 26),
                    ),
                    const SizedBox(height: 18),
                    const Text('Σύνδεση', style: TextStyle(
                      fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary)),
                    const SizedBox(height: 4),
                    const Text('Συνδέσου για να δεις όλα τα γυμναστήριά σου',
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                    const SizedBox(height: 24),

                    // Tabs
                    Container(
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: TabBar(
                        controller: _tabCtrl,
                        onTap: (_) => setState(() => _error = null),
                        indicator: BoxDecoration(
                          color: AppColors.lime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        indicatorSize: TabBarIndicatorSize.tab,
                        dividerColor: Colors.transparent,
                        labelColor: AppColors.bg,
                        unselectedLabelColor: AppColors.textSecondary,
                        labelStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                        tabs: const [
                          Tab(text: 'Πελάτης'),
                          Tab(text: 'Προσωπικό'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    if (_error != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),

                    // Tab views inline (no TabBarView to avoid nested scroll issues)
                    AnimatedBuilder(
                      animation: _tabCtrl,
                      builder: (_, __) {
                        return _tabCtrl.index == 0
                            ? _CustomerForm(
                                emailCtrl: _emailCtrl,
                                passCtrl: _passCtrl,
                                obscure: _obscure,
                                onToggle: () => setState(() => _obscure = !_obscure),
                                onSubmit: _loginCustomer,
                                loading: _loading,
                              )
                            : _StaffForm(
                                emailCtrl: _staffEmailCtrl,
                                passCtrl: _staffPassCtrl,
                                obscure: _staffObscure,
                                onToggle: () => setState(() => _staffObscure = !_staffObscure),
                                onSubmit: _loginStaff,
                                loading: _loading,
                              );
                      },
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
}

class _CustomerForm extends StatelessWidget {
  const _CustomerForm({
    required this.emailCtrl, required this.passCtrl,
    required this.obscure, required this.onToggle,
    required this.onSubmit, required this.loading,
  });
  final TextEditingController emailCtrl, passCtrl;
  final bool obscure, loading;
  final VoidCallback onToggle, onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Email'),
        const SizedBox(height: 6),
        _textField(emailCtrl, 'email@example.com', type: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _label('Κωδικός'),
        const SizedBox(height: 6),
        _passField(passCtrl, obscure, onToggle),
        const SizedBox(height: 24),
        _submitBtn('Σύνδεση', loading, onSubmit),
      ],
    );
  }
}

class _StaffForm extends StatelessWidget {
  const _StaffForm({
    required this.emailCtrl, required this.passCtrl,
    required this.obscure, required this.onToggle,
    required this.onSubmit, required this.loading,
  });
  final TextEditingController emailCtrl, passCtrl;
  final bool obscure, loading;
  final VoidCallback onToggle, onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Email Προσωπικού'),
        const SizedBox(height: 6),
        _textField(emailCtrl, 'staff@example.com', type: TextInputType.emailAddress),
        const SizedBox(height: 14),
        _label('Κωδικός'),
        const SizedBox(height: 6),
        _passField(passCtrl, obscure, onToggle),
        const SizedBox(height: 8),
        const Text(
          'Αν δεν έχεις κωδικό, επικοινώνησε με τον διαχειριστή.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _submitBtn('Σύνδεση Προσωπικού', loading, onSubmit),
      ],
    );
  }
}

Widget _label(String text) => Text(text,
  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary));

Widget _textField(TextEditingController ctrl, String hint, {TextInputType? type}) => TextField(
  controller: ctrl,
  keyboardType: type,
  style: const TextStyle(color: AppColors.textPrimary),
  decoration: InputDecoration(
    hintText: hint,
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surfaceLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.lime.withValues(alpha: 0.6))),
  ),
);

Widget _passField(TextEditingController ctrl, bool obscure, VoidCallback toggle) => TextField(
  controller: ctrl,
  obscureText: obscure,
  style: const TextStyle(color: AppColors.textPrimary),
  decoration: InputDecoration(
    hintText: '••••••',
    hintStyle: const TextStyle(color: AppColors.textSecondary),
    filled: true,
    fillColor: AppColors.surfaceLight,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    suffixIcon: IconButton(
      onPressed: toggle,
      icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
        color: AppColors.textSecondary, size: 20),
    ),
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: AppColors.border)),
    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.lime.withValues(alpha: 0.6))),
  ),
);

Widget _submitBtn(String label, bool loading, VoidCallback onPressed) => SizedBox(
  width: double.infinity,
  height: 52,
  child: ElevatedButton(
    onPressed: loading ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.lime,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    child: loading
        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
        : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
  ),
);
