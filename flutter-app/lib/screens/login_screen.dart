import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/push_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tenant_logo.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneCtrl = TextEditingController();
  final _pinCtrl   = TextEditingController();
  final _phoneFocus = FocusNode();
  final _pinFocus   = FocusNode();
  // Staff login
  final _emailCtrl    = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _staffMode = false;
  bool _passwordVisible = false;

  bool _loading = false;
  bool _biometricLoading = false;
  String? _error;
  String _biometricLabel = 'Βιομετρικά';
  IconData _biometricIcon = Icons.fingerprint;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initBiometric());
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _pinCtrl.dispose();
    _phoneFocus.dispose();
    _pinFocus.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _initBiometric() async {
    final auth = context.read<AuthService>();
    final bio  = BiometricAuthService.instance;
    if (auth.biometricAvailable || auth.canUnlockWithBiometrics) {
      _biometricLabel = await bio.biometricLabel();
      _biometricIcon  = await bio.biometricIcon();
      if (mounted) setState(() {});
    }
    if (!auth.canUnlockWithBiometrics) return;
    await _biometricLogin(silentFail: true);
  }

  Future<void> _submit() async {
    if (_staffMode) { await _submitStaff(); return; }
    final phone = _phoneCtrl.text.trim();
    final pin   = _pinCtrl.text.trim();
    if (phone.isEmpty) {
      setState(() => _error = AppStrings.of(context).loginEnterMobile);
      return;
    }
    if (pin.length != 4) {
      setState(() => _error = AppStrings.of(context).loginEnterPin);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.login(phone, pin);
      if (!mounted) return;
      setState(() => _loading = false);
      if (auth.biometricAvailable && !await auth.isBiometricLoginEnabled()) {
        _offerBiometricSetup();
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = AppStrings.of(context).unexpectedError; _loading = false; });
    }
  }

  Future<void> _submitStaff() async {
    final email    = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (email.isEmpty) {
      setState(() => _error = AppStrings.of(context).loginEnterEmail);
      return;
    }
    if (password.isEmpty) {
      setState(() => _error = AppStrings.of(context).loginEnterPassword);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final auth = context.read<AuthService>();
      await auth.staffLogin(email, password);
      if (mounted) setState(() => _loading = false);
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = AppStrings.of(context).unexpectedError; _loading = false; });
    }
  }

  Future<void> _offerBiometricSetup() async {
    final auth  = context.read<AuthService>();
    final label = await BiometricAuthService.instance.biometricLabel();
    if (!mounted) return;
    final enable = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppStrings.of(context).loginEnableBiometricTitle(label)),
        content: Text(AppStrings.of(context).loginEnableBiometricBody(label)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(AppStrings.of(context).loginNotNow)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(AppStrings.of(context).loginEnableBiometricEnable)),
        ],
      ),
    );
    if (enable == true) await auth.enableBiometricLogin();
  }

  void _showForgotPassword() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppStrings.of(context).loginForgotPinTitle),
        content: Text(AppStrings.of(context).loginForgotPinBody),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(AppStrings.of(context).ok),
          ),
        ],
      ),
    );
  }

  Future<void> _biometricLogin({bool silentFail = false}) async {
    setState(() { _biometricLoading = true; _error = null; });
    final ok = await context.read<AuthService>().unlockWithBiometrics();
    if (!mounted) return;
    if (!ok && !silentFail) {
      setState(() { _error = AppStrings.of(context).loginBiometricFailed; _biometricLoading = false; });
      return;
    }
    if (mounted) setState(() => _biometricLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<TenantConfig>();
    final auth   = context.watch<AuthService>();
    final showBiometric = auth.canUnlockWithBiometrics || auth.biometricAvailable;

    return Scaffold(
      body: SizedBox.expand(
        child: DecoratedBox(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1A1035), AppColors.bg, Color(0xFF0D1F1A)],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 40),
                  const TenantLogo(),
                  const SizedBox(height: 20),
                  Text(
                    config.appName,
                    style: Theme.of(context).textTheme.headlineLarge,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    config.label('home_hero', AppStrings.of(context).loginBookEasy),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (auth.canUnlockWithBiometrics) ...[
                    const SizedBox(height: 28),
                    OutlinedButton.icon(
                      onPressed: _biometricLoading ? null : () => _biometricLogin(),
                      icon: _biometricLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : Icon(_biometricIcon, size: 24),
                      label: Text('${AppStrings.of(context).loginWithBiometric} $_biometricLabel'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.lime,
                        side: BorderSide(color: AppColors.lime),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(AppStrings.of(context).loginOrWith,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium),
                  ],
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AppColors.surface.withValues(alpha: 0.85),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        if (!_staffMode) ...[
                          // Customer: phone + PIN
                          TextFormField(
                            controller: _phoneCtrl,
                            focusNode: _phoneFocus,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\s]'))],
                            decoration: InputDecoration(
                              labelText: AppStrings.of(context).loginMobile,
                              prefixIcon: Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                              hintText: '6901234567',
                            ),
                            onFieldSubmitted: (_) => _pinFocus.requestFocus(),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _pinCtrl,
                            focusNode: _pinFocus,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.done,
                            obscureText: true,
                            maxLength: 4,
                            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                            decoration: InputDecoration(
                              labelText: AppStrings.of(context).loginPin,
                              prefixIcon: Icon(Icons.lock_outline, color: AppColors.textSecondary),
                              counterText: '',
                            ),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ] else ...[
                          // Staff: email + password
                          Row(
                            children: [
                              GestureDetector(
                                onTap: () => setState(() { _staffMode = false; _error = null; }),
                                child: const Icon(Icons.arrow_back, color: AppColors.textSecondary, size: 20),
                              ),
                              const SizedBox(width: 10),
                              Text(AppStrings.of(context).loginStaffTitle,
                                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
                            ],
                          ),
                          const SizedBox(height: 20),
                          TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            textInputAction: TextInputAction.next,
                            autocorrect: false,
                            decoration: const InputDecoration(
                              labelText: 'Email',
                              prefixIcon: Icon(Icons.email_outlined, color: AppColors.textSecondary),
                            ),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordCtrl,
                            obscureText: !_passwordVisible,
                            textInputAction: TextInputAction.done,
                            decoration: InputDecoration(
                              labelText: AppStrings.of(context).loginPassword,
                              prefixIcon: const Icon(Icons.lock_outline, color: AppColors.textSecondary),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _passwordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () => setState(() => _passwordVisible = !_passwordVisible),
                              ),
                            ),
                            onFieldSubmitted: (_) => _submit(),
                          ),
                        ],

                        if (_error != null) ...[
                          const SizedBox(height: 16),
                          Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: AppColors.orange, fontSize: 13, height: 1.35)),
                        ],
                        if (!_staffMode) ...[
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _showForgotPassword,
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: EdgeInsets.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              child: Text(AppStrings.of(context).loginForgotPin, style: const TextStyle(fontSize: 13)),
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _loading ? null : _submit,
                            child: _loading
                                ? const SizedBox(height: 20, width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                                : Text(AppStrings.of(context).loginTitle),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showBiometric && !auth.canUnlockWithBiometrics) ...[
                    const SizedBox(height: 12),
                    Text(
                      AppStrings.of(context).loginAfterFirst,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12),
                    ),
                  ],
                  const SizedBox(height: 20),
                  if (!_staffMode) ...[
                    TextButton(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterScreen())),
                      child: Text(AppStrings.of(context).loginNoAccount),
                    ),
                    const SizedBox(height: 4),
                    TextButton(
                      onPressed: () => setState(() { _staffMode = true; _error = null; }),
                      style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.badge_outlined, size: 15, color: AppColors.textSecondary),
                          const SizedBox(width: 6),
                          Text(AppStrings.of(context).loginAsStaff, style: const TextStyle(fontSize: 13)),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _switchBusiness,
                    style: TextButton.styleFrom(foregroundColor: AppColors.textSecondary),
                    child: Text(
                      '${config.appName} · ${AppStrings.of(context).loginSwitchGym}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _switchBusiness() async {
    final auth = context.read<AuthService>();
    // Unregister FCM token from this gym before switching
    await PushService.instance.unregisterFromCurrentGym(auth);
    // Logout clears the token for this gym (keeping biometric prefs intact for it)
    await auth.logout();
    await TenantConfig.clearCachedTenant();
    if (!mounted) return;
    AppBootstrap.switchBusiness();
  }
}

