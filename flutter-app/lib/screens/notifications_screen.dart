import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../l10n/tr.dart';


class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key, this.onUnreadChanged});
  final ValueChanged<int>? onUnreadChanged;

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  static const _kBg     = Color(0xFF0A0A0A);
  static const _kCard   = Color(0xFF16171B);
  static const _kBorder = Color(0xFF2A2B30);
  static const _kGray   = Color(0xFF9A9CA3);
  static const _kLime   = Color(0xFFC6FF3D);
  static const _kAccent = Color(0xFF7B3EAD);
  static const _kAmber  = Color(0xFFFFB238);
  static const _kCyan   = Color(0xFF3EE6FF);

  List<Map<String, dynamic>> _items = [];
  bool _loading = true;
  bool _markingAll = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final api = context.read<AuthService>().api;
      final result = await api.fetchNotifications();
      if (!mounted) return;
      setState(() => _items = result.notifications);
      widget.onUnreadChanged?.call(result.unreadCount);
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _markRead(Map<String, dynamic> item) async {
    final isRead = item['is_read'] == 1 || item['is_read'] == true;
    if (isRead) return;
    final id = item['id']?.toString();
    if (id == null) return;
    try {
      final api = context.read<AuthService>().api;
      await api.markNotificationRead(id);
      if (!mounted) return;
      setState(() => item['is_read'] = 1);
      final unread = _items.where((n) => n['is_read'] != 1 && n['is_read'] != true).length;
      widget.onUnreadChanged?.call(unread);
    } catch (_) {}
  }

  Future<void> _markAll() async {
    setState(() => _markingAll = true);
    try {
      final api = context.read<AuthService>().api;
      await api.markAllNotificationsRead();
      if (!mounted) return;
      setState(() {
        for (final n in _items) {
          n['is_read'] = 1;
        }
      });
      widget.onUnreadChanged?.call(0);
    } catch (_) {}
    if (mounted) setState(() => _markingAll = false);
  }

  String _relativeTime(String? raw) {
    if (raw == null || raw.isEmpty) return '';
    try {
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
      final diff = DateTime.now().difference(dt);
      if (diff.inMinutes < 1) return tr('Μόλις τώρα');
      if (diff.inMinutes < 60) return tr('${diff.inMinutes} λ. πριν');
      if (diff.inHours < 24) return tr('${diff.inHours} ώρ. πριν');
      if (diff.inDays == 1) return tr('Χθες');
      if (diff.inDays < 7) return tr('${diff.inDays} μέρες πριν');
      return '${dt.day}/${dt.month}';
    } catch (_) {
      return '';
    }
  }

  Map<String, dynamic> _iconForType(String type) {
    switch (type) {
      case 'workout_complete':
      case 'checkin_reminder':
        return {'icon': Icons.check_circle_outline, 'color': _kLime,
          'bg': const Color(0xFF1D2410), 'border': const Color(0x4DC6FF3D)};
      case 'booking_reminder_24h':
      case 'prep_reminder':
        return {'icon': Icons.alarm_outlined, 'color': _kAmber,
          'bg': const Color(0xFF2B2110), 'border': const Color(0x4DFFB238)};
      case 'announcement':
        return {'icon': Icons.campaign_outlined, 'color': _kAccent,
          'bg': const Color(0xFF1C1524), 'border': const Color(0x4D7B3EAD)};
      case 'message':
        return {'icon': Icons.chat_bubble_outline, 'color': _kCyan,
          'bg': const Color(0xFF0F1F24), 'border': const Color(0x4D3EE6FF)};
      case 'join_approved':
        return {'icon': Icons.how_to_reg_outlined, 'color': _kLime,
          'bg': const Color(0xFF1D2410), 'border': const Color(0x4DC6FF3D)};
      case 'join_rejected':
        return {'icon': Icons.cancel_outlined, 'color': const Color(0xFFFF5353),
          'bg': const Color(0xFF24100F), 'border': const Color(0x4DFF5353)};
      default:
        return {'icon': Icons.notifications_outlined, 'color': _kGray,
          'bg': const Color(0xFF1F2024), 'border': _kBorder};
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2))
                  : _items.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: _kAccent,
                          backgroundColor: _kCard,
                          onRefresh: _load,
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                            itemCount: _items.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 8),
                            itemBuilder: (_, i) => _buildCard(_items[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final hasUnread = _items.any((n) => n['is_read'] != 1 && n['is_read'] != true);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => Navigator.maybePop(context),
            child: Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: _kCard,
                shape: BoxShape.circle,
                border: Border.all(color: _kBorder),
              ),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(tr('Ειδοποιήσεις'),
              style: GoogleFonts.inter(
                fontSize: 20, fontWeight: FontWeight.w700,
                color: Colors.white, letterSpacing: -0.5)),
          ),
          if (hasUnread && !_loading)
            GestureDetector(
              onTap: _markingAll ? null : _markAll,
              child: _markingAll
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(color: _kLime, strokeWidth: 2))
                  : Text(tr('Όλα διαβαστά'),
                      style: GoogleFonts.inter(
                        fontSize: 12, fontWeight: FontWeight.w700, color: _kLime)),
            ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64, height: 64,
            decoration: BoxDecoration(
              color: _kCard, shape: BoxShape.circle,
              border: Border.all(color: _kBorder),
            ),
            child: const Icon(Icons.notifications_outlined, color: _kGray, size: 28),
          ),
          const SizedBox(height: 16),
          Text(tr('Δεν υπάρχουν ειδοποιήσεις'),
            style: GoogleFonts.inter(fontSize: 15, fontWeight: FontWeight.w600, color: _kGray)),
          const SizedBox(height: 6),
          Text(tr('Θα σε ενημερώσουμε για κρατήσεις\nκαι νέα του γυμναστηρίου.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13, color: _kGray.withValues(alpha: 0.6), height: 1.5)),
        ],
      ),
    );
  }

  Widget _buildCard(Map<String, dynamic> item) {
    final unread = item['is_read'] != 1 && item['is_read'] != true;
    final type = item['type'] as String? ?? '';
    final style = _iconForType(type);
    final time = _relativeTime(item['created_at'] as String?);

    return GestureDetector(
      onTap: () => _markRead(item),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: unread ? _kAccent.withValues(alpha: 0.35) : _kBorder),
          ),
          child: Stack(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 14, 14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        color: style['bg'] as Color,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: style['border'] as Color),
                      ),
                      child: Icon(style['icon'] as IconData,
                        color: style['color'] as Color, size: 18),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  tr(item['title'] as String? ?? tr('Ειδοποίηση')),
                                  style: GoogleFonts.inter(
                                    fontSize: 14, fontWeight: FontWeight.w700,
                                    color: Colors.white),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Row(
                                children: [
                                  if (time.isNotEmpty)
                                    Text(time, style: GoogleFonts.inter(
                                      fontSize: 11, fontWeight: FontWeight.w500,
                                      color: _kGray)),
                                  if (unread) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      width: 6, height: 6,
                                      decoration: BoxDecoration(
                                        color: _kLime,
                                        shape: BoxShape.circle,
                                        boxShadow: [BoxShadow(
                                          color: _kLime.withValues(alpha: 0.9),
                                          blurRadius: 8)],
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ],
                          ),
                          if ((item['body'] as String?)?.isNotEmpty == true) ...[
                            const SizedBox(height: 4),
                            Text(
                              tr(item['body'] as String),
                              style: GoogleFonts.inter(
                                fontSize: 13, color: _kGray, height: 1.4),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (unread)
                Positioned(
                  left: 0, top: 0, bottom: 0,
                  child: Container(
                    width: 4,
                    decoration: BoxDecoration(
                      color: _kLime,
                      boxShadow: [BoxShadow(
                        color: _kLime.withValues(alpha: 0.6), blurRadius: 10)],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
