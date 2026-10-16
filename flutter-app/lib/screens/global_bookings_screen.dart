import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../services/global_auth_service.dart';
import '../l10n/tr.dart';

const _kBg      = Color(0xFF090A0F);
const _kCard    = Color(0xFF14161F);
const _kBorder  = Color(0xFF2B2E3D);
const _kText    = Color(0xFFF5F5FA);
const _kGray    = Color(0xFFA7ABBE);
const _kGray2   = Color(0xFF757B92);
const _kAccent  = Color(0xFF9A9DFF);
const _kPrimary = Color(0xFF565CE4);
const _kGuideBg = Color(0xFF242642);
const _kGreen   = Color(0xFF8DE2BB);
const _kGreenBg = Color(0xFF17332B);
const _kPink    = Color(0xFFC52473);
const _kPinkBg  = Color(0xFF2A0E1C);
const _kApiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

// ─── Role helpers ────────────────────────────────────────────────────────────

Color _roleBar(String role) {
  switch (role) {
    case 'staff':     return _kPink;
    case 'nutritionist': return _kGreen;
    default:          return _kAccent; // member / athlete
  }
}

Color _roleBadgeBg(String role) {
  switch (role) {
    case 'staff':        return _kPinkBg;
    case 'nutritionist': return _kGreenBg;
    default:             return _kGuideBg;
  }
}

Color _roleBadgeText(String role) {
  switch (role) {
    case 'staff':        return _kPink;
    case 'nutritionist': return _kGreen;
    default:             return _kAccent;
  }
}

String _roleLabel(String role) {
  switch (role) {
    case 'staff':        return tr('Προπονητής');
    case 'nutritionist': return tr('Διατροφολόγος');
    default:             return tr('Αθλητής');
  }
}

// ─── Date formatting ─────────────────────────────────────────────────────────

String _dateKey(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

String _groupLabel(String dateStr) {
  final d = DateTime.tryParse(dateStr);
  if (d == null) return dateStr;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = day.difference(today).inDays;
  final days = [tr('ΔΕΥΤΕΡΑ'),tr('ΤΡΙΤΗ'),tr('ΤΕΤΑΡΤΗ'),tr('ΠΕΜΠΤΗ'),tr('ΠΑΡΑΣΚΕΥΗ'),tr('ΣΑΒΒΑΤΟ'),tr('ΚΥΡΙΑΚΗ')];
  final months = [tr('ΙΑΝ'),tr('ΦΕΒ'),tr('ΜΑΡ'),tr('ΑΠΡ'),tr('ΜΑΪ'),tr('ΙΟΥΝ'),tr('ΙΟΥΛ'),tr('ΑΥΓ'),tr('ΣΕΠ'),tr('ΟΚΤ'),tr('ΝΟΕ'),tr('ΔΕΚ')];
  final dayName = days[d.weekday - 1];
  final datePart = '${d.day} ${months[d.month - 1]}';
  if (diff == 0) return tr('ΣΗΜΕΡΑ · $dayName $datePart');
  if (diff == 1) return tr('ΑΥΡΙΟ · $dayName $datePart');
  if (diff == -1) return tr('ΧΘΕΣ · $dayName $datePart');
  return '$dayName $datePart';
}

String _fmtTime(String raw) => raw.length >= 5 ? raw.substring(0, 5) : raw;

String _fmtTimeRange(String start, int durationMins) {
  final parts = start.split(':');
  if (parts.length < 2) return _fmtTime(start);
  final h = int.tryParse(parts[0]) ?? 0;
  final m = int.tryParse(parts[1]) ?? 0;
  final endH = (h * 60 + m + durationMins) ~/ 60;
  final endM = (h * 60 + m + durationMins) % 60;
  return '${h.toString().padLeft(2,'0')}:${m.toString().padLeft(2,'0')}–${endH.toString().padLeft(2,'0')}:${endM.toString().padLeft(2,'0')}';
}

// ─── GlobalBookingsScreen ────────────────────────────────────────────────────

class GlobalBookingsScreen extends StatefulWidget {
  const GlobalBookingsScreen({
    super.key,
    required this.globalAuth,
    required this.gyms,
    required this.onEnterGym,
    required this.dashboard,
    required this.loading,
    required this.onRefresh,
  });

  final GlobalAuthService globalAuth;
  final List<GlobalGym> gyms;
  final Future<void> Function(GlobalGym) onEnterGym;
  final Map<String, dynamic>? dashboard;
  final bool loading;
  final Future<void> Function() onRefresh;

  @override
  State<GlobalBookingsScreen> createState() => _GlobalBookingsScreenState();
}

class _GlobalBookingsScreenState extends State<GlobalBookingsScreen> {
  int _tab = 0; // 0=upcoming, 1=past
  String? _gymFilter;
  String? _roleFilter;

  List<Map<String, dynamic>> get _upcoming =>
      (widget.dashboard?['upcoming_bookings'] as List?)
          ?.cast<Map<String, dynamic>>() ?? [];

  List<Map<String, dynamic>> get _filteredUpcoming {
    return _upcoming.where((b) {
      if (_gymFilter != null && b['business_id']?.toString() != _gymFilter) return false;
      if (_roleFilter != null && b['role']?.toString() != _roleFilter) return false;
      return true;
    }).toList()
      ..sort((a, b) {
        final dateA = (a['booking_date']?.toString() ?? '');
        final dateB = (b['booking_date']?.toString() ?? '');
        if (dateA != dateB) return dateA.compareTo(dateB);
        return (a['booking_time']?.toString() ?? '').compareTo(b['booking_time']?.toString() ?? '');
      });
  }

  Map<String, List<Map<String, dynamic>>> get _grouped {
    final map = <String, List<Map<String, dynamic>>>{};
    for (final b in _filteredUpcoming) {
      final key = b['booking_date']?.toString() ?? '';
      map.putIfAbsent(key, () => []).add(b);
    }
    return map;
  }

  List<String> get _gymOptions {
    final seen = <String>{};
    final ids = <String>[];
    for (final b in _upcoming) {
      final id = b['business_id']?.toString() ?? '';
      if (id.isNotEmpty && seen.add(id)) ids.add(id);
    }
    return ids;
  }

  String _gymName(String bizId) {
    for (final g in widget.gyms) {
      if (g.businessId == bizId) return g.appName;
    }
    final b = _upcoming.firstWhere(
      (x) => x['business_id']?.toString() == bizId,
      orElse: () => {},
    );
    return b['app_name']?.toString() ?? b['business_name']?.toString() ?? bizId;
  }

  GlobalGym? _gymFor(String? bizId) {
    if (bizId == null) return null;
    for (final g in widget.gyms) {
      if (g.businessId == bizId) return g;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.loading) {
      return const Scaffold(
        backgroundColor: _kBg,
        body: Center(child: CircularProgressIndicator(color: _kAccent)),
      );
    }

    final grouped = _grouped;
    final isEmpty = _tab == 0 && _filteredUpcoming.isEmpty;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(
              upcomingCount: _upcoming.length,
              onProgramme: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => _ProgrammeScreen(
                  globalAuth: widget.globalAuth,
                  gyms: widget.gyms,
                  upcoming: _upcoming,
                  onEnterGym: widget.onEnterGym,
                )),
              ),
            ),

            if (!isEmpty) ...[
              _TabRow(
                tab: _tab,
                upcomingCount: _filteredUpcoming.length,
                onTab: (t) => setState(() => _tab = t),
              ),
              const SizedBox(height: 12),
              _FilterRow(
                gymOptions: _gymOptions,
                gymFilter: _gymFilter,
                roleFilter: _roleFilter,
                gymName: _gymName,
                onGym: (v) => setState(() => _gymFilter = v),
                onRole: (v) => setState(() => _roleFilter = v),
              ),
              const SizedBox(height: 4),
            ],

            Expanded(
              child: _tab == 0
                ? isEmpty
                  ? _EmptyState(onExplore: () {})
                  : RefreshIndicator(
                      color: _kAccent,
                      backgroundColor: _kCard,
                      onRefresh: widget.onRefresh,
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        children: [
                          for (final dateKey in grouped.keys) ...[
                            _DateHeader(label: _groupLabel(dateKey)),
                            for (final booking in grouped[dateKey]!) ...[
                              _BookingCard(
                                booking: booking,
                                gymName: _gymName(booking['business_id']?.toString() ?? ''),
                                onTap: () => _showDetail(context, booking),
                                onManage: () => _showDetail(context, booking),
                              ),
                            ],
                          ],
                        ],
                      ),
                    )
                : _PastTab(
                    globalAuth: widget.globalAuth,
                    gyms: widget.gyms,
                  ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, Map<String, dynamic> booking) {
    final bizId = booking['business_id']?.toString();
    final gym = _gymFor(bizId);
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: _BookingDetailSheet(
            booking: booking,
            onOpenGym: gym == null ? null : () => widget.onEnterGym(gym),
          ),
        ),
      ),
    );
  }
}

// ─── Header ──────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.upcomingCount, required this.onProgramme});
  final int upcomingCount;
  final VoidCallback onProgramme;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(tr('Κρατήσεις'),
                style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w600, color: _kText)),
              const Spacer(),
              GestureDetector(
                onTap: onProgramme,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: _kGuideBg,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.grid_view_rounded, color: _kAccent, size: 14),
                      const SizedBox(width: 6),
                      Text(tr('Το πρόγραμμά μου'),
                        style: GoogleFonts.inter(
                          fontSize: 12, fontWeight: FontWeight.w600, color: _kAccent)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(tr('Όλες οι δραστηριότητές σου σε έναν ρυθμό.'),
            style: GoogleFonts.inter(
              fontSize: 28, fontWeight: FontWeight.w800, color: _kText, height: 1.1)),
          const SizedBox(height: 6),
          Text(tr('Μαθήματα, & κρατήσεις σε απόλυτη ισορροπία.'),
            style: GoogleFonts.inter(fontSize: 13, color: _kGray, height: 1.45)),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ─── Tab row ──────────────────────────────────────────────────────────────────

class _TabRow extends StatelessWidget {
  const _TabRow({required this.tab, required this.upcomingCount, required this.onTab});
  final int tab;
  final int upcomingCount;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          _Tab(
            label: tr('Επόμενα · $upcomingCount'),
            active: tab == 0,
            onTap: () => onTab(0),
          ),
          const SizedBox(width: 8),
          _Tab(
            label: tr('Παρελθόν'),
            active: tab == 1,
            onTap: () => onTab(1),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kGuideBg : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kAccent : _kBorder),
        ),
        child: Text(label,
          style: GoogleFonts.inter(
            fontSize: 13, fontWeight: FontWeight.w600,
            color: active ? _kAccent : _kGray)),
      ),
    );
  }
}

// ─── Filter row ───────────────────────────────────────────────────────────────

class _FilterRow extends StatelessWidget {
  const _FilterRow({
    required this.gymOptions,
    required this.gymFilter,
    required this.roleFilter,
    required this.gymName,
    required this.onGym,
    required this.onRole,
  });
  final List<String> gymOptions;
  final String? gymFilter;
  final String? roleFilter;
  final String Function(String) gymName;
  final ValueChanged<String?> onGym;
  final ValueChanged<String?> onRole;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          if (gymOptions.length > 1) ...[
            _FilterChip(
              label: gymFilter == null
                  ? tr('Όλα τα γυμναστήρια')
                  : gymName(gymFilter!),
              active: gymFilter != null,
              onTap: () => _showGymSheet(context),
            ),
            const SizedBox(width: 8),
          ],
          _FilterChip(
            label: roleFilter == null
                ? tr('Όλοι οι ρόλοι')
                : _roleLabel(roleFilter!),
            active: roleFilter != null,
            onTap: () => _showRoleSheet(context),
          ),
        ],
      ),
    );
  }

  void _showGymSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(tr('Φιλτράρισμα κατά γυμναστήριο'),
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
              ),
              const SizedBox(height: 8),
              _SheetItem(
                label: tr('Όλα τα γυμναστήρια'),
                selected: gymFilter == null,
                onTap: () { onGym(null); Navigator.pop(context); },
              ),
              for (final id in gymOptions)
                _SheetItem(
                  label: gymName(id),
                  selected: gymFilter == id,
                  onTap: () { onGym(id); Navigator.pop(context); },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }

  void _showRoleSheet(BuildContext context) {
    final roles = [
      ('member', tr('Αθλητής')),
      ('staff', tr('Προπονητής')),
      ('nutritionist', tr('Διατροφολόγος')),
    ];
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: _kCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 36, height: 4,
                decoration: BoxDecoration(
                  color: _kBorder, borderRadius: BorderRadius.circular(2)),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(tr('Φιλτράρισμα κατά ρόλο'),
                  style: GoogleFonts.inter(
                    fontSize: 15, fontWeight: FontWeight.w700, color: _kText)),
              ),
              const SizedBox(height: 8),
              _SheetItem(
                label: tr('Όλοι οι ρόλοι'),
                selected: roleFilter == null,
                onTap: () { onRole(null); Navigator.pop(context); },
              ),
              for (final r in roles)
                _SheetItem(
                  label: r.$2,
                  selected: roleFilter == r.$1,
                  onTap: () { onRole(r.$1); Navigator.pop(context); },
                ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.active, required this.onTap});
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active ? _kGuideBg : _kCard,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: active ? _kAccent : _kBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: active ? _kAccent : _kGray)),
            const SizedBox(width: 4),
            Icon(Icons.keyboard_arrow_down_rounded,
              size: 14, color: active ? _kAccent : _kGray),
          ],
        ),
      ),
    );
  }
}

class _SheetItem extends StatelessWidget {
  const _SheetItem({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        color: Colors.transparent,
        child: Row(
          children: [
            Text(label,
              style: GoogleFonts.inter(
                fontSize: 14, color: selected ? _kAccent : _kText)),
            const Spacer(),
            if (selected)
              const Icon(Icons.check_rounded, color: _kAccent, size: 18),
          ],
        ),
      ),
    );
  }
}

// ─── Date header ─────────────────────────────────────────────────────────────

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 10),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w700,
          color: _kGray, letterSpacing: 0.5)),
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.gymName,
    this.onTap,
    this.onManage,
  });
  final Map<String, dynamic> booking;
  final String gymName;
  final VoidCallback? onTap;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final role     = booking['role']?.toString() ?? 'member';
    final rawTime  = booking['booking_time']?.toString() ?? '';
    final durationMins = int.tryParse(booking['duration_mins']?.toString() ?? '') ?? 0;
    final timeStr  = durationMins > 0
        ? _fmtTimeRange(rawTime, durationMins)
        : _fmtTime(rawTime);
    final service  = booking['service_name']?.toString() ?? '';
    final status   = booking['status']?.toString() ?? 'confirmed';
    final location = booking['location_name']?.toString();
    final isTrainer = role == 'staff';
    final who = isTrainer
        ? (booking['client_name']?.toString() ?? '')
        : (booking['staff_name']?.toString() ?? '');
    final isCancel = status == 'cancelled';
    final barColor = isCancel ? _kBorder : _roleBar(role);
    final isStaffBooking = booking['booking_type']?.toString() == 'appointment' ||
        (isTrainer && booking['client_name'] != null);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: _kCard,
          borderRadius: BorderRadius.circular(16),
          border: Border(
            top: BorderSide(color: _kBorder),
            right: BorderSide(color: _kBorder),
            bottom: BorderSide(color: _kBorder),
            left: BorderSide(color: barColor, width: 3),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(timeStr,
                    style: GoogleFonts.inter(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: isCancel ? _kGray : _kAccent)),
                  const SizedBox(width: 8),
                  if (!isCancel) _StatusBadge(status: status),
                  if (isCancel) _StatusBadge(status: 'cancelled'),
                ],
              ),
              const SizedBox(height: 6),
              Text(service,
                style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700, color: _kText)),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  if (gymName.isNotEmpty) _SmallBadge(label: gymName, bg: _kGuideBg, fg: _kGray),
                  _SmallBadge(
                    label: _roleLabel(role),
                    bg: _roleBadgeBg(role),
                    fg: _roleBadgeText(role),
                  ),
                ],
              ),
              if (who.isNotEmpty || (location != null && location.isNotEmpty)) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.location_on_outlined, size: 12, color: _kGray2),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        [if (who.isNotEmpty) who, if (location != null && location.isNotEmpty) location].join(' · '),
                        style: GoogleFonts.inter(fontSize: 12, color: _kGray2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
              if (isStaffBooking) ...[
                const SizedBox(height: 10),
                _GuideBox(
                  icon: Icons.person_outline_rounded,
                  text: tr('Επαγγελματικό ραντεβού · Για αλλαγή, επικοινωνήστε με τον πελάτη.'),
                ),
              ],
              if (!isCancel && onManage != null) ...[
                const SizedBox(height: 12),
                Container(height: 1, color: _kBorder),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: GestureDetector(
                    onTap: onManage,
                    child: Container(
                      height: 36,
                      decoration: BoxDecoration(
                        color: _kGuideBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
                      ),
                      child: Center(
                        child: Text(tr('Διαχείριση κράτησης'),
                          style: GoogleFonts.inter(
                            fontSize: 12, fontWeight: FontWeight.w700, color: _kAccent)),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    Color bg, fg;
    String label;
    switch (status) {
      case 'confirmed':
        bg = _kGreenBg; fg = _kGreen; label = tr('Επιβεβαιωμένη');
      case 'waitlist':
        bg = const Color(0xFF2A2004); fg = const Color(0xFFF5C542); label = tr('Λίστα αναμονής');
      case 'cancelled':
        bg = const Color(0xFF2A0F0F); fg = const Color(0xFFE07070); label = tr('Ακυρωμένη');
      default:
        bg = _kGuideBg; fg = _kGray; label = status;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 10, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge({required this.label, required this.bg, required this.fg});
  final String label;
  final Color bg, fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(label,
        style: GoogleFonts.inter(
          fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

class _GuideBox extends StatelessWidget {
  const _GuideBox({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _kGuideBg, borderRadius: BorderRadius.circular(10)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kAccent, size: 14),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text,
              style: GoogleFonts.inter(
                fontSize: 11, color: _kGray, height: 1.4)),
          ),
        ],
      ),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onExplore});
  final VoidCallback onExplore;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      children: [
        const SizedBox(height: 16),

        // Orbital illustration
        Center(
          child: SizedBox(
            width: 160, height: 160,
            child: CustomPaint(painter: _OrbitalPainter()),
          ),
        ),
        const SizedBox(height: 28),

        Text(tr('Η επόμενη συνεδρία σου ξεκινά εδώ.'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 22, fontWeight: FontWeight.w800, color: _kText, height: 1.2)),
        const SizedBox(height: 10),
        Text(
          tr('Καμία επερχόμενη κράτηση ή αναμονή στα γυμναστήρια και τους ρόλους σου. Ας βρούμε κάτι να ανυπομονείς.'),
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 14, color: _kGray, height: 1.5)),
        const SizedBox(height: 28),

        GestureDetector(
          onTap: onExplore,
          child: Container(
            height: 48,
            decoration: BoxDecoration(
              color: _kPrimary, borderRadius: BorderRadius.circular(12)),
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('Εξερεύνησε υπηρεσίες'),
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
                  const SizedBox(width: 6),
                  const Icon(Icons.arrow_forward_rounded, color: _kText, size: 14),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Container(
          height: 48,
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Center(
            child: Text(tr('Προβολή παλαιών κρατήσεων →'),
              style: GoogleFonts.inter(
                fontSize: 13, fontWeight: FontWeight.w600, color: _kGray)),
          ),
        ),
        const SizedBox(height: 20),

        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: _kGuideBg, borderRadius: BorderRadius.circular(12)),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.info_outline_rounded, color: _kAccent, size: 16),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('Επιβεβαιωμένες συνεδρίες, επαναλαμβανόμενες κρατήσεις και λίστες αναμονής θα εμφανιστούν εδώ όταν τις προσθέσεις.'),
                  style: GoogleFonts.inter(
                    fontSize: 12, color: _kGray, height: 1.45)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OrbitalPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final paint = Paint()
      ..color = _kBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    canvas.drawOval(Rect.fromCenter(
      center: Offset(cx, cy), width: size.width * 0.95, height: size.height * 0.45), paint);
    canvas.drawOval(Rect.fromCenter(
      center: Offset(cx, cy), width: size.width * 0.65, height: size.height * 0.68), paint);

    final boxRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(cx, cy), width: 64, height: 64),
      const Radius.circular(18));
    canvas.drawRRect(boxRect, Paint()..color = _kGuideBg);
    canvas.drawRRect(boxRect, Paint()
      ..color = _kBorder
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1);

    const iconColor = _kAccent;
    final iconPaint = Paint()..color = iconColor..strokeWidth = 2..style = PaintingStyle.stroke..strokeCap = StrokeCap.round;
    final ics = Offset(cx, cy);
    canvas.drawLine(Offset(ics.dx - 8, ics.dy + 10), Offset(ics.dx + 8, ics.dy + 10), iconPaint);
    canvas.drawLine(Offset(ics.dx - 8, ics.dy + 4), Offset(ics.dx + 8, ics.dy + 4), iconPaint);
    canvas.drawLine(Offset(ics.dx - 8, ics.dy - 2), Offset(ics.dx + 4, ics.dy - 2), iconPaint);
    canvas.drawLine(Offset(ics.dx + 6, ics.dy - 6), Offset(ics.dx + 11, ics.dy - 1), iconPaint);
    canvas.drawLine(Offset(ics.dx + 11, ics.dy - 6), Offset(ics.dx + 6, ics.dy - 1), iconPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ─── Past bookings tab ────────────────────────────────────────────────────────

class _PastTab extends StatefulWidget {
  const _PastTab({required this.globalAuth, required this.gyms});
  final GlobalAuthService globalAuth;
  final List<GlobalGym> gyms;

  @override
  State<_PastTab> createState() => _PastTabState();
}

class _PastTabState extends State<_PastTab> {
  bool _loading = false;
  List<Map<String, dynamic>> _past = [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.gyms.isEmpty) return;
    setState(() { _loading = true; _error = null; });
    try {
      final token = widget.globalAuth.token;
      if (token == null) {
        setState(() { _loading = false; });
        return;
      }
      final results = await Future.wait(
        widget.gyms.map((g) async {
          try {
            final res = await http.get(
              Uri.parse('$_kApiBase/booking/${g.businessId}/my-bookings'),
              headers: {'Authorization': 'Bearer $token'},
            ).timeout(const Duration(seconds: 15));
            if (res.statusCode == 200) {
              final data = jsonDecode(res.body);
              final list = (data['bookings'] as List? ??
                  data['data'] as List? ?? []).cast<Map<String, dynamic>>();
              return list.map((b) => {...b, '_gym_name': g.appName, '_biz_id': g.businessId}).toList();
            }
          } catch (_) {}
          return <Map<String, dynamic>>[];
        }),
      );
      final all = results.expand((r) => r).toList();
      final today = _dateKey(DateTime.now());
      final past = all.where((b) {
        final d = b['booking_date']?.toString() ?? '';
        final s = b['status']?.toString() ?? '';
        return d.compareTo(today) < 0 || s == 'cancelled' || s == 'completed';
      }).toList()
        ..sort((a, b) {
          final da = a['booking_date']?.toString() ?? '';
          final db = b['booking_date']?.toString() ?? '';
          return db.compareTo(da);
        });
      setState(() { _past = past; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: _kAccent));
    }
    if (_error != null) {
      return Center(
        child: Text(tr('Σφάλμα φόρτωσης: $_error'),
          style: GoogleFonts.inter(color: _kGray)));
    }
    if (_past.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.history_rounded, color: _kGray, size: 40),
            const SizedBox(height: 12),
            Text(tr('Δεν υπάρχουν παλαιές κρατήσεις'),
              style: GoogleFonts.inter(fontSize: 15, color: _kGray)),
          ],
        ),
      );
    }

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final b in _past) {
      final key = b['booking_date']?.toString() ?? '';
      grouped.putIfAbsent(key, () => []).add(b);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        for (final dateKey in grouped.keys) ...[
          _DateHeader(label: _groupLabel(dateKey)),
          for (final booking in grouped[dateKey]!)
            _BookingCard(
              booking: booking,
              gymName: booking['_gym_name']?.toString() ??
                  booking['app_name']?.toString() ??
                  booking['business_name']?.toString() ?? '',
            ),
        ],
      ],
    );
  }
}

// ─── Programme screen (week calendar view) ───────────────────────────────────

class _ProgrammeScreen extends StatefulWidget {
  const _ProgrammeScreen({
    required this.globalAuth,
    required this.gyms,
    required this.upcoming,
    required this.onEnterGym,
  });
  final GlobalAuthService globalAuth;
  final List<GlobalGym> gyms;
  final List<Map<String, dynamic>> upcoming;
  final Future<void> Function(GlobalGym) onEnterGym;

  @override
  State<_ProgrammeScreen> createState() => _ProgrammeScreenState();
}

class _ProgrammeScreenState extends State<_ProgrammeScreen> {
  int _weekOffset = 0;
  DateTime _selected = DateTime.now();

  List<DateTime> get _weekDays {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    return List.generate(7, (i) => monday.add(Duration(days: i + _weekOffset * 7)));
  }

  String _dateKey2(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';

  List<Map<String, dynamic>> _bookingsForDay(DateTime d) {
    final key = _dateKey2(d);
    return widget.upcoming.where((b) => b['booking_date'] == key).toList()
      ..sort((a, b) =>
          (a['booking_time']?.toString() ?? '').compareTo(b['booking_time']?.toString() ?? ''));
  }


  Map<String, List<Map<String, dynamic>>> _rolesForDay(DateTime d) {
    final bookings = _bookingsForDay(d);
    final map = <String, List<Map<String, dynamic>>>{};
    for (final b in bookings) {
      final role = b['role']?.toString() ?? 'member';
      map.putIfAbsent(role, () => []).add(b);
    }
    return map;
  }

  String _weekRange() {
    final days = _weekDays;
    final start = days.first;
    final end = days.last;
    final months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
    if (start.month == end.month) {
      return '${start.day}–${end.day} ${months[start.month - 1]} ${start.year}';
    }
    return '${start.day} ${months[start.month - 1]} – ${end.day} ${months[end.month - 1]} ${start.year}';
  }

  String _weekStats() {
    final days = _weekDays;
    final keys = days.map(_dateKey2).toSet();
    final bookings = widget.upcoming.where((b) => keys.contains(b['booking_date'])).toList();
    final roles = bookings.map((b) => b['role']?.toString() ?? 'member').toSet();
    int totalMins = 0;
    for (final b in bookings) {
      totalMins += int.tryParse(b['duration_mins']?.toString() ?? '') ?? 45;
    }
    final h = totalMins ~/ 60;
    final m = totalMins % 60;
    final durStr = h > 0 ? (m > 0 ? '${h}ω ${m}λ' : '${h}ω') : '${m}λ';
    return '${bookings.length} συνεδρίες · $durStr · ${roles.length} ρόλοι';
  }

  String _selectedLabel() {
    final d = _selected;
    final now = DateTime.now();
    final isToday = d.day == now.day && d.month == now.month && d.year == now.year;
    final days = ['Δευτέρα','Τρίτη','Τετάρτη','Πέμπτη','Παρασκευή','Σάββατο','Κυριακή'];
    final months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
    return '${days[d.weekday - 1]}, ${d.day} ${months[d.month - 1]}${isToday ? ' · Σήμερα' : ''}';
  }

  @override
  Widget build(BuildContext context) {
    final days = _weekDays;
    final bookings = _bookingsForDay(_selected);

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: Column(
          children: [
            // App bar
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _kCard, borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _kBorder)),
                      child: const Icon(Icons.arrow_back_rounded, color: _kText, size: 18),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(tr('Κρατήσεις'),
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _kGray)),
                  const Icon(Icons.chevron_right_rounded, color: _kGray, size: 16),
                  Text(tr('Το πρόγραμμά μου'),
                    style: GoogleFonts.inter(
                      fontSize: 15, fontWeight: FontWeight.w600, color: _kText)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tr('Το πρόγραμμά μου'),
                    style: GoogleFonts.inter(
                      fontSize: 28, fontWeight: FontWeight.w800, color: _kText)),
                  const SizedBox(height: 4),
                  Text(tr('Κάθε γυμναστήριο. Κάθε ρόλος. Μια ξεκάθαρη εικόνα.'),
                    style: GoogleFonts.inter(fontSize: 13, color: _kGray)),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Week navigation
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(_weekRange(),
                          style: GoogleFonts.inter(
                            fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
                        const SizedBox(height: 2),
                        Text(_weekStats(),
                          style: GoogleFonts.inter(fontSize: 11, color: _kGray)),
                      ],
                    ),
                  ),
                  _NavBtn(
                    icon: Icons.chevron_left_rounded,
                    onTap: () => setState(() => _weekOffset--),
                  ),
                  const SizedBox(width: 8),
                  _NavBtn(
                    icon: Icons.chevron_right_rounded,
                    onTap: () => setState(() => _weekOffset++),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // 7-column calendar grid
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: _kCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _kBorder),
                ),
                padding: const EdgeInsets.all(8),
                child: Row(
                  children: List.generate(7, (i) {
                    final day = days[i];
                    final isSelected = _dateKey2(day) == _dateKey2(_selected);
                    final isToday = _dateKey2(day) == _dateKey2(DateTime.now());
                    final rolesMap = _rolesForDay(day);
                    final dayLetters = ['Δ','Τ','Τ','Π','Π','Σ','Κ'];

                    return Expanded(
                      child: GestureDetector(
                        onTap: () => setState(() => _selected = day),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2),
                          decoration: BoxDecoration(
                            color: isSelected ? _kGuideBg : Colors.transparent,
                            borderRadius: BorderRadius.circular(10),
                            border: isSelected
                                ? Border.all(color: _kAccent)
                                : isToday
                                    ? Border.all(color: _kAccent.withValues(alpha: 0.3))
                                    : null,
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 2),
                          child: Column(
                            children: [
                              Text(dayLetters[i],
                                style: GoogleFonts.inter(
                                  fontSize: 9, fontWeight: FontWeight.w700,
                                  color: isSelected ? _kAccent : _kGray)),
                              const SizedBox(height: 4),
                              Text('${day.day}',
                                style: GoogleFonts.inter(
                                  fontSize: 14, fontWeight: FontWeight.w700,
                                  color: isSelected ? _kAccent : _kText)),
                              const SizedBox(height: 6),
                              // role dots
                              if (rolesMap.isNotEmpty)
                                ...rolesMap.keys.map((role) => Container(
                                  margin: const EdgeInsets.symmetric(vertical: 1),
                                  height: 3,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: _roleBar(role),
                                    borderRadius: BorderRadius.circular(2)),
                                ))
                              else
                                const SizedBox(height: 5),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Selected day label
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Text(_selectedLabel(),
                    style: GoogleFonts.inter(
                      fontSize: 13, fontWeight: FontWeight.w700, color: _kText)),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Session list for selected day
            Expanded(
              child: bookings.isEmpty
                  ? Center(
                      child: Text(tr('Δεν υπάρχουν συνεδρίες αυτή την ημέρα'),
                        style: GoogleFonts.inter(fontSize: 14, color: _kGray)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount: bookings.length,
                      itemBuilder: (_, i) => _BookingCard(
                        booking: bookings[i],
                        gymName: _gymNameFor(bookings[i]),
                      ),
                    ),
            ),

            // Legend
            if (widget.upcoming.isNotEmpty) ...[
              Container(height: 1, color: _kBorder),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: _Legend(upcoming: widget.upcoming),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _gymNameFor(Map<String, dynamic> b) {
    final bizId = b['business_id']?.toString();
    if (bizId == null) return b['app_name']?.toString() ?? b['business_name']?.toString() ?? '';
    for (final g in widget.gyms) {
      if (g.businessId == bizId) return g.appName;
    }
    return b['app_name']?.toString() ?? b['business_name']?.toString() ?? '';
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.upcoming});
  final List<Map<String, dynamic>> upcoming;

  @override
  Widget build(BuildContext context) {
    final roleCounts = <String, int>{};
    for (final b in upcoming) {
      final r = b['role']?.toString() ?? 'member';
      roleCounts[r] = (roleCounts[r] ?? 0) + 1;
    }
    final entries = roleCounts.entries.toList();
    return Row(
      children: entries.map((e) {
        return Padding(
          padding: const EdgeInsets.only(right: 16),
          child: Row(
            children: [
              Container(width: 8, height: 8,
                decoration: BoxDecoration(
                  color: _roleBar(e.key), shape: BoxShape.circle)),
              const SizedBox(width: 6),
              Text('${_roleLabel(e.key)} · ${e.value}',
                style: GoogleFonts.inter(fontSize: 11, color: _kGray)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _NavBtn extends StatelessWidget {
  const _NavBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: 34, height: 34,
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _kBorder)),
      child: Icon(icon, color: _kText, size: 18),
    ),
  );
}

// ─── Booking detail sheet ─────────────────────────────────────────────────────

class _BookingDetailSheet extends StatelessWidget {
  const _BookingDetailSheet({required this.booking, this.onOpenGym});
  final Map<String, dynamic> booking;
  final VoidCallback? onOpenGym;

  @override
  Widget build(BuildContext context) {
    final role     = booking['role']?.toString() ?? 'member';
    final rawTime  = booking['booking_time']?.toString() ?? '';
    final durationMins = int.tryParse(booking['duration_mins']?.toString() ?? '') ?? 0;
    final timeStr  = durationMins > 0
        ? _fmtTimeRange(rawTime, durationMins)
        : _fmtTime(rawTime);
    final service  = booking['service_name']?.toString() ?? '';
    final gym      = booking['app_name']?.toString() ?? booking['business_name']?.toString() ?? '';
    final status   = booking['status']?.toString() ?? 'confirmed';
    final location = booking['location_name']?.toString();
    final isTrainer = role == 'staff';
    final who      = isTrainer
        ? (booking['client_name']?.toString())
        : (booking['staff_name']?.toString());
    final date     = booking['booking_date']?.toString() ?? '';
    final imgUrl   = booking['service_image_url']?.toString();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                color: _kBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 20),

          if (imgUrl != null && imgUrl.isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imgUrl,
                height: 160, width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
            const SizedBox(height: 16),
          ],

          Row(children: [
            _StatusBadge(status: status),
            const SizedBox(width: 8),
            _SmallBadge(
              label: _roleLabel(role),
              bg: _roleBadgeBg(role),
              fg: _roleBadgeText(role),
            ),
          ]),
          const SizedBox(height: 10),

          Text(service,
            style: GoogleFonts.inter(
              fontSize: 20, fontWeight: FontWeight.w800, color: _kText)),
          const SizedBox(height: 12),

          _DetailRow(icon: Icons.access_time_rounded,
            label: tr('Ώρα'), value: '$date · $timeStr'),
          if (gym.isNotEmpty)
            _DetailRow(icon: Icons.fitness_center_rounded,
              label: tr('Γυμναστήριο'), value: gym),
          if (who != null && who.isNotEmpty)
            _DetailRow(
              icon: Icons.person_outline_rounded,
              label: isTrainer ? tr('Πελάτης') : tr('Προπονητής'),
              value: who,
            ),
          if (location != null && location.isNotEmpty)
            _DetailRow(icon: Icons.location_on_outlined,
              label: tr('Τοποθεσία'), value: location),

          const SizedBox(height: 16),
          if (onOpenGym != null)
            GestureDetector(
              onTap: () { Navigator.pop(context); onOpenGym!(); },
              child: Container(
                width: double.infinity, height: 48,
                decoration: BoxDecoration(
                  color: _kGuideBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _kAccent.withValues(alpha: 0.4)),
                ),
                child: Center(
                  child: Text(tr('Άνοιγμα γυμναστηρίου'),
                    style: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700, color: _kAccent)),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, required this.value});
  final IconData icon;
  final String label, value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _kGray, size: 16),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                style: GoogleFonts.inter(fontSize: 11, color: _kGray2)),
              Text(value,
                style: GoogleFonts.inter(fontSize: 14, color: _kText)),
            ],
          ),
        ],
      ),
    );
  }
}
