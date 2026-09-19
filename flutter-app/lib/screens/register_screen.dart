import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../models/location.dart';
import '../services/api_service.dart';
import '../theme/app_colors.dart';
import '../widgets/tenant_logo.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name    = TextEditingController();
  final _phone   = TextEditingController();
  final _email   = TextEditingController();
  final _pinCtrl = TextEditingController();

  bool _loading        = false;
  bool _locLoading     = true;
  String? _error;
  bool _submitted      = false;

  List<GymLocation> _locations   = [];
  bool _multiLocation             = false;
  String? _selectedLocationId;

  String get _pin => _pinCtrl.text;

  @override
  void initState() {
    super.initState();
    _loadLocations();
  }

  Future<void> _loadLocations() async {
    try {
      final config = context.read<TenantConfig>();
      final api    = ApiService(config);
      final result = await api.fetchLocations();
      if (mounted) {
        setState(() {
          _locations      = result.locations;
          _multiLocation  = result.multiLocation;
          _locLoading     = false;
          if (_locations.length == 1) _selectedLocationId = _locations.first.id;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _locLoading = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _email.dispose();
    _pinCtrl.dispose();
    super.dispose();
  }

  void _onPinKey(String digit) {
    if (_pin.length < 4) {
      _pinCtrl.text = _pin + digit;
      setState(() {});
    }
  }

  void _onPinDelete() {
    if (_pin.isNotEmpty) {
      _pinCtrl.text = _pin.substring(0, _pin.length - 1);
      setState(() {});
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_multiLocation && _locations.length > 1 && _selectedLocationId == null) {
      setState(() => _error = AppStrings.of(context).registerSelectBranch);
      return;
    }
    if (_pin.length != 4) {
      setState(() => _error = AppStrings.of(context).registerEnterPin);
      return;
    }
    setState(() { _loading = true; _error = null; });

    try {
      final config = context.read<TenantConfig>();
      final api    = ApiService(config);
      await api.registerRequest(
        fullName:   _name.text.trim(),
        phone:      _phone.text.trim(),
        email:      _email.text.trim().isEmpty ? null : _email.text.trim(),
        pin:        _pin,
        locationId: _selectedLocationId,
      );
      if (mounted) setState(() { _submitted = true; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = AppStrings.of(context).unexpectedError; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(AppStrings.of(context).registerTitle),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1A1035), AppColors.bg, Color(0xFF0D1F1A)],
          ),
        ),
        child: SafeArea(
          child: _submitted ? _buildSuccess() : _buildForm(),
        ),
      ),
    );
  }

  Widget _buildSuccess() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_outline, color: AppColors.lime, size: 72),
            const SizedBox(height: 20),
            Text(AppStrings.of(context).registerSentTitle,
                style: Theme.of(context).textTheme.headlineMedium,
                textAlign: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              AppStrings.of(context).registerSentBody,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppStrings.of(context).registerBackToLogin),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm() {
    final config = context.read<TenantConfig>();
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Gym branding header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                children: [
                  const TenantLogo(size: 44, borderRadius: 12, showShadow: false),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(config.appName,
                            style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white, fontSize: 15)),
                        Text(AppStrings.of(context).registerMembership,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(AppStrings.of(context).registerCreateAccount,
                style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 8),
            Text(
              AppStrings.of(context).registerSubtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 28),

            // Name
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).registerFullName,
                prefixIcon: const Icon(Icons.person_outline, color: AppColors.textSecondary),
              ),
              validator: (v) => v == null || v.trim().isEmpty ? AppStrings.of(context).registerNameRequired : null,
            ),
            const SizedBox(height: 16),

            // Phone
            TextFormField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d\+\-\s]'))],
              decoration: InputDecoration(
                labelText: AppStrings.of(context).registerMobile,
                prefixIcon: const Icon(Icons.phone_outlined, color: AppColors.textSecondary),
                hintText: '6901234567',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return AppStrings.of(context).registerMobileRequired;
                final digits = v.replaceAll(RegExp(r'\D'), '');
                if (digits.length < 10) return AppStrings.of(context).registerInvalidMobile;
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Email (optional)
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: AppStrings.of(context).registerEmail,
                prefixIcon: const Icon(Icons.email_outlined, color: AppColors.textSecondary),
                hintText: 'example@email.com',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return null;
                if (!v.contains('@') || !v.contains('.')) return AppStrings.of(context).registerInvalidEmail;
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Location selector — only if multi-location with >1 locations
            if (!_locLoading && _multiLocation && _locations.length > 1) ...[
              DropdownButtonFormField<String>(
                value: _selectedLocationId,
                decoration: InputDecoration(
                  labelText: AppStrings.of(context).registerBranch,
                  prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.textSecondary),
                ),
                dropdownColor: AppColors.surface,
                items: _locations.map((loc) => DropdownMenuItem(
                  value: loc.id,
                  child: Text(loc.name),
                )).toList(),
                onChanged: (v) => setState(() { _selectedLocationId = v; _error = null; }),
                validator: (v) => v == null ? AppStrings.of(context).registerBranchRequired : null,
              ),
              const SizedBox(height: 16),
            ],
            if (_locLoading) ...[
              const Center(child: CircularProgressIndicator()),
              const SizedBox(height: 16),
            ],

            // Password (PIN)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.surface.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(AppStrings.of(context).registerChoosePin,
                      style: Theme.of(context).textTheme.bodyMedium),
                  const SizedBox(height: 4),
                  Text(AppStrings.of(context).registerPinHint,
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(4, (i) {
                      final filled = i < _pin.length;
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 8),
                        width: 18, height: 18,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: filled ? AppColors.lime : Colors.transparent,
                          border: Border.all(
                            color: filled ? AppColors.lime : AppColors.border,
                            width: 2,
                          ),
                        ),
                      );
                    }),
                  ),
                  const SizedBox(height: 16),
                  _Numpad(onKey: _onPinKey, onDelete: _onPinDelete),
                ],
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
                ),
                child: Text(_error!, style: const TextStyle(color: AppColors.orange)),
              ),
            ],
            const SizedBox(height: 28),
            ElevatedButton(
              onPressed: _loading ? null : _submit,
              child: _loading
                  ? const SizedBox(height: 20, width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg))
                  : Text(AppStrings.of(context).registerSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _Numpad extends StatelessWidget {
  final void Function(String) onKey;
  final VoidCallback onDelete;
  const _Numpad({required this.onKey, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = ['1','2','3','4','5','6','7','8','9','','0','⌫'];
    return GridView.count(
      crossAxisCount: 3,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 2.2,
      mainAxisSpacing: 4,
      crossAxisSpacing: 4,
      children: keys.map((k) {
        if (k.isEmpty) return const SizedBox();
        final isDelete = k == '⌫';
        return TextButton(
          onPressed: isDelete ? onDelete : () => onKey(k),
          style: TextButton.styleFrom(
            foregroundColor: isDelete ? AppColors.textSecondary : AppColors.textPrimary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: AppColors.surface,
          ),
          child: Text(k, style: TextStyle(fontSize: isDelete ? 20 : 22, fontWeight: FontWeight.w600)),
        );
      }).toList(),
    );
  }
}
