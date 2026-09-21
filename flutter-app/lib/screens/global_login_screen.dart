import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import 'global_register_screen.dart';

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

class _GlobalLoginScreenState extends State<GlobalLoginScreen>
    with SingleTickerProviderStateMixin {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  // Customer tab (phone + PIN)
  final _phoneCtrl = TextEditingController();
  final _pinCtrl   = TextEditingController();

  // Staff tab
  final _staffEmailCtrl = TextEditingController();
  final _staffPassCtrl  = TextEditingController();
  bool _staffObscure    = true;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _tabCtrl.dispose();
    _phoneCtrl.dispose(); _pinCtrl.dispose();
    _staffEmailCtrl.dispose(); _staffPassCtrl.dispose();
    super.dispose();
  }

  Future<void> _loginCustomer() async {
    final phone = _phoneCtrl.text.trim();
    final pin   = _pinCtrl.text.trim();
    if (phone.isEmpty || pin.length != 4) {
      setState(() => _error = 'Συμπλήρωσε τηλέφωνο και 4ψήφιο PIN');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.loginPhone(phone, pin);
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
      backgroundColor: AppColors.bg,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Column(
          children: [
            // Back
            Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                child: IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppColors.textPrimary, size: 18),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(28, 12, 28, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // OmniPlex logo
                    Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: 44,
                        errorBuilder: (_, __, ___) => const Text(
                          'OmniPlex',
                          style: TextStyle(
                            fontSize: 30, fontWeight: FontWeight.w900,
                            color: AppColors.lime, letterSpacing: -0.5,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    const Text('Σύνδεση',
                        style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary)),
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
                        tabs: const [Tab(text: 'Πελάτης'), Tab(text: 'Προσωπικό')],
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
                        child: Text(_error!,
                            style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                      ),

                    AnimatedBuilder(
                      animation: _tabCtrl,
                      builder: (_, __) => _tabCtrl.index == 0
                          ? _CustomerForm(
                              phoneCtrl: _phoneCtrl,
                              pinCtrl: _pinCtrl,
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
                            ),
                    ),

                    const SizedBox(height: 32),

                    // Register CTA
                    Center(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Δεν έχεις λογαριασμό; ',
                              style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                          GestureDetector(
                            onTap: _goRegister,
                            child: const Text('Εγγραφή',
                                style: TextStyle(
                                  fontSize: 14, fontWeight: FontWeight.w800,
                                  color: AppColors.lime,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.lime,
                                )),
                          ),
                        ],
                      ),
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

// ── Customer form: phone + 4-digit PIN ────────────────────────

class _CustomerForm extends StatelessWidget {
  const _CustomerForm({
    required this.phoneCtrl,
    required this.pinCtrl,
    required this.onSubmit,
    required this.loading,
  });
  final TextEditingController phoneCtrl, pinCtrl;
  final bool loading;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label('Κινητό τηλέφωνο'),
        const SizedBox(height: 6),
        TextField(
          controller: phoneCtrl,
          keyboardType: TextInputType.phone,
          style: const TextStyle(color: AppColors.textPrimary, fontSize: 17, letterSpacing: 1),
          decoration: _inputDecoration('69XXXXXXXX',
              prefix: const Padding(
                padding: EdgeInsets.only(left: 14, right: 8),
                child: Text('+30', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
              )),
        ),
        const SizedBox(height: 16),
        _label('PIN (τελευταία 4 ψηφία κινητού)'),
        const SizedBox(height: 6),
        TextField(
          controller: pinCtrl,
          keyboardType: TextInputType.number,
          maxLength: 4,
          obscureText: true,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: const TextStyle(
              color: AppColors.textPrimary, fontSize: 22,
              letterSpacing: 12, fontWeight: FontWeight.w700),
          decoration: _inputDecoration('• • • •', counter: const SizedBox()),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 6),
        const Text(
          'Το PIN σου είναι τα τελευταία 4 ψηφία του κινητού σου',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 24),
        _submitBtn('Σύνδεση', loading, onSubmit),
      ],
    );
  }
}

// ── Staff form ────────────────────────────────────────────────

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
        TextField(
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecoration('staff@example.com'),
        ),
        const SizedBox(height: 14),
        _label('Κωδικός'),
        const SizedBox(height: 6),
        TextField(
          controller: passCtrl,
          obscureText: obscure,
          style: const TextStyle(color: AppColors.textPrimary),
          decoration: _inputDecoration('••••••', suffix: IconButton(
            onPressed: onToggle,
            icon: Icon(obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                color: AppColors.textSecondary, size: 20),
          )),
        ),
        const SizedBox(height: 8),
        const Text('Αν δεν έχεις κωδικό, επικοινώνησε με τον διαχειριστή.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
        _submitBtn('Σύνδεση Προσωπικού', loading, onSubmit),
      ],
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────

Widget _label(String text) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: AppColors.textSecondary));

InputDecoration _inputDecoration(String hint, {Widget? prefix, Widget? suffix, Widget? counter}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: AppColors.textSecondary),
      prefixIcon: prefix,
      suffixIcon: suffix,
      counter: counter,
      filled: true,
      fillColor: AppColors.surfaceLight,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.lime)),
    );

Widget _submitBtn(String label, bool loading, VoidCallback onPressed) => SizedBox(
  width: double.infinity, height: 54,
  child: ElevatedButton(
    onPressed: loading ? null : onPressed,
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.lime,
      foregroundColor: Colors.black,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
    ),
    child: loading
        ? const SizedBox(width: 20, height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
        : Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
  ),
);
