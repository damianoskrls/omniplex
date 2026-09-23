import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/global_auth_service.dart';
import '../widgets/omni_design.dart';
import 'global_register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.globalAuth});
  final GlobalAuthService? globalAuth;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _pinCtrl   = TextEditingController();
  final _phoneFocus = FocusNode();
  final _pinFocus   = FocusNode();

  bool _loading = false;
  bool _pinVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() {}));
    _pinFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _phoneFocus.dispose();
    _pinFocus.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    final phone = _phoneCtrl.text.trim();
    final pin   = _pinCtrl.text.trim();

    if (phone.isEmpty) {
      setState(() => _error = 'Συμπλήρωσε το κινητό σου');
      return;
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'Το PIN αποτελείται από 4 ψηφία');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.login(phone, pin);
    } catch (e) {
      if (mounted) setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      resizeToAvoidBottomInset: true,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: OmniBgPainter()),
          const OmniCornerBrackets(),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildLogo(),
                  const SizedBox(height: 40),
                  _buildHeading(),
                  const SizedBox(height: 8),
                  _buildSubtitle(),
                  const SizedBox(height: 32),
                  _buildPhoneField(),
                  const SizedBox(height: 16),
                  _buildPinField(),
                  const SizedBox(height: 12),
                  _buildHint(),
                  if (_error != null) ...[
                    const SizedBox(height: 16),
                    _buildError(),
                  ],
                  const SizedBox(height: 28),
                  _buildLoginButton(),
                  const SizedBox(height: 40),
                  _buildDivider(),
                  const SizedBox(height: 28),
                  _buildRegisterRow(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: kLime,
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.fitness_center, color: kBg, size: 18),
        ),
        const SizedBox(width: 10),
        Text('BookUp', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
      ],
    );
  }

  Widget _buildHeading() {
    return Text('Σύνδεση', style: GoogleFonts.spaceGrotesk(
      fontSize: 34, fontWeight: FontWeight.w700,
      color: Colors.white, letterSpacing: -0.8));
  }

  Widget _buildSubtitle() {
    return Text(
      'Έχεις λογαριασμό σε γυμναστήριο; Σύνδεσε με κινητό & PIN.',
      style: GoogleFonts.manrope(fontSize: 14, color: kGray, height: 1.5),
    );
  }

  Widget _buildPhoneField() {
    final active = _phoneFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ΚΙΝΗΤΌ', style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: active ? kLime : kGray, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? kLime : kBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: kBorder)),
                ),
                child: Text('+30', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: 1.0)),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  focusNode: _phoneFocus,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '6901234567',
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinField() {
    final active = _pinFocus.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('PIN (4 ΨΗΦΊΑ)', style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: active ? kLime : kGray, letterSpacing: 1.4)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: active ? kLime : kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _pinCtrl,
                  focusNode: _pinFocus,
                  obscureText: !_pinVisible,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.manrope(fontSize: 20, color: Colors.white, letterSpacing: 8),
                  decoration: InputDecoration(
                    hintText: '• • • •',
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onSubmitted: (_) => _login(),
                ),
              ),
              IconButton(
                icon: Icon(
                  _pinVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                  color: kGray, size: 20),
                onPressed: () => setState(() => _pinVisible = !_pinVisible),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHint() {
    return Row(
      children: [
        const Icon(Icons.info_outline, color: kGray, size: 14),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Το PIN είναι τα 4 τελευταία ψηφία του κινητού σου (εκτός αν έχει αλλάξει).',
            style: GoogleFonts.manrope(fontSize: 11, color: kGray, height: 1.4),
          ),
        ),
      ],
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1414),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFF5D5D).withValues(alpha: 0.40)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Color(0xFFFF5D5D), size: 16),
          const SizedBox(width: 10),
          Expanded(
            child: Text(_error!, style: GoogleFonts.manrope(
              fontSize: 13, color: const Color(0xFFFF5D5D))),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return GestureDetector(
      onTap: _loading ? null : _login,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: _loading ? kLime.withValues(alpha: 0.6) : kLime,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Center(
          child: _loading
            ? const SizedBox(width: 22, height: 22,
                child: CircularProgressIndicator(color: kBg, strokeWidth: 2.5))
            : Text('ΣΥΝΔΕΣΗ', style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: kBg, letterSpacing: 1.5)),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      const Expanded(child: Divider(color: kBorder, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('ΔΕΝ ΕΧΕΙΣ ΛΟΓΑΡΙΑΣΜΟ;', style: GoogleFonts.spaceGrotesk(
          fontSize: 10, color: kDim, letterSpacing: 1.5)),
      ),
      const Expanded(child: Divider(color: kBorder, thickness: 1)),
    ]);
  }

  Widget _buildRegisterRow() {
    return Column(
      children: [
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => GlobalRegisterScreen(
              globalAuth: widget.globalAuth ?? GlobalAuthService(),
              onRegistered: () => Navigator.pop(context),
            ))),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: kBorder2),
            ),
            child: Center(
              child: Text('ΔΗΜΙΟΥΡΓΙΑ ΛΟΓΑΡΙΑΣΜΟΥ', style: GoogleFonts.spaceGrotesk(
                fontSize: 13, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: 1.2)),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Αν δεν έχεις ακόμα λογαριασμό, δημιούργησε έναν και βρες το γυμναστήριό σου.',
          textAlign: TextAlign.center,
          style: GoogleFonts.manrope(fontSize: 12, color: kGray, height: 1.5),
        ),
      ],
    );
  }
}
