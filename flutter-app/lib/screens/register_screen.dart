import 'package:flutter/material.dart';
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
  final _emailCtrl     = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  final _confirmCtrl   = TextEditingController();

  final _emailFocus = FocusNode();

  bool _loading = false;
  bool _passVisible = false;
  bool _confirmVisible = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailFocus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    _emailFocus.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_passwordCtrl.text != _confirmCtrl.text) {
      setState(() => _error = 'Passwords do not match');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.registerRequest(
        fullName: '${_firstNameCtrl.text.trim()} ${_lastNameCtrl.text.trim()}'.trim(),
        phone: _phoneCtrl.text.trim(),
        pin: _passwordCtrl.text,
      );
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
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
                  OmniTopNav(onBack: () => Navigator.maybePop(context)),
                  const SizedBox(height: 24),
                  _buildHeading(),
                  const SizedBox(height: 32),
                  _buildAvatarPicker(),
                  const SizedBox(height: 32),
                  _buildForm(),
                  const SizedBox(height: 20),
                  _buildTerms(),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    OmniErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 8),
                  OmniLimeButton(
                    label: 'Create Account',
                    loading: _loading,
                    onTap: _register,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Already have an account?', style: GoogleFonts.manrope(
                        fontSize: 14, color: kGray)),
                      const SizedBox(width: 6),
                      GestureDetector(
                        onTap: () => Navigator.maybePop(context),
                        child: Text('Log in', style: GoogleFonts.manrope(
                          fontSize: 14, fontWeight: FontWeight.w700, color: kLime)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Create your\nOmniPlex account', style: GoogleFonts.spaceGrotesk(
          fontSize: 30, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.75, height: 1.25)),
        const SizedBox(height: 10),
        Text('Sign up to manage your gyms, bookings and access.',
          style: GoogleFonts.manrope(fontSize: 14, color: kGray, height: 1.625)),
      ],
    );
  }

  Widget _buildAvatarPicker() {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                width: 96, height: 96,
                decoration: BoxDecoration(
                  color: kCard,
                  shape: BoxShape.circle,
                  border: Border.all(color: kBorder2, width: 2),
                ),
                child: const Icon(Icons.photo_camera_outlined, color: kGray, size: 28),
              ),
              Positioned(
                right: 0, bottom: 0,
                child: Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: kLime,
                    shape: BoxShape.circle,
                    border: Border.all(color: kBg, width: 2),
                  ),
                  child: const Icon(Icons.add, color: kBg, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Add photo (optional)', style: GoogleFonts.manrope(
            fontSize: 12, color: kGray)),
        ],
      ),
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: OmniField(
              label: 'FIRST NAME',
              child: _textInput(_firstNameCtrl, 'John'),
            )),
            const SizedBox(width: 16),
            Expanded(child: OmniField(
              label: 'LAST NAME',
              child: _textInput(_lastNameCtrl, 'Doe'),
            )),
          ],
        ),
        const SizedBox(height: 20),
        OmniField(
          label: 'MOBILE NUMBER',
          prefix: const OmniPhonePrefix(),
          child: _textInput(_phoneCtrl, '555 123 4567', type: TextInputType.phone),
        ),
        const SizedBox(height: 20),
        OmniField(
          label: 'EMAIL',
          focusNode: _emailFocus,
          child: _textInput(_emailCtrl, 'john.doe@email.com',
            type: TextInputType.emailAddress, focus: _emailFocus),
        ),
        const SizedBox(height: 20),
        OmniField(
          label: 'PASSWORD',
          suffix: _eyeButton(_passVisible, () => setState(() => _passVisible = !_passVisible)),
          child: TextField(
            controller: _passwordCtrl,
            obscureText: !_passVisible,
            style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Create a password',
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        OmniField(
          label: 'CONFIRM PASSWORD',
          suffix: _eyeButton(_confirmVisible, () => setState(() => _confirmVisible = !_confirmVisible)),
          child: TextField(
            controller: _confirmCtrl,
            obscureText: !_confirmVisible,
            style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Re-enter your password',
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            onSubmitted: (_) => _register(),
          ),
        ),
      ],
    );
  }

  Widget _textInput(TextEditingController ctrl, String hint, {
    TextInputType type = TextInputType.text,
    FocusNode? focus,
  }) {
    return TextField(
      controller: ctrl,
      focusNode: focus,
      keyboardType: type,
      style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _eyeButton(bool visible, VoidCallback onPressed) {
    return IconButton(
      icon: Icon(visible ? Icons.visibility_off : Icons.visibility, color: kDim, size: 20),
      onPressed: onPressed,
    );
  }

  Widget _buildTerms() {
    return Text.rich(
      TextSpan(
        style: GoogleFonts.manrope(fontSize: 12, color: kDim, height: 1.625),
        children: [
          const TextSpan(text: 'By continuing you agree to our '),
          TextSpan(text: 'Terms', style: GoogleFonts.manrope(
            fontSize: 12, color: kGray, fontWeight: FontWeight.w600)),
          const TextSpan(text: ' and '),
          TextSpan(text: 'Privacy Policy', style: GoogleFonts.manrope(
            fontSize: 12, color: kGray, fontWeight: FontWeight.w600)),
          const TextSpan(text: '.'),
        ],
      ),
    );
  }
}
