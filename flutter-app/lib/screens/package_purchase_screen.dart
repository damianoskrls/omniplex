import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';

/// Shown when the user taps "Αγορά πακέτου".
/// Collects user details (if not logged in), initiates Stripe Payment Sheet,
/// and on success calls /global/purchase/:slug/confirm to create membership.
class PackagePurchaseScreen extends StatefulWidget {
  const PackagePurchaseScreen({
    super.key,
    required this.plan,
    required this.gymSlug,
    required this.gymName,
    required this.gymColor,
    required this.globalAuth,
    required this.onPurchased,
  });

  final Map<String, dynamic> plan;
  final String gymSlug;
  final String gymName;
  final Color gymColor;
  final GlobalAuthService globalAuth;
  final VoidCallback onPurchased;

  @override
  State<PackagePurchaseScreen> createState() => _PackagePurchaseScreenState();
}

class _PackagePurchaseScreenState extends State<PackagePurchaseScreen> {
  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  final _nameCtrl     = TextEditingController();
  final _emailCtrl    = TextEditingController();
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _loading  = false;
  bool _obscure  = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Pre-fill from global auth if logged in
    final u = widget.globalAuth.user;
    if (u != null) {
      _nameCtrl.text  = u.fullName;
      _emailCtrl.text = u.email;
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose(); _emailCtrl.dispose();
    _phoneCtrl.dispose(); _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final name     = _nameCtrl.text.trim();
    final email    = _emailCtrl.text.trim();
    final phone    = _phoneCtrl.text.trim();
    final password = _passwordCtrl.text;

    if (name.isEmpty || phone.isEmpty) {
      setState(() => _error = 'Συμπλήρωσε ονοματεπώνυμο και κινητό');
      return;
    }
    if (!widget.globalAuth.isLoggedIn && password.length < 4) {
      setState(() => _error = 'Ο κωδικός πρέπει να έχει τουλάχιστον 4 ψηφία');
      return;
    }

    setState(() { _loading = true; _error = null; });

    try {
      // Step 1: create PaymentIntent
      final intentRes = await http.post(
        Uri.parse('$_apiBase/global/purchase/${widget.gymSlug}/intent'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'plan_id': widget.plan['id'],
          'user_info': {
            'full_name': name,
            'email':     email,
            'phone':     phone,
            'password':  password,
          },
        }),
      );
      if (intentRes.statusCode != 200) {
        final b = jsonDecode(intentRes.body) as Map<String, dynamic>;
        setState(() { _error = b['error'] as String? ?? 'Σφάλμα'; _loading = false; });
        return;
      }
      final intentBody = jsonDecode(intentRes.body) as Map<String, dynamic>;
      final clientSecret   = intentBody['client_secret'] as String;
      final publishableKey = intentBody['publishable_key'] as String;

      // Step 2: init Stripe + show Payment Sheet
      Stripe.publishableKey = publishableKey;
      await Stripe.instance.initPaymentSheet(
        paymentSheetParameters: SetupPaymentSheetParameters(
          paymentIntentClientSecret: clientSecret,
          merchantDisplayName: widget.gymName,
          style: ThemeMode.dark,
          appearance: PaymentSheetAppearance(
            colors: PaymentSheetAppearanceColors(
              primary: Color(widget.gymColor.value),
              background: const Color(0xFF1A1A1A),
              componentBackground: const Color(0xFF2A2A2A),
              primaryText: const Color(0xFFFFFFFF),
              secondaryText: const Color(0xFF999999),
            ),
          ),
        ),
      );
      await Stripe.instance.presentPaymentSheet();

      // Step 3: confirm on backend → create user + membership
      final confirmRes = await http.post(
        Uri.parse('$_apiBase/global/purchase/${widget.gymSlug}/confirm'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'intent_id': intentBody['intent_id'],
          'plan_id':   widget.plan['id'],
          'user_info': {
            'full_name': name,
            'email':     email,
            'phone':     phone,
            'password':  password,
          },
        }),
      );

      if (confirmRes.statusCode == 200) {
        final confirmBody = jsonDecode(confirmRes.body) as Map<String, dynamic>;
        // Persist session so user is logged in
        await widget.globalAuth.persistFromPurchase(confirmBody);
        if (mounted) widget.onPurchased();
      } else {
        final b = jsonDecode(confirmRes.body) as Map<String, dynamic>;
        setState(() { _error = b['error'] as String? ?? 'Σφάλμα επιβεβαίωσης'; _loading = false; });
      }
    } on StripeException catch (e) {
      final msg = e.error.localizedMessage ?? e.error.message ?? 'Η πληρωμή ακυρώθηκε';
      setState(() { _error = msg; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  String _fmtPrice(int cents) {
    final eur = cents / 100;
    return '€${eur % 1 == 0 ? eur.toInt() : eur.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final plan       = widget.plan;
    final planName   = plan['name'] as String? ?? '';
    final price      = plan['price_cents'] as int? ?? 0;
    final sessions   = plan['sessions_included'] as int?;
    final days       = plan['validity_days'] as int?;
    final color      = widget.gymColor;
    final isLoggedIn = widget.globalAuth.isLoggedIn;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.textPrimary, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Αγορά πακέτου',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800,
                color: AppColors.textPrimary)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Package summary card
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: color.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(Icons.card_membership_rounded, color: color, size: 28),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(planName, style: const TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary)),
                        Text(widget.gymName, style: TextStyle(
                            fontSize: 13, color: color, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (sessions != null)
                              Text('$sessions συνεδρίες',
                                  style: const TextStyle(fontSize: 12,
                                      color: AppColors.textSecondary)),
                            if (days != null)
                              Text('$days ημέρες',
                                  style: const TextStyle(fontSize: 12,
                                      color: AppColors.textSecondary)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Text(_fmtPrice(price),
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // User info form
            const Text('Στοιχεία',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 14),

            _label('Ονοματεπώνυμο'),
            const SizedBox(height: 6),
            _textField(_nameCtrl, 'Γιώργης Παπαδόπουλος'),
            const SizedBox(height: 12),

            _label('Κινητό τηλέφωνο *'),
            const SizedBox(height: 6),
            _textField(_phoneCtrl, '69XXXXXXXX', type: TextInputType.phone,
                enabled: !isLoggedIn),
            const SizedBox(height: 12),

            _label('Email (προαιρετικό)'),
            const SizedBox(height: 6),
            _textField(_emailCtrl, 'email@example.com',
                type: TextInputType.emailAddress, enabled: !isLoggedIn),

            if (!isLoggedIn) ...[
              const SizedBox(height: 12),
              _label('Κωδικός (για το OmniPlex account σου)'),
              const SizedBox(height: 6),
              TextField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                style: const TextStyle(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  hintText: '••••',
                  hintStyle: const TextStyle(color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  suffixIcon: IconButton(
                    icon: Icon(_obscure ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                        color: AppColors.textSecondary, size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.border)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(color: AppColors.lime)),
                ),
              ),
              const SizedBox(height: 6),
              const Text('Θα δημιουργηθεί αυτόματα λογαριασμός OmniPlex.',
                  style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            ],

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(_error!,
                    style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
              ),
            ],

            const SizedBox(height: 28),

            // Pay button
            SizedBox(
              width: double.infinity,
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _pay,
                style: FilledButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                child: _loading
                    ? const SizedBox(width: 22, height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lock_rounded, size: 18),
                          const SizedBox(width: 8),
                          Text('Πληρωμή ${_fmtPrice(price)}',
                              style: const TextStyle(
                                  fontSize: 17, fontWeight: FontWeight.w800)),
                        ],
                      ),
              ),
            ),

            const SizedBox(height: 12),
            const Center(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.security_rounded, size: 14, color: AppColors.textSecondary),
                  SizedBox(width: 6),
                  Text('Ασφαλής πληρωμή μέσω Stripe',
                      style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _label(String text) => Text(text,
    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
        color: AppColors.textSecondary));

Widget _textField(
  TextEditingController ctrl,
  String hint, {
  TextInputType? type,
  bool enabled = true,
}) =>
    TextField(
      controller: ctrl,
      keyboardType: type,
      enabled: enabled,
      style: TextStyle(
          color: enabled ? AppColors.textPrimary : AppColors.textSecondary),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.textSecondary),
        filled: true,
        fillColor: enabled ? AppColors.surfaceLight : AppColors.border.withAlpha(80),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border)),
        disabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: AppColors.lime)),
      ),
    );
