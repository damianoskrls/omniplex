import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app.dart';
import '../app_nav.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../services/biometric_auth_service.dart';
import '../services/global_auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';
import '../widgets/ui_kit.dart';
import 'goals_screen.dart';
import 'my_qr_screen.dart';
import 'electronic_documents_screen.dart';
import 'member_intake_screen.dart';
import 'rewards_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'staff_messages_screen.dart';
import 'payments_screen.dart';
import 'workout_metrics_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key, this.onRemoveGym, this.onEnterAsRole});

  final Future<void> Function()? onRemoveGym;
  final Future<void> Function(GlobalGym)? onEnterAsRole;

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _biometricEnabled = false;
  String _biometricLabel = '';
  IconData _biometricIcon = Icons.fingerprint;

  @override
  void initState() {
    super.initState();
    _loadBiometricState();
  }

  Future<void> _loadBiometricState() async {
    if (!mounted) return;
    final auth = context.read<AuthService>();
    final bio = BiometricAuthService.instance;
    final enabled = await bio.isBiometricEnabled(auth.api.bizId);
    final label = await bio.biometricLabel();
    final icon = await bio.biometricIcon();
    if (mounted) {
      setState(() {
        _biometricEnabled = enabled;
        _biometricLabel = label;
        _biometricIcon = icon;
      });
    }
  }

  Future<void> _requestExtraRole(BuildContext context, {required String role, String? specialty}) async {
    final config = context.read<TenantConfig>();
    final auth = context.read<AuthService>();
    final global = GlobalAuthService();
    await global.init();
    if (!context.mounted) return;
    if (!global.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Συνδέσου από το OmniPlex για να στείλεις αίτημα.')),
      );
      return;
    }
    if (role == 'member' && global.gyms.any((g) => g.businessId == config.businessId && !g.isStaff)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Είσαι ήδη ασκούμενος σε αυτό το γυμναστήριο.')),
      );
      return;
    }
    String? locationId;
    try {
      final locs = await auth.api.fetchLocations();
      if (locs.locations.length > 1) {
        if (!context.mounted) return;
        locationId = await showDialog<String>(
          context: context,
          builder: (ctx) => SimpleDialog(
            title: const Text('Σε ποιο κατάστημα;'),
            children: [
              for (final loc in locs.locations)
                SimpleDialogOption(
                  onPressed: () => Navigator.pop(ctx, loc.id),
                  child: Text(loc.name),
                ),
            ],
          ),
        );
        if (locationId == null) return;
      } else if (locs.locations.length == 1) {
        locationId = locs.locations.first.id;
      }
    } catch (_) {}
    try {
      final user = global.user;
      final res = await global.submitJoinRequest(
        businessId: config.businessId,
        role: role,
        specialty: specialty,
        fullName: user?.fullName ?? auth.user?.fullName,
        phone: user?.phone ?? auth.user?.phone,
        email: user?.email,
        locationId: locationId,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(res['message']?.toString() ?? 'Το αίτημα στάλθηκε. Ο διαχειριστής θα το δει για έγκριση.')),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final config = context.read<TenantConfig>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final fitness = user.fitnessProfile;
    final isStaff = user.isStaff;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        GradientCard(
          colors: const [Color(0xFF3D2F8F), AppColors.purple],
          child: Column(
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 2),
                  gradient: const LinearGradient(colors: [AppColors.pink, AppColors.orange]),
                ),
                alignment: Alignment.center,
                child: Text(
                  user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: Colors.white),
                ),
              ),
              const SizedBox(height: 14),
              Text(user.fullName, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: Colors.white)),
              const SizedBox(height: 4),
              Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
              if (user.phone != null) ...[
                const SizedBox(height: 4),
                Text(user.phone!, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
              ],
              if (!isStaff && fitness.fitnessGoalLabel != null) ...[
                const SizedBox(height: 12),
                PillChip(
                  label: fitness.fitnessGoalLabel!,
                  color: AppColors.teal.withValues(alpha: 0.2),
                  textColor: AppColors.teal,
                ),
              ],
              if (!isStaff && (fitness.weightKg != null || fitness.targetWeightKg != null)) ...[
                const SizedBox(height: 8),
                Text(
                  [
                    if (fitness.weightKg != null) '${fitness.weightKg!.toStringAsFixed(1)} kg',
                    if (fitness.targetWeightKg != null) AppStrings.of(context).profileTargetWeight(fitness.targetWeightKg!),
                  ].join(' · '),
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
              ],
              if (!isStaff && config.featureLoyaltyPoints) ...[
                const SizedBox(height: 16),
                PillChip(
                  label: '${config.label('loyalty_label', 'Πόντοι')}: ${user.loyaltyPoints}',
                  color: AppColors.lime.withValues(alpha: 0.25),
                  textColor: AppColors.lime,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              if (AppNav.leaveGym != null) ...[
                _MenuTile(
                  icon: Icons.arrow_back_rounded,
                  title: 'Πίσω στο OmniPlex',
                  subtitle: 'Έξοδος από αυτόν τον ρόλο',
                  onTap: () {
                    Navigator.of(context).pop();
                    AppNav.leaveGym!();
                  },
                ),
                const Divider(height: 1, indent: 56),
              ],
              if (config.featureQrCheckin) ...[
                _MenuTile(
                  icon: Icons.qr_code_2_outlined,
                  title: AppStrings.of(context).profileQrTitle,
                  subtitle: AppStrings.of(context).profileQrSubtitle,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MyQrScreen())),
                ),
                const Divider(height: 1, indent: 56),
              ],
              if (!isStaff) ...[
                _MenuTile(
                  icon: Icons.track_changes_outlined,
                  title: AppStrings.of(context).profileGoals,
                  subtitle: fitness.fitnessGoalLabel ?? AppStrings.of(context).profileGoalsSubtitle(''),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GoalsScreen())),
                ),
                const Divider(height: 1, indent: 56),
                _MenuTile(
                  icon: Icons.insights_outlined,
                  title: AppStrings.of(context).profileMetrics,
                  subtitle: AppStrings.of(context).profileMetricsSubtitle,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutMetricsScreen())),
                ),
                const Divider(height: 1, indent: 56),
              ],
              if (auth.biometricAvailable)
                SwitchListTile(
                  secondary: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.purple.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(_biometricIcon, color: AppColors.purple, size: 20),
                  ),
                  title: Text(AppStrings.of(context).profileBiometricLogin(_biometricLabel), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(AppStrings.of(context).profileBiometricSubtitle(_biometricLabel)),
                  value: _biometricEnabled,
                  onChanged: (value) async {
                    if (value) {
                      final ok = await auth.enableBiometricLogin();
                      if (!mounted) return;
                      if (ok) {
                        setState(() => _biometricEnabled = true);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(AppStrings.of(context).profileBiometricFailed)),
                        );
                      }
                    } else {
                      await auth.disableBiometricLogin();
                      if (mounted) setState(() => _biometricEnabled = false);
                    }
                  },
                ),
              if (auth.biometricAvailable) const Divider(height: 1, indent: 56),
              if (!isStaff) ...[
                _MenuTile(
                  icon: Icons.receipt_long_outlined,
                  title: AppStrings.of(context).profilePayments,
                  subtitle: AppStrings.of(context).profilePaymentsSubtitle,
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PaymentsScreen())),
                ),
                const Divider(height: 1, indent: 56),
              ],
              if (!isStaff) ...[
                _MenuTile(
                  icon: Icons.health_and_safety_outlined,
                  title: 'Κάρτα υγείας',
                  subtitle: 'Στόχος, παθήσεις, φάρμακα, έγγραφο γιατρού',
                  onTap: () {
                    final base = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => MemberIntakeScreen(
                        apiBase: '$base/api',
                        token: auth.api.token ?? '',
                        bizId: config.businessId,
                      ),
                    ));
                  },
                ),
                const Divider(height: 1, indent: 56),
              ],
              if (!isStaff && config.featureLoyaltyPoints) ...[
                _MenuTile(
                  icon: Icons.card_giftcard_outlined,
                  title: 'Επιβράβευση',
                  subtitle: 'Εκπτώσεις και προσφορές για συχνούς',
                  onTap: () {
                    final base = config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => RewardsScreen(
                        apiBase: '$base/api',
                        token: auth.api.token ?? '',
                      ),
                    ));
                  },
                ),
                const Divider(height: 1, indent: 56),
              ],
              if (!isStaff) ...[
                _MenuTile(
                  icon: Icons.draw_outlined,
                  title: 'Ηλεκτρονικές εγγραφές',
                  subtitle: 'Εγγραφή, ανανέωση, δήλωση συμμετοχής',
                  onTap: () {
                    final auth = context.read<AuthService>();
                    final base = auth.config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');
                    Navigator.push(context, MaterialPageRoute(
                      builder: (_) => ElectronicDocumentsScreen.gym(
                        apiBase: '$base/api',
                        token: auth.api.token ?? '',
                      ),
                    ));
                  },
                ),
                const Divider(height: 1, indent: 56),
              ],
              _MenuTile(
                icon: Icons.notifications_outlined,
                title: AppStrings.of(context).profileNotifications,
                subtitle: AppStrings.of(context).profileNotifSubtitle,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const NotificationsScreen())),
              ),
              const Divider(height: 1, indent: 56),
              _MenuTile(
                icon: Icons.chat_bubble_outline,
                title: AppStrings.of(context).profileMessages,
                subtitle: AppStrings.of(context).profileMessagesSubtitle,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => isStaff ? const StaffMessagesScreen() : const MessagesScreen(),
                  ),
                ),
              ),
              const Divider(height: 1, indent: 56),
              _MenuTile(icon: Icons.email_outlined, title: AppStrings.of(context).email, subtitle: user.email),
              const Divider(height: 1, indent: 56),
              if (user.phone != null)
                _MenuTile(icon: Icons.phone_outlined, title: AppStrings.of(context).profilePhone, subtitle: user.phone!),
              if (user.phone != null) const Divider(height: 1, indent: 56),
              _RoleSwitcher(
                businessId: config.businessId,
                currentIsStaff: isStaff,
                currentKind: user.isNutritionist ? 'nutritionist' : user.staffKind,
                onEnterAsRole: widget.onEnterAsRole,
                onRequest: (role, specialty) => _requestExtraRole(context, role: role, specialty: specialty),
              ),
              _MenuTile(
                icon: Icons.fitness_center,
                title: config.appName,
                subtitle: user.isNutritionist
                    ? 'Διατροφολόγος'
                    : user.staffKind == 'physiotherapist'
                        ? 'Φυσιοθεραπευτής'
                        : isStaff
                            ? (user.staffRole ?? 'Trainer')
                            : AppStrings.of(context).activeMember,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: ListenableBuilder(
            listenable: LanguageService.instance,
            builder: (_, __) {
              final isEl = LanguageService.instance.isGreek;
              final s = AppStrings.of(context);
              return ListTile(
                leading: Container(
                  width: 36, height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A2A3A),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.language_rounded, size: 18, color: Colors.white60),
                ),
                title: Text(
                  s.languageLabel,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LangChip(label: 'ΕΛ', active: isEl, onTap: () => LanguageService.instance.setLocale(const Locale('el'))),
                    const SizedBox(width: 6),
                    _LangChip(label: 'EN', active: !isEl, onTap: () => LanguageService.instance.setLocale(const Locale('en'))),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 16),
        if (widget.onRemoveGym != null)
          // Came from Omniplex — show "Remove gym" instead of logout
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: _MenuTile(
              icon: Icons.remove_circle_outline_rounded,
              title: isStaff ? 'Αφαίρεση ως trainer' : 'Αφαίρεση γυμναστηρίου',
              iconColor: AppColors.orange,
              titleColor: AppColors.orange,
              onTap: () async {
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (_) => AlertDialog(
                    backgroundColor: const Color(0xFF16171B),
                    title: const Text('Αφαίρεση γυμναστηρίου',
                        style: TextStyle(color: Colors.white)),
                    content: Text(
                      isStaff
                          ? 'Θα αφαιρεθείς ως trainer από αυτό το γυμναστήριο. Η σύνδεσή σου ως ασκούμενος, αν υπάρχει, μένει.'
                          : 'Θα αφαιρεθείς ως ασκούμενος από αυτό το γυμναστήριο. Η σύνδεσή σου ως trainer, αν υπάρχει, μένει.',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Άκυρο',
                            style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(context, true),
                        child: Text('Αφαίρεση',
                            style: TextStyle(color: AppColors.orange)),
                      ),
                    ],
                  ),
                );
                if (confirmed != true) return;
                await widget.onRemoveGym!();
              },
            ),
          )
        else
          SurfaceCard(
            padding: EdgeInsets.zero,
            child: _MenuTile(
              icon: Icons.logout,
              title: AppStrings.of(context).profileLogout,
              iconColor: AppColors.orange,
              titleColor: AppColors.orange,
              onTap: () async {
                await auth.logout();
                appNavigatorKey.currentState?.popUntil((route) => route.isFirst);
              },
            ),
          ),
      ],
    );
  }
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.iconColor,
    this.titleColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? iconColor;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: (iconColor ?? AppColors.purple).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: iconColor ?? AppColors.purple, size: 20),
      ),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary)),
      subtitle: subtitle != null ? Text(subtitle!, style: Theme.of(context).textTheme.bodyMedium) : null,
      trailing: onTap != null ? const Icon(Icons.chevron_right, color: AppColors.textSecondary) : null,
    );
  }
}

class _LangChip extends StatelessWidget {
  const _LangChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const lime = Color(0xFFB8F55E);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: active ? lime.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? lime.withValues(alpha: 0.5) : Colors.white12),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: active ? lime : Colors.white38,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _RoleSwitcher extends StatefulWidget {
  const _RoleSwitcher({
    required this.businessId,
    required this.currentIsStaff,
    required this.currentKind,
    required this.onEnterAsRole,
    required this.onRequest,
  });

  final String businessId;
  final bool currentIsStaff;
  final String? currentKind;
  final Future<void> Function(GlobalGym)? onEnterAsRole;
  final void Function(String role, String? specialty) onRequest;

  @override
  State<_RoleSwitcher> createState() => _RoleSwitcherState();
}

class _RoleSwitcherState extends State<_RoleSwitcher> {
  List<GlobalGym> _roles = [];
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final global = GlobalAuthService();
    await global.init();
    if (!mounted) return;
    setState(() {
      _roles = global.gyms.where((g) => g.businessId == widget.businessId).toList();
      _ready = true;
    });
  }

  String _label(GlobalGym gym) {
    if (!gym.isStaff) return 'Ασκούμενος';
    if (gym.staffKind == 'nutritionist') return 'Διατροφολόγος';
    if (gym.staffKind == 'physiotherapist') return 'Φυσιοθεραπευτής';
    return 'Trainer';
  }

  bool _isCurrent(GlobalGym gym) {
    if (gym.isStaff != widget.currentIsStaff) return false;
    if (!gym.isStaff) return true;
    return (gym.staffKind ?? 'trainer') == (widget.currentKind ?? 'trainer');
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SizedBox.shrink();
    final have = _roles.map(_label).toSet();
    if (widget.currentIsStaff) {
      have.add(widget.currentKind == 'nutritionist'
          ? 'Διατροφολόγος'
          : widget.currentKind == 'physiotherapist'
              ? 'Φυσιοθεραπευτής'
              : 'Trainer');
    } else {
      have.add('Ασκούμενος');
    }
    final missing = <(String, String?, String, String)>[
      if (!have.contains('Ασκούμενος')) ('member', null, 'Αίτημα ασκούμενου', 'Γίνε και πελάτης στο ίδιο γυμναστήριο'),
      if (!have.contains('Trainer')) ('staff', 'Trainer', 'Αίτημα trainer', 'Γίνε και trainer στο ίδιο γυμναστήριο'),
      if (!have.contains('Διατροφολόγος')) ('staff', 'Διατροφολόγος', 'Αίτημα διατροφολόγου', 'Γίνε και διατροφολόγος στο ίδιο γυμναστήριο'),
      if (!have.contains('Φυσιοθεραπευτής')) ('staff', 'Φυσιοθεραπευτής', 'Αίτημα φυσιοθεραπευτή', 'Γίνε και φυσιοθεραπευτής στο ίδιο γυμναστήριο'),
    ];
    if (_roles.length < 2 && missing.isEmpty) return const SizedBox.shrink();
    return Column(children: [
      if (_roles.length > 1)
        for (final role in _roles.where((g) => !_isCurrent(g))) ...[
          _MenuTile(
            icon: Icons.swap_horiz_rounded,
            title: 'Μπες ως ${_label(role)}',
            subtitle: 'Αλλαγή ρόλου χωρίς να ξαναβρείς το γυμναστήριο',
            onTap: (widget.onEnterAsRole ?? AppNav.enterAsRole) == null
                ? null
                : () => (widget.onEnterAsRole ?? AppNav.enterAsRole)!(role),
          ),
          const Divider(height: 1, indent: 56),
        ],
      for (final ask in missing) ...[
        _MenuTile(
          icon: Icons.add_circle_outline,
          title: ask.$3,
          subtitle: ask.$4,
          onTap: () => widget.onRequest(ask.$1, ask.$2),
        ),
        const Divider(height: 1, indent: 56),
      ],
    ]);
  }
}
