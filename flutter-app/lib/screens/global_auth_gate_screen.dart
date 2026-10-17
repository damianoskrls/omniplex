import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import 'phone_otp_login_screen.dart';
import '../l10n/tr.dart';

const _kBg      = Color(0xFF090A0F);
const _kCard    = Color(0xFF14161F);
const _kBorder  = Color(0xFF2B2E3D);
const _kText    = Color(0xFFF5F5FA);
const _kGray    = Color(0xFFA7ABBE);
const _kGray2   = Color(0xFF757B92);
const _kAccent  = Color(0xFF9A9DFF);
const _kPrimary = Color(0xFF565CE4);
const _kGuideBg = Color(0xFF242642);

class GlobalAuthGateScreen extends StatefulWidget {
  const GlobalAuthGateScreen({
    super.key,
    required this.globalAuth,
    required this.onLogin,
    required this.onExplore,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onLogin;
  final VoidCallback onExplore;

  @override
  State<GlobalAuthGateScreen> createState() => _GlobalAuthGateScreenState();
}

class _GlobalAuthGateScreenState extends State<GlobalAuthGateScreen> {
  final _phoneCtrl = TextEditingController();
  bool _agreed = true;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _continueWithPhone() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = tr('Εισάγετε τον αριθμό τηλεφώνου σας'));
      return;
    }
    if (!_agreed) {
      setState(() => _error = tr('Αποδεχτείτε τους Όρους Χρήσης για να συνεχίσετε'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.sendOtp(phone);
      if (!mounted) return;
      Navigator.push(context, MaterialPageRoute(
        builder: (_) => PhoneOtpLoginScreen(
          globalAuth: widget.globalAuth,
          onLoggedIn: () {
            Navigator.pop(context);
            widget.onLogin();
          },
          initialPhone: phone,
        ),
      ));
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 56,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    tr('Καλωσήρθες στο Omniplex'),
                    style: GoogleFonts.inter(
                      color: _kText, fontSize: 16, fontWeight: FontWeight.w600, height: 1.45),
                  ),
                ),
              ),

              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: SvgPicture.asset('assets/omniplex_logo.svg', height: 44),
              ),

              Text.rich(TextSpan(
                text: tr('Το επόμενο κεφάλαιό σου\nξεκινά εδώ.'),
                style: GoogleFonts.inter(
                  color: _kText, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1),
              )),
              const SizedBox(height: 10),
              Text(
                tr('Συνδέσου ή δημιούργησε λογαριασμό με τον αριθμό του κινητού σου. Εμείς θα φροντίσουμε τα υπόλοιπα.'),
                style: GoogleFonts.inter(color: _kGray, fontSize: 14, height: 1.45),
              ),
              const SizedBox(height: 22),

              Text(tr('Κινητό τηλέφωνο'),
                style: GoogleFonts.inter(
                  color: _kGray, fontSize: 12, fontWeight: FontWeight.w500, height: 1.45)),
              const SizedBox(height: 8),
              Container(
                height: 56,
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kBorder),
                ),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Text('🇬🇷  +30',
                        style: GoogleFonts.inter(color: _kText, fontSize: 15)),
                    ),
                    Container(width: 1, height: 28, color: _kBorder),
                    Expanded(
                      child: TextField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: GoogleFonts.inter(color: _kText, fontSize: 15),
                        decoration: InputDecoration(
                          hintText: tr('6xxxxxxxxx'),
                          hintStyle: GoogleFonts.inter(color: _kGray),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                        ),
                        onSubmitted: (_) => _continueWithPhone(),
                      ),
                    ),
                  ],
                ),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                _ErrorBanner(_error!),
              ],
              const SizedBox(height: 10),

              // Guidance
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _kGuideBg, borderRadius: BorderRadius.circular(12)),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.smartphone_outlined, color: _kAccent, size: 18),
                    const SizedBox(width: 10),
                    Expanded(child: Text(
                      tr('Ήδη μέλος γυμναστηρίου; Θα βρούμε αυτόματα συνδρομές που συνδέονται με τον επαληθευμένο αριθμό σου.'),
                      style: GoogleFonts.inter(color: _kGray, fontSize: 12, height: 1.45))),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Terms
              GestureDetector(
                onTap: () => setState(() => _agreed = !_agreed),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 21, height: 21,
                      child: Checkbox(
                        value: _agreed,
                        onChanged: (v) => setState(() => _agreed = v ?? false),
                        activeColor: _kPrimary,
                        checkColor: _kText,
                        side: const BorderSide(color: _kBorder),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(
                      tr('Συμφωνώ με τους Όρους Χρήσης και την Πολιτική Απορρήτου, συμπεριλαμβανομένης της επαλήθευσης μέσω SMS.'),
                      style: GoogleFonts.inter(color: _kGray, fontSize: 12, height: 1.45))),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Primary CTA
              GestureDetector(
                onTap: _loading ? null : _continueWithPhone,
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: _kPrimary, borderRadius: BorderRadius.circular(12)),
                  child: _loading
                    ? const Center(child: SizedBox(width: 20, height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)))
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(tr('Συνέχεια με κινητό'),
                            style: GoogleFonts.inter(color: _kText, fontSize: 14)),
                          const SizedBox(width: 8),
                          const Icon(Icons.arrow_forward, color: _kText, size: 16),
                        ],
                      ),
                ),
              ),
              const SizedBox(height: 12),
              Container(height: 1, color: _kBorder),
              const SizedBox(height: 12),

              // Guest CTA
              GestureDetector(
                onTap: widget.onExplore,
                child: Container(
                  width: double.infinity, height: 52,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1F2B),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(tr('Συνέχεια ως επισκέπτης'),
                        style: GoogleFonts.inter(color: _kText, fontSize: 14)),
                      const SizedBox(width: 8),
                      const Icon(Icons.explore_outlined, color: _kText, size: 16),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),

              Text(
                tr('Εξερεύνησε ελεύθερα. Συνδέσου όταν είσαι έτοιμος να γίνεις μέλος, να κλείσεις θέση ή να αγοράσεις.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _kGray, fontSize: 12, height: 1.45),
              ),
              const SizedBox(height: 6),
              Text(
                tr('Ο αριθμός σου παραμένει ιδιωτικός. Κανένα μήνυμα marketing.'),
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: _kGray2, fontSize: 10, height: 1.45),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(tr(message),
            style: GoogleFonts.inter(color: Colors.redAccent, fontSize: 13))),
        ],
      ),
    );
  }
}
