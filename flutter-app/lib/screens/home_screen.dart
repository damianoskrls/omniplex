import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../l10n/app_strings.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../widgets/gym_info_sheet.dart';
import '../widgets/ui_kit.dart';
import 'credits_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'staff_clients_screen.dart';
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
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../widgets/qr_checkin_sheet.dart';
import 'ai_agent_screen.dart';
import 'member_intake_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0, this.onSwitchGym, this.onRemoveGym});

  final int initialTab;
  final VoidCallback? onSwitchGym;
  final Future<void> Function()? onRemoveGym;

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
    if (user?.isNutritionist == true && user?.staffKind == 'nutritionist') {
      return [
        _TabItem(
          key: 'nutrition_clients',
          icon: Icons.people_outline_rounded,
          label: 'Πελάτες',
          screen: const NutritionistClientsScreen(),
        ),
        _TabItem(
          key: 'nutrition_bookings',
          icon: Icons.calendar_today_outlined,
          label: 'Ραντεβού',
          screen: const NutritionistBookingsScreen(),
        ),
        _TabItem(
          key: 'nutrition_templates',
          icon: Icons.menu_book_outlined,
          label: 'Προγράμματα',
          screen: const NutritionistTemplatesScreen(),
        ),
      ];
    }
    if (user?.isStaff == true) {
      return [
        _TabItem(
          key: 'schedule',
          icon: Icons.calendar_today_outlined,
          label: 'Πρόγραμμα',
          screen: const StaffScheduleScreen(),
        ),
        _TabItem(
          key: 'messages',
          icon: Icons.chat_bubble_outline_rounded,
          label: 'Μηνύματα',
          screen: const StaffMessagesScreen(),
        ),
        _TabItem(
          key: 'community',
          icon: Icons.people_outline_rounded,
          label: 'Κοινότητα',
          screen: const CommunityScreen(),
        ),
        _TabItem(
          key: 'clients',
          icon: Icons.people_outline_rounded,
          label: 'Πελάτες',
          screen: const StaffClientsScreen(),
        ),
        _TabItem(
          key: 'leave',
          icon: Icons.flight_takeoff_outlined,
          label: 'Άδειες',
          screen: const StaffLeavesScreen(),
        ),
      ];
    }
    return [
      // ── Primary (always visible, 2 left of QR) ──────────────
      _TabItem(
        key: 'gym_dashboard',
        icon: Icons.home_outlined,
        label: 'My Gym',
        screen: const GymDashboardScreen(),
      ),
      _TabItem(
        key: 'booking',
        icon: Icons.fitness_center_outlined,
        label: config.label('book_cta', 'Κράτηση'),
        screen: const ServicesScreen(),
      ),
      // ── Primary (visible, 1 right of QR before overflow) ────
      _TabItem(
        key: 'goals',
        icon: Icons.track_changes_outlined,
        label: 'Στόχοι',
        screen: const GoalsScreen(),
      ),
      // ── Overflow ─────────────────────────────────────────────
      _TabItem(
        key: 'appointments',
        icon: Icons.calendar_month_outlined,
        label: config.label('appointment_noun', 'Ραντεβού'),
        screen: const MyBookingsScreen(),
      ),
      _TabItem(
        key: 'community',
        icon: Icons.people_outline_rounded,
        label: 'Κοινότητα',
        screen: const CommunityScreen(),
      ),
      _TabItem(
        key: 'packages',
        icon: Icons.card_membership_outlined,
        label: 'Πακέτα',
        screen: const CreditsScreen(),
      ),
      if (config.featureNutrition && _hasNutritionAccess)
        _TabItem(
          key: 'nutrition',
          icon: Icons.restaurant_menu_outlined,
          label: AppStrings.of(context).nutrition,
          screen: const NutritionScreen(),
        ),
      if (config.featureMarketplace)
        _TabItem(
          key: 'marketplace',
          icon: Icons.storefront_outlined,
          label: AppStrings.of(context).marketplace,
          screen: const MarketplaceScreen(),
        ),
      _TabItem(
        key: 'payments',
        icon: Icons.payment_outlined,
        label: 'Πληρωμές',
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
      MemberIntakeScreen.promptIfNeeded(context);
    });
    _unreadTimer = Timer.periodic(const Duration(seconds: 45), (_) => _refreshUnread());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNutritionAccess();
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text(AppStrings.of(context).profile)),
          body: ProfileScreen(onRemoveGym: widget.onRemoveGym),
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
    final hasOverflow = tabs.length > _maxNavItems;
    final visibleTabs = hasOverflow ? tabs.sublist(0, _maxNavItems - 1) : tabs;
    final overflowTabs = hasOverflow ? tabs.sublist(_maxNavItems - 1) : <_TabItem>[];
    final overflowSelected = hasOverflow && _index >= _maxNavItems - 1;
    final navSelectedIndex = overflowSelected ? visibleTabs.length : _index;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            GreetingHeader(
              greeting: greetingForHour(),
              name: firstName,
              subtitle: config.appName,
              avatarLetter: user.fullName.isNotEmpty ? user.fullName[0] : '?',
              onLogoTap: _openGymInfo,
              onAvatarTap: _openProfile,
              onCheckinTap: _openCheckin,
              onMessagesTap: _showMessages,
              onNotificationsTap: _showNotifications,
              onSwitchGym: widget.onSwitchGym,
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
          setState(() => _index = i);
          if (tabs[i].key == 'gym_dashboard' || tabs[i].key == 'booking') {
            _loadNutritionAccess();
          }
        },
        items: [
          ...visibleTabs.map((t) => FloatingNavItem(icon: t.icon, label: t.label)),
          if (hasOverflow)
            FloatingNavItem(icon: Icons.grid_view_rounded, label: AppStrings.of(context).more),
        ],
        centerAction: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const MyQrScreen()),
        ),
        centerIcon: Icons.qr_code_2_rounded,
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
