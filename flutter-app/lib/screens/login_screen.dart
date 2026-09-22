import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/push_service.dart';
import '../widgets/omni_design.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _phoneFocus   = FocusNode();
  final _passFocus    = FocusNode();

  bool _loading = false;
  bool _passwordVisible = false;
  String? _error;

  bool _showBiometric = false;
  String _biometricLabel = '';
  IconData _biometricIcon = Icons.fingerprint;

  @override
  void initState() {
    super.initState();
    _phoneFocus.addListener(() => setState(() {}));
    _passFocus.addListener(() => setState(() {}));
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passwordCtrl.dispose();
    _phoneFocus.dispose();
    _passFocus.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    final auth = context.read<AuthService>();
    final bio  = BiometricAuthService.instance;
    if (auth.biometricAvailable || auth.canUnlockWithBiometrics) {
      final label = await bio.biometricLabel();
      final icon  = await bio.biometricIcon();
      if (mounted) {
        setState(() {
          _biometricLabel = label;
          _biometricIcon  = icon;
          _showBiometric  = true;
        });
      }
    }
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.login(_phoneCtrl.text.trim(), _passwordCtrl.text);
      if (mounted) {
        await PushService.instance.registerWithAuth(auth);
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _biometricLogin() async {
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      final ok = await auth.unlockWithBiometrics();
      if (!ok || !mounted) { setState(() => _loading = false); return; }
      await PushService.instance.registerWithAuth(auth);
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
                  const SizedBox(height: 32),
                  _buildHeading(),
                  const SizedBox(height: 32),
                  _buildForm(),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    OmniErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 16),
                  OmniLimeButton(label: 'Log in', loading: _loading, onTap: _login),
                  const SizedBox(height: 32),
                  _buildDivider(),
                  const SizedBox(height: 32),
                  _buildSocialButtons(),
                  const SizedBox(height: 32),
                  _buildFooter(),
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
        Text('Welcome back', style: GoogleFonts.spaceGrotesk(
          fontSize: 36, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.9)),
        const SizedBox(height: 10),
        Text('Log in to manage your gyms, bookings and access.',
          style: GoogleFonts.manrope(fontSize: 14, color: kGray, height: 1.625)),
      ],
    );
  }

  Widget _buildForm() {
    return Column(
      children: [
        OmniField(
          label: 'MOBILE NUMBER',
          focusNode: _phoneFocus,
          prefix: const OmniPhonePrefix(),
          child: TextField(
            controller: _phoneCtrl,
            focusNode: _phoneFocus,
            keyboardType: TextInputType.phone,
            style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: '555 123 4567',
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
          ),
        ),
        const SizedBox(height: 20),
        OmniField(
          label: 'PASSWORD',
          focusNode: _passFocus,
          suffix: IconButton(
            icon: Icon(_passwordVisible ? Icons.visibility_off : Icons.visibility,
              color: kDim, size: 20),
            onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
          ),
          child: TextField(
            controller: _passwordCtrl,
            focusNode: _passFocus,
            obscureText: !_passwordVisible,
            style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your password',
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            ),
            onSubmitted: (_) => _login(),
          ),
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerRight,
          child: Text('Forgot password?', style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600, color: kLime)),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      const Expanded(child: Divider(color: kBorder, thickness: 1)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('OR CONTINUE WITH', style: GoogleFonts.spaceGrotesk(
          fontSize: 11, color: kDim, letterSpacing: 2.2)),
      ),
      const Expanded(child: Divider(color: kBorder, thickness: 1)),
    ]);
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        OmniOutlineButton(icon: Icons.apple, label: 'Continue with Apple', onTap: () {}),
        const SizedBox(height: 16),
        OmniOutlineButton(icon: Icons.g_mobiledata, label: 'Continue with Google', onTap: () {}),
        if (_showBiometric) ...[
          const SizedBox(height: 16),
          OmniOutlineButton(icon: _biometricIcon,
            label: 'Continue with $_biometricLabel', onTap: _biometricLogin),
        ],
      ],
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text("Don't have an account?", style: GoogleFonts.manrope(
          fontSize: 14, color: kGray)),
        const SizedBox(width: 6),
        GestureDetector(
          onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const RegisterScreen())),
          child: Text('Sign up', style: GoogleFonts.manrope(
            fontSize: 14, fontWeight: FontWeight.w700, color: kLime)),
        ),
      ],
    );
  }
}
