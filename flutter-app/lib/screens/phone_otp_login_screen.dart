import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/global_auth_service.dart';
import 'global_role_picker_screen.dart';

const _kBg     = Color(0xFF0A0A0A);
const _kCard   = Color(0xFF16171B);
const _kBorder = Color(0xFF2A2B30);
const _kGray   = Color(0xFF9A9CA3);
const _kLime   = Color(0xFFC6FF3D);

class PhoneOtpLoginScreen extends StatefulWidget {
  const PhoneOtpLoginScreen({
    super.key,
    required this.globalAuth,
    required this.onLoggedIn,
  });

  final GlobalAuthService globalAuth;
  final VoidCallback onLoggedIn;

  @override
  State<PhoneOtpLoginScreen> createState() => _PhoneOtpLoginScreenState();
}

class _PhoneOtpLoginScreenState extends State<PhoneOtpLoginScreen> {
  // Phase: 'phone' | 'otp'
  String _phase = 'phone';

  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrls     = List.generate(6, (_) => TextEditingController());
  final _otpFocus     = List.generate(6, (_) => FocusNode());

  bool   _loading  = false;
  String? _error;

  // Countdown for resend
  int  _resendSeconds = 0;
  Timer? _timer;

  String get _phone => _phoneCtrl.text.trim();
  String get _otp   => _otpCtrls.map((c) => c.text).join();

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final f in _otpFocus) f.dispose();
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
    final phone = _phone;
    if (phone.isEmpty) {
      setState(() => _error = 'Εισάγετε τον αριθμό τηλεφώνου σας');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.globalAuth.sendOtp(phone);
      _startResendTimer();
      setState(() { _phase = 'otp'; _loading = false; });
      // Auto-focus first OTP box
      Future.delayed(const Duration(milliseconds: 200), () {
        if (mounted) _otpFocus[0].requestFocus();
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _verifyOtp() async {
    if (_otp.length != 6) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.globalAuth.verifyOtp(_phone, _otp);
      await _registerFcmToken();
      if (!mounted) return;
      if (result['is_new'] == true) {
        _goRolePicker();
      } else {
        widget.onLoggedIn();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
      for (final c in _otpCtrls) c.clear();
      _otpFocus[0].requestFocus();
    }
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null && token.isNotEmpty) {
        final platform = Platform.isIOS ? 'ios' : 'android';
        await widget.globalAuth.registerFcmToken(token, platform: platform);
      }
    } catch (_) {}
  }

  void _onOtpDigit(int index, String val) {
    if (val.isNotEmpty && index < 5) {
      _otpFocus[index + 1].requestFocus();
    }
    // Auto-verify when all 6 filled
    final full = _otpCtrls.map((c) => c.text).join();
    if (full.length == 6) _verifyOtp();
  }

  Future<void> _verifyPassword() async {
    final pwd = _passwordCtrl.text.trim();
    if (pwd.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.globalAuth.verifyOtp(_phone, pwd);
      await _registerFcmToken();
      if (!mounted) return;
      if (result['is_new'] == true) {
        _goRolePicker();
      } else {
        widget.onLoggedIn();
      }
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _goRolePicker() {
    Navigator.pushReplacement(context, MaterialPageRoute(
      builder: (_) => GlobalRolePickerScreen(
        globalAuth: widget.globalAuth,
        onDone: (_) => widget.onLoggedIn(),
      ),
    ));
  }

  void _onOtpBackspace(int index) {
    if (_otpCtrls[index].text.isEmpty && index > 0) {
      _otpFocus[index - 1].requestFocus();
      _otpCtrls[index - 1].clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      appBar: AppBar(
        backgroundColor: _kBg,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () {
            if (_phase == 'otp') {
              setState(() { _phase = 'phone'; _error = null; });
            } else {
              Navigator.of(context).pop();
            }
          },
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: _phase == 'phone' ? _buildPhasePhone() : _buildPhaseOtp(),
        ),
      ),
    );
  }

  Widget _buildPhasePhone() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Σύνδεση', style: GoogleFonts.manrope(
          color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 8),
        Text('Εισάγετε τον αριθμό τηλεφώνου σας\nγια να λάβετε κωδικό επαλήθευσης.',
          style: GoogleFonts.manrope(color: _kGray, fontSize: 14, height: 1.5),
        ),
        const SizedBox(height: 40),

        // Phone field
        Text('Τηλέφωνο', style: GoogleFonts.manrope(
          color: _kGray, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 0.5,
        )),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                decoration: BoxDecoration(
                  border: Border(right: BorderSide(color: _kBorder)),
                ),
                child: Text('+30', style: GoogleFonts.manrope(
                  color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500,
                )),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  autofocus: true,
                  style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: '6xxxxxxxxx',
                    hintStyle: GoogleFonts.manrope(color: _kGray),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
                  ),
                  onSubmitted: (_) => _sendOtp(),
                ),
              ),
            ],
          ),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(_error!),
        ],

        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _loading ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: _kLime,
              foregroundColor: Colors.black,
              disabledBackgroundColor: _kLime.withOpacity(0.4),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : Text('Αποστολή κωδικού', style: GoogleFonts.manrope(
                  fontWeight: FontWeight.w700, fontSize: 15,
                )),
          ),
        ),
      ],
    );
  }

  // true = use OTP boxes, false = use password field
  bool _useOtpMode = true;

  Widget _buildPhaseOtp() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text('Κωδικός επαλήθευσης', style: GoogleFonts.manrope(
          color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 8),
        if (_useOtpMode)
          Text.rich(TextSpan(
            children: [
              TextSpan(text: 'Στείλαμε 6-ψήφιο κωδικό στο ', style: GoogleFonts.manrope(color: _kGray, fontSize: 14)),
              TextSpan(text: '+30 $_phone', style: GoogleFonts.manrope(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ))
        else
          Text('Βάλτε τον κωδικό του λογαριασμού σας OmniPlex.',
            style: GoogleFonts.manrope(color: _kGray, fontSize: 14, height: 1.5),
          ),
        const SizedBox(height: 40),

        if (_useOtpMode) ...[
          // 6 OTP boxes
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) => Padding(
              padding: EdgeInsets.only(right: i < 5 ? 10 : 0),
              child: _OtpBox(
                controller: _otpCtrls[i],
                focusNode: _otpFocus[i],
                onChanged: (v) => _onOtpDigit(i, v),
                onBackspace: () => _onOtpBackspace(i),
              ),
            )),
          ),
        ] else ...[
          // Password field
          Container(
            decoration: BoxDecoration(
              color: _kCard,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _kBorder),
            ),
            child: TextField(
              controller: _passwordCtrl,
              obscureText: true,
              autofocus: true,
              style: GoogleFonts.manrope(color: Colors.white, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Κωδικός OmniPlex',
                hintStyle: GoogleFonts.manrope(color: _kGray),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
              ),
              onSubmitted: (_) => _verifyPassword(),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _loading ? null : _verifyPassword,
              style: ElevatedButton.styleFrom(
                backgroundColor: _kLime,
                foregroundColor: Colors.black,
                disabledBackgroundColor: _kLime.withOpacity(0.4),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: _loading
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                : Text('Σύνδεση', style: GoogleFonts.manrope(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
          ),
        ],

        if (_error != null) ...[
          const SizedBox(height: 20),
          _ErrorBanner(_error!),
        ],

        const SizedBox(height: 24),

        // Toggle between OTP and password
        Center(
          child: GestureDetector(
            onTap: () => setState(() {
              _useOtpMode = !_useOtpMode;
              _error = null;
            }),
            child: Text(
              _useOtpMode
                ? 'Έχω κωδικό λογαριασμού OmniPlex'
                : 'Χρήση κωδικού SMS',
              style: GoogleFonts.manrope(
                color: _kLime, fontSize: 13, fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),

        if (_useOtpMode) ...[
          const SizedBox(height: 16),
          // Resend
          Center(
            child: _resendSeconds > 0
              ? Text('Αποστολή ξανά σε ${_resendSeconds}s', style: GoogleFonts.manrope(color: _kGray, fontSize: 13))
              : GestureDetector(
                  onTap: _loading ? null : _sendOtp,
                  child: Text('Αποστολή ξανά', style: GoogleFonts.manrope(
                    color: _kGray, fontSize: 13, fontWeight: FontWeight.w600,
                  )),
                ),
          ),
        ],

        if (_loading && _useOtpMode) ...[
          const SizedBox(height: 24),
          const Center(child: CircularProgressIndicator(color: _kLime)),
        ],
      ],
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onBackspace,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 56,
      child: Focus(
        onKeyEvent: (node, event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              controller.text.isEmpty) {
            onBackspace();
            return KeyEventResult.handled;
          }
          return KeyEventResult.ignored;
        },
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(1)],
          style: GoogleFonts.manrope(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF16171B),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2A2B30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF2A2B30)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: _kLime, width: 1.5),
            ),
            contentPadding: EdgeInsets.zero,
          ),
          onChanged: onChanged,
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
        border: Border.all(color: Colors.red.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: GoogleFonts.manrope(color: Colors.redAccent, fontSize: 13))),
        ],
      ),
    );
  }
}
