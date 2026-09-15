import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/tenant_config.dart';
import '../services/auth_service.dart';
import '../widgets/gym_info_sheet.dart';
import '../widgets/ui_kit.dart';
import 'credits_screen.dart';
import 'my_bookings_screen.dart';
import 'notifications_screen.dart';
import 'messages_screen.dart';
import 'community_screen.dart';
import 'profile_screen.dart';
import 'services_screen.dart';
import 'qr_checkin_screen.dart';
import 'nutrition_screen.dart';
import 'workout_programs_screen.dart';
import 'marketplace_screen.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.initialTab = 0});

  final int initialTab;

  static void selectTab(int index) => _HomeScreenState.selectTab(index);

  static void openNotifications() => _HomeScreenState.openNotifications();

  static void openMessages() => _HomeScreenState.openMessages();

  static void openCommunityPost(String? postId) => _HomeScreenState.openCommunityPost(postId);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static _HomeScreenState? _active;

  late int _index;
  int _unreadCount = 0;
  bool _hasNutritionAccess = false;
  Timer? _unreadTimer;

  static void selectTab(int index) {
    final state = _active;
    if (state == null || !state.mounted) return;
    state.setState(() => state._index = state._clampTab(index));
  }

  static void openNotifications() {
    final state = _active;
    if (state == null || !state.mounted) return;
    state._showNotifications();
  }

  static void openMessages() {
    final state = _active;
    if (state == null || !state.mounted) return;
    state._showMessages();
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

  static const _maxNavItems = 4;

  List<_TabItem> get _tabItems {
    final config = context.read<TenantConfig>();
    // Primary tabs always shown first; secondary (optional features) go to overflow
    return [
      _TabItem(
        key: 'booking',
        icon: Icons.fitness_center,
        label: config.label('book_cta', 'Κράτηση'),
        screen: const ServicesScreen(),
      ),
      _TabItem(
        key: 'appointments',
        icon: Icons.calendar_month,
        label: config.label('appointment_noun', 'Ραντεβού'),
        screen: const MyBookingsScreen(),
      ),
      _TabItem(
        key: 'community',
        icon: Icons.people_outline,
        label: 'Κοινότητα',
        screen: const CommunityScreen(),
      ),
      _TabItem(
        key: 'programs',
        icon: Icons.sports_gymnastics,
        label: 'Προγράμματα',
        screen: const WorkoutProgramsScreen(),
      ),
      // Secondary — appear in overflow when nav is full
      if (config.featureMemberships)
        _TabItem(
          key: 'packages',
          icon: Icons.card_membership,
          label: 'Πακέτα',
          screen: const CreditsScreen(),
        ),
      if (config.featureNutrition && _hasNutritionAccess)
        _TabItem(
          key: 'nutrition',
          icon: Icons.restaurant_menu,
          label: 'Διατροφή',
          screen: const NutritionScreen(),
        ),
      if (config.featureMarketplace)
        _TabItem(
          key: 'marketplace',
          icon: Icons.storefront_outlined,
          label: 'Shop',
          screen: const MarketplaceScreen(),
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
      _checkServerNotifications();
      _loadNutritionAccess();
    });
    _unreadTimer = Timer.periodic(const Duration(seconds: 45), (_) => _refreshUnread());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadNutritionAccess();
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
    if (!auth.isLoggedIn) return;
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
      if (mounted) {
        setState(() {
          _unreadCount = notifResult.unreadCount;
        });
      }
    } on ApiException catch (_) {}
  }

  Future<void> _checkServerNotifications() async {
    final auth = context.read<AuthService>();
    if (!auth.isLoggedIn) return;
    try {
      final result = await auth.api.fetchNotifications();
      for (final n in result.notifications) {
        if (n['is_read'] == 1) continue;
        final type = n['type'] as String? ?? '';
        if (type == 'workout_complete') {
          final bookingId = n['booking_id'] as String?;
          if (bookingId == null) continue;
          await NotificationService.instance.showInstant(
            title: n['title'] as String? ?? 'Προπόνηση',
            body: n['body'] as String? ?? '',
            payload: 'complete:$bookingId',
          );
          break;
        }
        if (type == 'checkin_reminder') {
          final bookingId = n['booking_id'] as String?;
          if (bookingId == null) continue;
          await NotificationService.instance.showInstant(
            title: n['title'] as String? ?? 'Check-in',
            body: n['body'] as String? ?? '',
            payload: 'complete:$bookingId',
          );
          break;
        }
      }
    } on ApiException catch (_) {}
  }

  void _showMessages() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => MessagesScreen(
          onUnreadChanged: (count) {
            if (mounted) setState(() {});
          },
        ),
      ),
    ).then((_) => _refreshUnread());
  }

  void _openCheckin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const QrCheckinScreen()),
    );
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
          appBar: AppBar(title: const Text('Προφίλ')),
          body: const ProfileScreen(),
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
              onNotificationsTap: _showNotifications,
              notificationCount: _unreadCount,
            ),
            Expanded(child: tabs[_index].screen),
          ],
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
          if (tabs[i].key == 'packages' || tabs[i].key == 'booking') {
            _loadNutritionAccess();
          }
        },
        items: [
          ...visibleTabs.map((t) => FloatingNavItem(icon: t.icon, label: t.label)),
          if (hasOverflow)
            const FloatingNavItem(icon: Icons.grid_view_rounded, label: 'Περισσότερα'),
        ],
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
          ...tabs.map((tab) => ListTile(
            leading: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: const Color(0xFFB8F55E).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(tab.icon, color: const Color(0xFFB8F55E), size: 22),
            ),
            title: Text(tab.label,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 16)),
            trailing: const Icon(Icons.chevron_right, color: Colors.white38),
            onTap: () {
              Navigator.pop(context);
              onSelect(tab);
            },
          )),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
