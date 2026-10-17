import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import '../services/push_service.dart';
import 'global_profile_details_screen.dart';
import '../l10n/tr.dart';

const _kBg      = Color(0xFF090A0F);
const _kCard    = Color(0xFF14161F);
const _kBorder  = Color(0xFF2B2E3D);
const _kText    = Color(0xFFF5F5FA);
const _kGray    = Color(0xFFA7ABBE);
const _kAccent  = Color(0xFF9A9DFF);
const _kPrimary = Color(0xFF565CE4);
const _kGuideBg = Color(0xFF242642);

class PhoneOtpLoginScreen extends StatefulWidget {
  const PhoneOtpLoginScreen({
    super.key,
    required this.globalAuth,
    required this.onLoggedIn,
    this.skipProfile = false,
    this.initialPhone,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onLoggedIn;
  final bool skipProfile;
  // When set, OTP was already sent by the caller — start directly in OTP phase
  final String? initialPhone;

  @override
  State<PhoneOtpLoginScreen> createState() => _PhoneOtpLoginScreenState();
}

class _PhoneOtpLoginScreenState extends State<PhoneOtpLoginScreen> {
  late String _phase;

  final _phoneCtrl = TextEditingController();
  final _otpCtrls  = List.generate(6, (_) => TextEditingController());

  bool   _loading = false;
  String? _error;
  int    _resendSeconds = 0;
  int    _currentDigit = 0;
  Timer? _timer;

  String get _phone => widget.initialPhone ?? _phoneCtrl.text.trim();
  String get _otp   => _otpCtrls.map((c) => c.text).join();

  @override
  void initState() {
    super.initState();
    _phase = widget.initialPhone != null ? 'otp' : 'phone';
    if (_phase == 'otp') {
      _startResendTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendSeconds = 60;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() {
        _resendSeconds--;
        if (_resendSeconds <= 0) t.cancel();
      });
    });
  }

  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = tr('Εισάγετε τον αριθμό τηλεφώνου σας'));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.sendOtp(phone);
      _startResendTimer();
      setState(() { _phase = 'otp'; _loading = false; _currentDigit = 0; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _resendOtp() async {
    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.sendOtp(_phone);
      _startResendTimer();
      for (final c in _otpCtrls) c.clear();
      setState(() => _currentDigit = 0);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.globalAuth.verifyOtp(_phone, _otp);
      await _registerFcmToken();
      if (!mounted) return;
      _routeAfterLogin(result);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; _currentDigit = 0; });
      for (final c in _otpCtrls) c.clear();
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      await PushService.instance.init();
      await PushService.instance.registerGlobal(widget.globalAuth);
    } catch (_) {}
  }

  void _routeAfterLogin(Map<String, dynamic> result) {
    final isNew = result['is_new'] == true;
    final name = (widget.globalAuth.user?.fullName ?? '').trim();
    final hasName = name.isNotEmpty &&
        !RegExp(tr(r'^Χρήστης\s+\d+$')).hasMatch(name);
    if (!widget.skipProfile && (isNew || !hasName)) {
      _goProfileDetails();
    } else {
      widget.onLoggedIn();
    }
  }

  void _goProfileDetails() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => GlobalProfileDetailsScreen(
        globalAuth: widget.globalAuth,
        onDone: widget.onLoggedIn,
      ),
    ));
  }

  void _keypadPress(String key) {
    if (key == '⌫') {
      for (var i = 5; i >= 0; i--) {
        if (_otpCtrls[i].text.isNotEmpty) {
          _otpCtrls[i].clear();
          setState(() => _currentDigit = i);
          return;
        }
      }
      return;
    }
    for (var i = 0; i < 6; i++) {
      if (_otpCtrls[i].text.isEmpty) {
        _otpCtrls[i].text = key;
        setState(() => _currentDigit = i < 5 ? i + 1 : 5);
        final full = _otpCtrls.map((c) => c.text).join();
        if (full.length == 6) _verifyOtp();
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: _phase == 'phone' ? _buildPhasePhone() : _buildPhaseOtp(),
      ),
    );
  }

  Widget _buildPhasePhone() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 56,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: const Icon(Icons.arrow_back_ios_new, color: _kText, size: 18),
                ),
                const SizedBox(width: 12),
                Text(tr('Σύνδεση'),
                  style: GoogleFonts.inter(
                    color: _kText, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(tr('Το επόμενο κεφάλαιό σου\nξεκινά εδώ.'),
            style: GoogleFonts.inter(
              color: _kText, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
          const SizedBox(height: 10),
          Text(tr('Συνδέσου ή δημιούργησε λογαριασμό με τον αριθμό του κινητού σου.'),
            style: GoogleFonts.inter(color: _kGray, fontSize: 14, height: 1.45)),
          const SizedBox(height: 22),
          Text(tr('Κινητό τηλέφωνο'),
            style: GoogleFonts.inter(color: _kGray, fontSize: 12, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          Container(
            height: 56,
            decoration: BoxDecoration(
              color: _kCard, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder)),
            child: Row(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text('🇬🇷  +30',
                    style: GoogleFonts.inter(color: _kText, fontSize: 15)),
                ),
                Container(width: 1, height: 28, color: _kBorder),
                Expanded(child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: GoogleFonts.inter(color: _kText, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: tr('6xxxxxxxxx'),
                    hintStyle: GoogleFonts.inter(color: _kGray),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) => _sendOtp(),
                )),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            _ErrorBanner(_error!),
          ],
          const SizedBox(height: 16),
          GestureDetector(
            onTap: _loading ? null : _sendOtp,
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
        ],
      ),
    );
  }

  Widget _buildPhaseOtp() {
    final maskedPhone = _phone.length > 4
      ? '+30 ••• ••• ${_phone.substring(_phone.length - 4)}'
      : '+30 $_phone';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: SizedBox(
            height: 56,
            child: Row(
              children: [
                GestureDetector(
                  onTap: () {
                    if (widget.initialPhone != null) {
                      Navigator.of(context).pop();
                    } else {
                      setState(() { _phase = 'phone'; _error = null; });
                    }
                  },
                  child: const Icon(Icons.arrow_back_ios_new, color: _kText, size: 18),
                ),
                const SizedBox(width: 12),
                Text(tr('Επαλήθευση αριθμού'),
                  style: GoogleFonts.inter(
                    color: _kText, fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),

        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Text('ΜΙΑ ΓΡΗΓΟΡΗ ΕΠΑΛΗΘΕΥΣΗ',
                  style: GoogleFonts.inter(
                    color: _kAccent, fontSize: 10, fontWeight: FontWeight.w700)),
                const SizedBox(height: 10),
                Text(tr('Ο κωδικός σου. Η πρόσβασή σου.'),
                  style: GoogleFonts.inter(
                    color: _kText, fontSize: 30, fontWeight: FontWeight.w800, height: 1.1)),
                const SizedBox(height: 10),
                Text('Εισάγετε τον 6ψήφιο κωδικό που στάλθηκε στο $maskedPhone.',
                  style: GoogleFonts.inter(color: _kGray, fontSize: 14, height: 1.45)),
                const SizedBox(height: 22),

                // OTP digit boxes
                Row(
                  children: List.generate(6, (i) => Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(right: i < 5 ? 8 : 0),
                      child: _OtpBox(
                        controller: _otpCtrls[i],
                        isActive: i == _currentDigit,
                      ),
                    ),
                  )),
                ),
                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(child: Text(
                      _resendSeconds > 0
                        ? tr('Επαναποστολή σε ${_formatTime(_resendSeconds)}')
                        : tr('Ο κωδικός έληξε'),
                      style: GoogleFonts.inter(color: _kGray, fontSize: 12))),
                    GestureDetector(
                      onTap: () {
                        if (widget.initialPhone != null) {
                          Navigator.of(context).pop();
                        } else {
                          setState(() { _phase = 'phone'; _error = null; });
                        }
                      },
                      child: Text(tr('Αλλαγή αριθμού'),
                        style: GoogleFonts.inter(color: _kAccent, fontSize: 12)),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                if (_error != null) ...[
                  _ErrorBanner(_error!),
                  const SizedBox(height: 14),
                ],

                GestureDetector(
                  onTap: _loading ? null : _verifyOtp,
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
                            Text(tr('Επαλήθευση & συνέχεια'),
                              style: GoogleFonts.inter(color: _kText, fontSize: 14)),
                            const SizedBox(width: 8),
                            const Icon(Icons.arrow_forward, color: _kText, size: 16),
                          ],
                        ),
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: _kGuideBg, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.shield_outlined, color: _kAccent, size: 18),
                      const SizedBox(width: 10),
                      Expanded(child: Text(
                        tr('Οι επαληθευμένοι αριθμοί σε συνδέουν με ασφάλεια με τις υπάρχουσες συνδρομές σου.'),
                        style: GoogleFonts.inter(color: _kGray, fontSize: 12, height: 1.45))),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        _NumericKeypad(
          onKey: _keypadPress,
          onResend: _resendSeconds <= 0 && !_loading ? _resendOtp : null,
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

// ── Custom numeric keypad ─────────────────────────────────────────────────────

class _NumericKeypad extends StatelessWidget {
  const _NumericKeypad({required this.onKey, this.onResend});
  final ValueChanged<String> onKey;
  final VoidCallback? onResend;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: _kBg,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          _KeyRow(keys: const ['1', '2', '3'], onKey: onKey),
          const SizedBox(height: 8),
          _KeyRow(keys: const ['4', '5', '6'], onKey: onKey),
          const SizedBox(height: 8),
          _KeyRow(keys: const ['7', '8', '9'], onKey: onKey),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: onResend != null
                  ? GestureDetector(
                      onTap: onResend,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1F2B),
                          borderRadius: BorderRadius.circular(10)),
                        child: Center(child: Text('Επαναποστολή',
                          style: GoogleFonts.inter(color: _kAccent, fontSize: 12))),
                      ))
                  : const SizedBox(height: 52),
              ),
              const SizedBox(width: 8),
              Expanded(child: _KeyButton(label: '0', onTap: () => onKey('0'))),
              const SizedBox(width: 8),
              Expanded(child: _KeyButton(label: '⌫', onTap: () => onKey('⌫'))),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyRow extends StatelessWidget {
  const _KeyRow({required this.keys, required this.onKey});
  final List<String> keys;
  final ValueChanged<String> onKey;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: keys.asMap().entries.map((e) => Expanded(
        child: Padding(
          padding: EdgeInsets.only(right: e.key < keys.length - 1 ? 8 : 0),
          child: _KeyButton(label: e.value, onTap: () => onKey(e.value)),
        ),
      )).toList(),
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 52,
        decoration: BoxDecoration(
          color: _kCard, borderRadius: BorderRadius.circular(10)),
        child: Center(child: Text(label,
          style: GoogleFonts.inter(color: _kText, fontSize: 22))),
      ),
    );
  }
}

// ── OTP digit display box ─────────────────────────────────────────────────────

class _OtpBox extends StatelessWidget {
  const _OtpBox({required this.controller, required this.isActive});
  final TextEditingController controller;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 62,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isActive ? _kAccent : _kBorder,
          width: isActive ? 2 : 1),
      ),
      child: Center(
        child: Text(
          controller.text.isEmpty ? '' : controller.text,
          style: GoogleFonts.inter(
            color: _kText, fontSize: 25, fontWeight: FontWeight.w600),
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
