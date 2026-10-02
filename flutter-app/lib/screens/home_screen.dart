import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../app_nav.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/global_auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gym_info_sheet.dart';
import '../widgets/ui_kit.dart';
import 'credits_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'staff_clients_screen.dart';
import 'staff_trials_screen.dart';
import 'staff_leaves_screen.dart';
import 'staff_messages_screen.dart';
import 'staff_schedule_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'qr_checkin_screen.dart';
import 'my_qr_screen.dart';
import 'dropin_screen.dart';
import 'nutrition_screen.dart';
import 'nutritionist_portal_screen.dart';
import 'marketplace_screen.dart';
import 'goals_screen.dart';
import 'payments_screen.dart';
import 'gym_dashboard_screen.dart';
import 'gym_profile_screen.dart';
import 'workout_programs_screen.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/qr_checkin_sheet.dart';
import 'ai_agent_screen.dart';
import 'member_intake_screen.dart';
import '../l10n/tr.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0, this.onSwitchGym, this.onRemoveGym, this.globalAuth, this.onEnterAsRole});

  final int initialTab;
  final VoidCallback? onSwitchGym;
  final Future<void> Function()? onRemoveGym;
  final GlobalAuthService? globalAuth;
  final Future<void> Function(GlobalGym)? onEnterAsRole;

  static void selectTab(int index) => _HomeScreenState.selectTab(index);

  static void selectTabByKey(String key) => _HomeScreenState.selectTabByKey(key);

  static void openNotifications() => _HomeScreenState.openNotifications();

  static void openMessages({String? threadId}) => _HomeScreenState.openMessages(threadId: threadId);

  static void openCommunityPost(String? postId) => _HomeScreenState.openCommunityPost(postId);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static _HomeScreenState? _active;

  late int _index;
  int _unreadCount = 0;
  int _messageUnreadCount = 0;
  bool _hasNutritionAccess = false;
  bool _hasWorkoutPrograms = true;
  bool _switchingRole = false;
  Timer? _unreadTimer;

  static void selectTab(int index) {
    final state = _active;
    if (state == null || !state.mounted) return;
    state.setState(() => state._index = state._clampTab(index));
  }

  static void selectTabByKey(String key) {
    final state = _active;
    if (state == null || !state.mounted) return;
    final index = state._tabItems.indexWhere((tab) => tab.key == key);
    if (index < 0) return;
    state.setState(() => state._index = index);
  }

  static void openNotifications() {
    final state = _active;
    if (state == null || !state.mounted) return;
    state._showNotifications();
  }

  static void openMessages({String? threadId}) {
    final state = _active;
    if (state == null || !state.mounted) return;
    state._showMessages(threadId: threadId);
  }

  static void openCommunityPost(String? postId) {
    final state = _active;
    if (state == null || !state.mounted) return;
    state._openCommunityPost(postId);
  }

  VoidCallback? get _leaveToOmniplex => widget.onSwitchGym ?? AppNav.leaveGym;

  Future<void> Function(GlobalGym)? get _enterRole => widget.onEnterAsRole ?? AppNav.enterAsRole;

  List<GlobalGym> _rolesHere() {
    final config = context.read<TenantConfig>();
    final gyms = widget.globalAuth?.gyms.where((g) => g.businessId == config.businessId).toList() ?? [];
    gyms.sort((a, b) {
      int rank(GlobalGym g) {
        if (g.staffKind == 'nutritionist') return 0;
        if (g.staffKind == 'physiotherapist') return 1;
        if (!g.isStaff) return 2;
        return 3;
      }
      return rank(a).compareTo(rank(b));
    });
    return gyms;
  }

  String _roleLabelForUser(AppUser user) {
    if (user.isNutritionist || user.staffKind == 'nutritionist') return tr('Διατροφολόγος');
    if (user.staffKind == 'physiotherapist') return tr('Φυσιοθεραπευτής');
    if (user.isStaff) return 'Trainer';
    return tr('Ασκούμενος');
  }

  String _roleBlurb(GlobalGym gym) {
    if (!gym.isStaff) return tr('My Gym, κρατήσεις και προπόνηση');
    if (gym.staffKind == 'nutritionist') return tr('Πελάτες, πρόγραμμα και ραντεβού');
    if (gym.staffKind == 'physiotherapist') return tr('Πελάτες και πρόγραμμα');
    return tr('Πρόγραμμα, μηνύματα και πελάτες');
  }

  void _openRoleSheet(AppUser user) {
    final roles = _rolesHere();
    final primary = context.tenantPrimary;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Text(tr('Ρόλος'), style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(tr('Τώρα: ${_roleLabelForUser(user)}'), style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 14),
              if (_leaveToOmniplex != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.pop(ctx);
                        _leaveToOmniplex!();
                      },
                      icon: const Icon(Icons.arrow_back_rounded, size: 18),
                      label: Text(tr('Πίσω στο OmniPlex')),
                    ),
                  ),
                ),
              if (roles.isNotEmpty)
                _InGymRoleBar(
                  roles: roles,
                  currentIsStaff: user.isStaff,
                  currentKind: user.isNutritionist ? 'nutritionist' : user.staffKind,
                  switching: _switchingRole,
                  onEnter: (role) async {
                    Navigator.pop(ctx);
                    await _switchRole(role);
                  },
                  onRequest: () {
                    Navigator.pop(ctx);
                    _openProfile();
                  },
                ),
              const SizedBox(height: 8),
              for (final role in roles)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(tr('${_sheetRoleLabel(role)} · ${_roleBlurb(role)}'),
                    style: TextStyle(
                      fontSize: 13,
                      color: _sheetIsCurrent(role, user) ? primary : AppColors.textSecondary,
                      fontWeight: _sheetIsCurrent(role, user) ? FontWeight.w700 : FontWeight.w500,
                    )),
                ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _openProfile();
                  },
                  child: Text(tr('Προφίλ')),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _sheetRoleLabel(GlobalGym gym) {
    if (!gym.isStaff) return tr('Ασκούμενος');
    if (gym.staffKind == 'nutritionist') return tr('Διατροφολόγος');
    if (gym.staffKind == 'physiotherapist') return tr('Φυσιοθεραπευτής');
    return 'Trainer';
  }

  bool _sheetIsCurrent(GlobalGym gym, AppUser user) {
    if (gym.isStaff != user.isStaff) return false;
    if (!gym.isStaff) return true;
    final kind = user.isNutritionist ? 'nutritionist' : (user.staffKind ?? 'trainer');
    return (gym.staffKind ?? 'trainer') == kind;
  }

  Future<void> _switchRole(GlobalGym role) async {
    if (_switchingRole || _enterRole == null) return;
    setState(() => _switchingRole = true);
    try {
      await _enterRole!(role);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr(e.toString().replaceFirst('Exception: ', '')))),
      );
    } finally {
      if (mounted) setState(() => _switchingRole = false);
    }
  }

  int _clampTab(int index) {
    final max = _tabItems.length - 1;
    if (index < 0) return 0;
    if (index > max) return max;
    return index;
  }

  // 3 primary visible + 1 overflow = 4 total items → 2 | QR | 2 layout
  static const _maxNavItems = 4;

  List<_TabItem> get _tabItems {
    final config = context.read<TenantConfig>();
    final user = context.read<AuthService>().user;
    final s = AppStrings.of(context);
    if (user?.isNutritionist == true && user?.staffKind == 'nutritionist') {
      return [
        _TabItem(
          key: 'nutrition_bookings',
          icon: Icons.calendar_today_outlined,
          label: tr(s.navAppointments),
          screen: const NutritionistBookingsScreen(),
        ),
        _TabItem(
          key: 'nutrition_clients',
          icon: Icons.people_outline_rounded,
          label: tr(s.navClients),
          screen: const NutritionistClientsScreen(),
        ),
        _TabItem(
          key: 'nutrition_templates',
          icon: Icons.menu_book_outlined,
          label: tr(s.programs),
          screen: const NutritionistTemplatesScreen(),
        ),
        _TabItem(
          key: 'nutrition_schedule',
          icon: Icons.schedule_rounded,
          label: tr(s.navHours),
          screen: const NutritionistScheduleScreen(),
        ),
      ];
    }
    if (user?.isStaff == true) {
      return [
        _TabItem(
          key: 'schedule',
          icon: Icons.calendar_today_outlined,
          label: tr(s.staffScheduleTab),
          screen: const StaffScheduleScreen(),
        ),
        _TabItem(
          key: 'messages',
          icon: Icons.chat_bubble_outline_rounded,
          label: tr(s.navMessages),
          screen: const StaffMessagesScreen(),
        ),
        _TabItem(
          key: 'community',
          icon: Icons.people_outline_rounded,
          label: tr(s.community),
          screen: const CommunityScreen(),
        ),
        if (user?.staffKind == 'physiotherapist')
          _TabItem(
            key: 'clients',
            icon: Icons.people_outline_rounded,
            label: tr(s.navClients),
            screen: const StaffClientsScreen(),
          )
        else
          _TabItem(
            key: 'trials',
            icon: Icons.person_search_outlined,
            label: tr(s.navTrials),
            screen: const StaffTrialsScreen(),
          ),
        _TabItem(
          key: 'leave',
          icon: Icons.flight_takeoff_outlined,
          label: tr(s.staffLeavesTab),
          screen: const StaffLeavesScreen(),
        ),
        if (config.featureQrCheckin)
          _TabItem(
            key: 'qr',
            icon: Icons.qr_code_2_rounded,
            label: tr('QR'),
            screen: const MyQrScreen(),
          ),
      ];
    }
    return [
      _TabItem(
        key: 'gym_dashboard',
        icon: Icons.home_outlined,
        label: tr(s.navMyGym),
        screen: const GymDashboardScreen(),
      ),
      _TabItem(
        key: 'booking',
        icon: Icons.fitness_center_outlined,
        label: tr(s.navBook),
        screen: const ServicesScreen(),
      ),
      if (_hasWorkoutPrograms)
        _TabItem(
          key: 'workout',
          icon: Icons.fitness_center_rounded,
          label: tr(s.navWorkout),
          screen: const WorkoutProgramsScreen(),
        )
      else
        _TabItem(
          key: 'appointments',
          icon: Icons.calendar_month_outlined,
          label: tr(s.navAppointments),
          screen: const MyBookingsScreen(),
        ),
      _TabItem(
        key: 'goals',
        icon: Icons.track_changes_outlined,
        label: tr(s.goals),
        screen: const GoalsScreen(),
      ),
      if (_hasWorkoutPrograms)
        _TabItem(
          key: 'appointments',
          icon: Icons.calendar_month_outlined,
          label: tr(s.navAppointments),
          screen: const MyBookingsScreen(),
        ),
      _TabItem(
        key: 'community',
        icon: Icons.people_outline_rounded,
        label: tr(s.community),
        screen: const CommunityScreen(),
      ),
      _TabItem(
        key: 'packages',
        icon: Icons.card_membership_outlined,
        label: tr(s.packages),
        screen: const CreditsScreen(),
      ),
      if (config.featureQrCheckin)
        _TabItem(
          key: 'qr',
          icon: Icons.qr_code_2_rounded,
          label: tr('QR'),
          screen: const MyQrScreen(),
        ),
      if (config.featureNutrition && _hasNutritionAccess)
        _TabItem(
          key: 'nutrition',
          icon: Icons.restaurant_menu_outlined,
          label: tr(s.nutrition),
          screen: const NutritionScreen(),
        ),
      if (config.featureMarketplace)
        _TabItem(
          key: 'marketplace',
          icon: Icons.storefront_outlined,
          label: tr(s.marketplace),
          screen: const MarketplaceScreen(),
        ),
      _TabItem(
        key: 'payments',
        icon: Icons.payment_outlined,
        label: tr(s.navPayments),
        screen: const PaymentsScreen(),
      ),
    ];
  }

  void _openMoreSheet(List<_TabItem> overflowTabs) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(
        tabs: overflowTabs,
        onSelect: (tab) {
          final all = _tabItems;
          final idx = all.indexWhere((t) => t.key == tab.key);
          if (idx >= 0) setState(() => _index = idx);
        },
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _active = this;
    _index = _clampTab(widget.initialTab);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUnread();
      _loadNutritionAccess();
      _loadWorkoutNav();
      final openedFromPurchase = GymLaunch.tabKey != null;
      _openLaunchTab();
      if (!openedFromPurchase) MemberIntakeScreen.promptIfNeeded(context);
    });
    _unreadTimer = Timer.periodic(const Duration(seconds: 45), (_) => _refreshUnread());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNutritionAccess();
      _loadWorkoutNav();
      _refreshUnread();
      NotificationService.instance.clearBadge();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _unreadTimer?.cancel();
    if (_active == this) _active = null;
    super.dispose();
  }

  bool _countsAsTrainingProgram(Map<String, dynamic> program) {
    final category = program['service_category']?.toString();
    if (category == 'nutrition' || category == 'nutrition_consultation') return false;
    final name = (program['service_name'] ?? '').toString().trim().toLowerCase();
    if (name == 'συνεδρία διατροφολόγου') return false;
    return true;
  }

  Future<void> _loadWorkoutNav() async {
    final auth = context.read<AuthService>();
    final user = auth.user;
    if (user == null || user.isStaff) return;
    try {
      final rows = await auth.api.fetchMyPrograms(user.id);
      if (!mounted) return;
      final has = rows.any(_countsAsTrainingProgram);
      if (has != _hasWorkoutPrograms) {
        final currentKey = _index >= 0 && _index < _tabItems.length ? _tabItems[_index].key : null;
        setState(() => _hasWorkoutPrograms = has);
        if (!mounted || currentKey == null) return;
        final next = _tabItems.indexWhere((tab) => tab.key == currentKey);
        if (next >= 0 && next != _index) setState(() => _index = next);
      }
      _openLaunchTab();
    } on ApiException catch (_) {}
  }

  void _openLaunchTab() {
    final key = GymLaunch.tabKey;
    if (key == null || !mounted) return;
    final idx = _tabItems.indexWhere((tab) => tab.key == key);
    if (idx < 0) return;
    final msg = GymLaunch.message;
    GymLaunch.tabKey = null;
    GymLaunch.message = null;
    setState(() => _index = idx);
    if (msg == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(msg))));
    });
  }

  Future<void> _loadNutritionAccess() async {
    final config = context.read<TenantConfig>();
    if (!config.featureNutrition) return;
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn || auth.user?.isStaff == true) return;
    try {
      final hasAccess = await auth.api.fetchNutritionAccess();
      if (!mounted) return;
      setState(() {
        _hasNutritionAccess = hasAccess;
        _index = _clampTab(_index);
      });
    } on ApiException catch (_) {
      if (!mounted || _hasNutritionAccess) return;
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!mounted) return;
      try {
        final hasAccess = await auth.api.fetchNutritionAccess();
        if (!mounted) return;
        setState(() {
          _hasNutritionAccess = hasAccess;
          _index = _clampTab(_index);
        });
      } on ApiException catch (_) {}
    }
  }

  Future<void> _refreshUnread() async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) return;
    try {
      final notifResult = await auth.api.fetchNotifications();
      if (mounted) setState(() => _unreadCount = notifResult.unreadCount);
    } on ApiException catch (_) {}
    try {
      final msgCount = await context.read<AuthService>().api.fetchMessageUnreadCount();
      if (mounted) setState(() => _messageUnreadCount = msgCount);
    } on ApiException catch (_) {}
  }

  void _showMessages({String? threadId}) {
    final staff = context.read<AuthService>().user?.isStaff == true;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => staff
            ? const StaffMessagesScreen()
            : MessagesScreen(
                initialThreadId: threadId,
                onUnreadChanged: (count) {
                  if (mounted) setState(() => _messageUnreadCount = count);
                },
              ),
      ),
    ).then((_) => _refreshUnread());
  }

  void _openCheckin() {
    showQrCheckinSheet(context);
  }

  void _openCommunityPost(String? postId) {
    final tabs = _tabItems;
    final idx = tabs.indexWhere((t) => t.key == 'community');
    if (idx < 0) return;
    setState(() => _index = idx);
    if (postId != null) {
      CommunityScreen.highlightPost(postId);
    }
  }

  void _showNotifications() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationsScreen(
          onUnreadChanged: (count) {
            if (mounted) setState(() => _unreadCount = count);
          },
        ),
      ),
    ).then((_) => _refreshUnread());
  }

  Future<void> _openGymInfo() async {
    final api = context.read<AuthService>().api;
    try {
      final info = await api.fetchGymInfo();
      if (!mounted) return;
      await showGymInfoSheet(context, info: info);
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr(e.message))));
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(AppStrings.of(context).profile)),
          body: ProfileScreen(
            onRemoveGym: widget.onRemoveGym,
            onEnterAsRole: widget.onEnterAsRole,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<TenantConfig>();
    final auth = context.watch<AuthService>();
    final user = auth.user;
    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Color(0xFFB8F55E))),
      );
    }
    final firstName = user.fullName.split(' ').first;
    final tabs = _tabItems;
    final centerKey = !user.isStaff
        ? null
        : (user.isNutritionist ? 'nutrition_bookings' : 'schedule');
    final sideTabs = centerKey == null
        ? tabs
        : tabs.where((t) => t.key != centerKey).toList();
    final hasOverflow = sideTabs.length > _maxNavItems;
    final visibleTabs = hasOverflow ? sideTabs.sublist(0, _maxNavItems - 1) : sideTabs;
    final overflowTabs = hasOverflow ? sideTabs.sublist(_maxNavItems - 1) : <_TabItem>[];
    final currentKey = tabs[_index].key;
    final sideIndex = visibleTabs.indexWhere((t) => t.key == currentKey);
    final overflowSelected = overflowTabs.any((t) => t.key == currentKey);
    final navSelectedIndex = overflowSelected ? visibleTabs.length : sideIndex;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GreetingHeader(
              greeting: greetingForHour(),
              name: firstName,
              subtitle: tr(config.appName),
              avatarLetter: user.fullName.isNotEmpty ? user.fullName[0] : '?',
              roleLabel: _roleLabelForUser(user),
              onLogoTap: _openGymInfo,
              onAvatarTap: _enterRole != null || _leaveToOmniplex != null
                  ? () => _openRoleSheet(user)
                  : _openProfile,
              onCheckinTap: config.featureQrCheckin ? _openCheckin : null,
              onMessagesTap: _showMessages,
              onNotificationsTap: _showNotifications,
              onSwitchGym: _leaveToOmniplex,
              notificationCount: _unreadCount,
              messageCount: _messageUnreadCount,
            ),
            Expanded(child: tabs[_index].screen),
          ],
        ),
      ),
      floatingActionButton: (user.isStaff || tabs[_index].key == 'community') ? null : FloatingActionButton(
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AiAgentScreen())),
        backgroundColor: Colors.transparent,
        elevation: 0,
        child: Container(
          width: 56, height: 56,
          decoration: BoxDecoration(
            color: context.tenantPrimary,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: context.tenantPrimary.withValues(alpha: 0.4),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Icon(Icons.auto_awesome_rounded, color: AppColors.onFill(context.tenantPrimary), size: 24),
        ),
      ),
      bottomNavigationBar: FloatingNavBar(
        selectedIndex: navSelectedIndex,
        onTap: (i) {
          if (hasOverflow && i == visibleTabs.length) {
            _openMoreSheet(overflowTabs);
            return;
          }
          if (i < 0 || i >= visibleTabs.length) return;
          final idx = tabs.indexWhere((t) => t.key == visibleTabs[i].key);
          if (idx < 0) return;
          setState(() => _index = idx);
          if (tabs[idx].key == 'gym_dashboard' || tabs[idx].key == 'booking') {
            _loadNutritionAccess();
          }
        },
        items: [
          ...visibleTabs.map((t) => FloatingNavItem(icon: t.icon, label: tr(t.label))),
          if (hasOverflow)
            FloatingNavItem(icon: Icons.grid_view_rounded, label: AppStrings.of(context).more),
        ],
        centerAction: () {
          final key = centerKey ?? 'booking';
          final idx = tabs.indexWhere((t) => t.key == key);
          if (idx >= 0) setState(() => _index = idx);
        },
        centerIcon: Icons.event_available_rounded,
        activeColor: context.tenantPrimary,
      ),
    );
  }
}

class _TabItem {
  _TabItem({
    required this.key,
    required this.icon,
    required this.label,
    required this.screen,
  });
  final String key;
  final IconData icon;
  final String label;
  final Widget screen;
}

class _MoreSheet extends StatelessWidget {
  const _MoreSheet({required this.tabs, required this.onSelect});
  final List<_TabItem> tabs;
  final void Function(_TabItem) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E2E),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 12),
          Container(
            width: 36, height: 4,
            decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 16),
          ...tabs.map((tab) {
            final primary = context.tenantPrimary;
            return ListTile(
              leading: Container(
                width: 44, height: 44,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(tab.icon, color: primary, size: 22),
              ),
              title: Text(tab.label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () {
                Navigator.pop(context);
                onSelect(tab);
              },
            );
          }),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _InGymRoleBar extends StatelessWidget {
  const _InGymRoleBar({
    required this.roles,
    required this.currentIsStaff,
    required this.currentKind,
    required this.onEnter,
    required this.onRequest,
    required this.switching,
  });

  final List<GlobalGym> roles;
  final bool currentIsStaff;
  final String? currentKind;
  final Future<void> Function(GlobalGym) onEnter;
  final VoidCallback onRequest;
  final bool switching;

  bool _isCurrent(GlobalGym gym) {
    if (gym.isStaff != currentIsStaff) return false;
    if (!gym.isStaff) return true;
    return (gym.staffKind ?? 'trainer') == (currentKind ?? 'trainer');
  }

  String _label(GlobalGym gym) {
    if (!gym.isStaff) return tr('Ασκούμενος');
    if (gym.staffKind == 'nutritionist') return tr('Διατροφολόγος');
    if (gym.staffKind == 'physiotherapist') return tr('Φυσιοθεραπευτής');
    return 'Trainer';
  }

  @override
  Widget build(BuildContext context) {
    if (roles.isEmpty) return const SizedBox.shrink();
    final primary = context.tenantPrimary;
    final onFill = AppColors.onFill(primary);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(children: [
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                for (final role in roles)
                  Expanded(
                    child: GestureDetector(
                      onTap: switching || _isCurrent(role) ? null : () => onEnter(role),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        height: 34,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: _isCurrent(role) ? primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: switching && !_isCurrent(role)
                            ? SizedBox(
                                width: 16, height: 16,
                                child: CircularProgressIndicator(strokeWidth: 2, color: primary),
                              )
                            : Text(tr(_label(role)),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12, fontWeight: FontWeight.w700,
                                  color: _isCurrent(role) ? onFill : AppColors.textPrimary,
                                )),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: switching ? null : onRequest,
          child: Container(
            height: 40,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(tr('Νέος ρόλος'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
          ),
        ),
      ]),
    );
  }
}
