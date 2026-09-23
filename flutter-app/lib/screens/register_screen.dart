import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../widgets/omni_design.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl  = TextEditingController();
  final _phoneCtrl     = TextEditingController();
  final _pinCtrl       = TextEditingController();
  final _pinConfirmCtrl = TextEditingController();
  final _emailCtrl     = TextEditingController();

  bool _loading = false;
  bool _pinVisible = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _pinConfirmCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    final firstName = _firstNameCtrl.text.trim();
    final lastName  = _lastNameCtrl.text.trim();
    final phone     = _phoneCtrl.text.trim();
    final pin       = _pinCtrl.text.trim();
    final pinConfirm = _pinConfirmCtrl.text.trim();

    if (firstName.isEmpty || lastName.isEmpty) {
      setState(() => _error = 'Συμπλήρωσε όνομα και επώνυμο');
      return;
    }
    if (phone.isEmpty || phone.length < 10) {
      setState(() => _error = 'Συμπλήρωσε έγκυρο κινητό (10 ψηφία)');
      return;
    }
    if (pin.length != 4 || int.tryParse(pin) == null) {
      setState(() => _error = 'Το PIN πρέπει να είναι ακριβώς 4 ψηφία');
      return;
    }
    if (pin != pinConfirm) {
      setState(() => _error = 'Τα PIN δεν ταιριάζουν');
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.registerRequest(
        fullName: '$firstName $lastName',
        phone: phone,
        pin: pin,
        email: _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim(),
      );
      if (mounted) setState(() { _loading = false; _done = true; });
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
            child: _done ? _buildSuccess() : _buildForm(),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: kLime.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.check_circle_outline, color: kLime, size: 40),
          ),
          const SizedBox(height: 24),
          Text('Το αίτημά σου στάλθηκε!',
            textAlign: TextAlign.center,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 26, fontWeight: FontWeight.w700,
              color: Colors.white, letterSpacing: -0.6)),
          const SizedBox(height: 12),
          Text(
            'Ο διαχειριστής του γυμναστηρίου θα εγκρίνει το αίτημά σου. '
            'Μόλις εγκριθεί, μπορείς να συνδεθείς με κινητό και PIN.',
            textAlign: TextAlign.center,
            style: GoogleFonts.manrope(fontSize: 14, color: kGray, height: 1.6),
          ),
          const SizedBox(height: 40),
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              height: 56,
              decoration: BoxDecoration(
                color: kLime,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Center(
                child: Text('ΠΙΣΩ ΣΤΗ ΣΥΝΔΕΣΗ', style: GoogleFonts.spaceGrotesk(
                  fontSize: 13, fontWeight: FontWeight.w700,
                  color: kBg, letterSpacing: 1.2)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: kCard,
                shape: BoxShape.circle,
                border: Border.all(color: kBorder),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(height: 28),
          Text('Εγγραφή', style: GoogleFonts.spaceGrotesk(
            fontSize: 34, fontWeight: FontWeight.w700,
            color: Colors.white, letterSpacing: -0.8)),
          const SizedBox(height: 8),
          Text(
            'Δημιούργησε λογαριασμό και βρες το γυμναστήριό σου.',
            style: GoogleFonts.manrope(fontSize: 14, color: kGray, height: 1.5),
          ),
          const SizedBox(height: 32),
          // Name row
          Row(children: [
            Expanded(child: _labeledField('ΌΝΟΜΑ', _firstNameCtrl, 'Γιώργης')),
            const SizedBox(width: 12),
            Expanded(child: _labeledField('ΕΠΏΝΥΜΟ', _lastNameCtrl, 'Παπαδόπουλος')),
          ]),
          const SizedBox(height: 16),
          // Phone
          _buildPhoneField(),
          const SizedBox(height: 16),
          // Email optional
          _labeledField('EMAIL (ΠΡΟΑΙΡΕΤΙΚΌ)', _emailCtrl, 'example@email.com',
            type: TextInputType.emailAddress),
          const SizedBox(height: 16),
          // PIN
          _buildPinField('PIN (4 ΨΗΦΊΑ)', _pinCtrl, 'Π.χ. 1234'),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.info_outline, color: kGray, size: 13),
              const SizedBox(width: 6),
              Expanded(child: Text(
                'Συνιστάται τα 4 τελευταία ψηφία του κινητού σου.',
                style: GoogleFonts.manrope(fontSize: 11, color: kGray),
              )),
            ],
          ),
          const SizedBox(height: 16),
          _buildPinField('ΕΠΙΒΕΒΑΊΩΣΗ PIN', _pinConfirmCtrl, 'Ξανά το PIN'),
          if (_error != null) ...[
            const SizedBox(height: 16),
            _buildError(),
          ],
          const SizedBox(height: 28),
          _buildRegisterButton(),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Έχεις ήδη λογαριασμό; ', style: GoogleFonts.manrope(
                fontSize: 14, color: kGray)),
              GestureDetector(
                onTap: () => Navigator.maybePop(context),
                child: Text('Σύνδεση', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: kLime)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _labeledField(String label, TextEditingController ctrl, String hint, {
    TextInputType type = TextInputType.text,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: kGray, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: TextField(
            controller: ctrl,
            keyboardType: type,
            style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ΚΙΝΗΤΌ', style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: kGray, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: const BoxDecoration(
                  border: Border(right: BorderSide(color: kBorder)),
                ),
                child: Text('+30', style: GoogleFonts.manrope(
                  fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              Expanded(
                child: TextField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
                  decoration: InputDecoration(
                    hintText: '6901234567',
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPinField(String label, TextEditingController ctrl, String hint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.manrope(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: kGray, letterSpacing: 1.2)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: ctrl,
                  obscureText: !_pinVisible,
                  keyboardType: TextInputType.number,
                  maxLength: 4,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  style: GoogleFonts.manrope(
                    fontSize: ctrl == _pinCtrl ? 22 : 14,
                    color: Colors.white, letterSpacing: ctrl == _pinCtrl ? 6 : 0),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
                    border: InputBorder.none,
                    counterText: '',
                    contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  ),
                ),
              ),
              if (ctrl == _pinCtrl)
                IconButton(
                  icon: Icon(
                    _pinVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                    color: kGray, size: 18),
                  onPressed: () => setState(() => _pinVisible = !_pinVisible),
                ),
            ],
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
          Expanded(child: Text(_error!, style: GoogleFonts.manrope(
            fontSize: 13, color: const Color(0xFFFF5D5D)))),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return GestureDetector(
      onTap: _loading ? null : _register,
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
            : Text('ΕΓΓΡΑΦΗ', style: GoogleFonts.spaceGrotesk(
                fontSize: 14, fontWeight: FontWeight.w700,
                color: kBg, letterSpacing: 1.5)),
        ),
      ),
    );
  }
}
