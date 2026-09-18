import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../config/tenant_config.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import '../widgets/ui_kit.dart';
import 'home_screen.dart';
import 'notification_detail_screen.dart';
import 'messages_screen.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({
    super.key,
    this.embedded = false,
    this.onUnreadChanged,
  });

  final bool embedded;
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _markingAll = false;

  ApiService get _api => context.read<AuthService>().api;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final result = await _api.fetchNotifications();
      if (mounted) {
        setState(() => _items = result.notifications);
        _notifyUnread();
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _notifyUnread() {
    final count = _items.where((n) => n['is_read'] != 1 && n['is_read'] != true).length;
    widget.onUnreadChanged?.call(count);
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final id = item['id'] as String?;
    if (id == null || item['is_read'] == 1 || item['is_read'] == true) return;
    await _api.markNotificationRead(id);
    if (!mounted) return;
    setState(() => item['is_read'] = 1);
    _notifyUnread();
  }

  Future<void> _markAllRead() async {
    final hasUnread = _items.any((n) => n['is_read'] != 1 && n['is_read'] != true);
    if (!hasUnread) return;
    setState(() => _markingAll = true);
    try {
      await _api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final n in _items) n['is_read'] = 1;
      });
      _notifyUnread();
    } finally {
      if (mounted) setState(() => _markingAll = false);
    }
  }

  String? _imageUrl(Map<String, dynamic> n) {
    final config = context.read<TenantConfig>();
    final direct = n['image_url'] as String?;
    if (direct != null && direct.isNotEmpty) return resolveMediaUrl(config, direct);
    final payload = n['payload'];
    Map<String, dynamic>? map;
    if (payload is Map) {
      map = payload.cast<String, dynamic>();
    } else if (payload is String && payload.isNotEmpty) {
      try { map = (jsonDecode(payload) as Map).cast<String, dynamic>(); } catch (_) {}
    }
    final fromPayload = map?['image_url'] as String?;
    if (fromPayload != null && fromPayload.isNotEmpty) return resolveMediaUrl(config, fromPayload);
    return null;
  }

  DateTime? _when(Map<String, dynamic> n) {
    final created = n['created_at'] as String?;
    if (created == null) return null;
    try { return DateTime.parse(created).toLocal(); } catch (_) { return null; }
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'announcement': return Icons.campaign_outlined;
      case 'payment_reminder':
      case 'payment_reminder_auto': return Icons.payments_outlined;
      case 'booking_reminder_24h':
      case 'prep_reminder': return Icons.calendar_today_outlined;
      case 'workout_complete':
      case 'checkin_reminder': return Icons.fitness_center;
      case 'message': return Icons.chat_bubble_outline;
      case 'community_mention':
      case 'community_comment':
      case 'community_post': return Icons.people_outline;
      default: return Icons.notifications_outlined;
    }
  }

  Map<String, dynamic>? _parsePayload(Map<String, dynamic> n) {
    final payload = n['payload'];
    if (payload is Map) return payload.cast<String, dynamic>();
    if (payload is String && payload.isNotEmpty) {
      try { return (jsonDecode(payload) as Map).cast<String, dynamic>(); } catch (_) {}
    }
    return null;
  }

  Future<void> _onTap(Map<String, dynamic> n) async {
    final type = n['type'] as String? ?? '';
    if (type == 'message') {
      await _markRead(n);
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(builder: (_) => const MessagesScreen()));
      return;
    }

    if (type == 'community_mention' || type == 'community_comment' || type == 'community_post') {
      final postId = _parsePayload(n)?['post_id'] as String?;
      await _markRead(n);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      HomeScreen.openCommunityPost(postId);
      return;
    }

    final imageUrl = _imageUrl(n);
    final body = n['body'] as String?;
    final title = n['title'] as String? ?? 'Ειδοποίηση';
    final when = _when(n);
    final hasDetail = imageUrl != null || (body?.isNotEmpty == true);

    await _markRead(n);
    if (!mounted || !hasDetail) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NotificationDetailScreen(
          title: title, body: body, imageUrl: imageUrl, when: when,
        ),
      ),
    );
  }

  String _relativeTime(DateTime when) {
    final diff = DateTime.now().difference(when);
    if (diff.inMinutes < 1) return 'Μόλις τώρα';
    if (diff.inMinutes < 60) return 'Πριν ${diff.inMinutes} λεπτά';
    if (diff.inHours < 24) return 'Πριν ${diff.inHours} ώρες';
    if (diff.inDays == 1) return 'Χθες';
    if (diff.inDays < 7) return 'Πριν ${diff.inDays} μέρες';
    return DateFormat('d MMM', 'el_GR').format(when);
  }

  Widget _buildList() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: AppColors.lime));
    }
    if (_items.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Δεν υπάρχουν ειδοποιήσεις',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
      );
    }

    return RefreshIndicator(
      color: AppColors.lime,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: _items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final n = _items[i];
          final isRead = n['is_read'] == 1 || n['is_read'] == true;
          final imageUrl = _imageUrl(n);
          final when = _when(n);
          final hasDetail = imageUrl != null || (n['body'] as String?)?.isNotEmpty == true;

          return Opacity(
            opacity: isRead ? 0.65 : 1.0,
            child: SurfaceCard(
              padding: EdgeInsets.zero,
              child: InkWell(
                onTap: () => _onTap(n),
                borderRadius: BorderRadius.circular(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (imageUrl != null)
                      ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                        child: AspectRatio(
                          aspectRatio: 16 / 9,
                          child: Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: AppColors.surface,
                              child: const Icon(Icons.broken_image_outlined,
                                  color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (imageUrl == null)
                            Container(
                              width: 40, height: 40,
                              decoration: BoxDecoration(
                                color: (isRead ? AppColors.textSecondary : AppColors.lime)
                                    .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                _iconFor(n['type'] as String?),
                                color: isRead ? AppColors.textSecondary : AppColors.lime,
                                size: 20,
                              ),
                            ),
                          if (imageUrl == null) const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  n['title'] as String? ?? 'Ειδοποίηση',
                                  style: TextStyle(
                                    fontWeight: isRead ? FontWeight.w600 : FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                if ((n['body'] as String?)?.isNotEmpty == true) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    n['body'] as String,
                                    maxLines: hasDetail ? 2 : null,
                                    overflow: hasDetail ? TextOverflow.ellipsis : null,
                                    style: Theme.of(context).textTheme.bodyMedium,
                                  ),
                                ],
                                if (when != null) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    _relativeTime(when),
                                    style: Theme.of(context).textTheme.bodyMedium
                                        ?.copyWith(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                                if (!isRead && hasDetail) ...[
                                  const SizedBox(height: 6),
                                  Text(
                                    'Πάτα για ανάγνωση',
                                    style: TextStyle(
                                      fontSize: 12, fontWeight: FontWeight.w600,
                                      color: AppColors.lime.withValues(alpha: 0.9),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (!isRead)
                            Container(
                              width: 8, height: 8,
                              margin: const EdgeInsets.only(top: 6),
                              decoration: const BoxDecoration(
                                color: AppColors.lime, shape: BoxShape.circle,
                              ),
                            ),
                          if (isRead)
                            const Icon(Icons.check_circle_outline,
                                size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader({bool fullPage = false}) {
    final hasUnread = _items.any((n) => n['is_read'] != 1 && n['is_read'] != true);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, fullPage ? 0 : 8, 8, 0),
      child: Row(
        children: [
          const Expanded(
            child: Text('Ειδοποιήσεις',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ),
          if (hasUnread)
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: _markingAll
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                  : const Text('Όλα διαβαστέντα',
                      style: TextStyle(fontSize: 13, color: AppColors.lime)),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.embedded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildHeader(),
          Expanded(child: _buildList()),
        ],
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Ειδοποιήσεις'),
        actions: [
          if (_items.any((n) => n['is_read'] != 1 && n['is_read'] != true))
            TextButton(
              onPressed: _markingAll ? null : _markAllRead,
              child: _markingAll
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                  : const Text('Όλα διαβαστέντα',
                      style: TextStyle(fontSize: 13, color: AppColors.lime)),
            ),
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
      body: _buildList(),
    );
  }
}
