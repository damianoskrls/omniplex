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
const _kAccent  = Color(0xFF9A9DFF);
const _kPrimary = Color(0xFF565CE4);
const _kGuideBg = Color(0xFF242642);
const _kGold    = Color(0xFFF0CC85);
const _kGoldBg  = Color(0xFF362D20);
const _kGreen   = Color(0xFF8DE2BB);
const _kGreenBg = Color(0xFF17332B);
const _kIconBg  = Color(0xFF1C1F2B);

enum _JoinStep { checking, chooseRole, profile, pending, existingMembership }

class JoinGymFlowScreen extends StatefulWidget {
  const JoinGymFlowScreen({
    super.key,
    required this.gym,
    required this.globalAuth,
    this.locationId,
    this.onGymAdded,
    this.onRequestSent,
    this.onBrowseGyms,
  });

  final Map<String, dynamic> gym;
  final GlobalAuthService globalAuth;
  final String? locationId;
  final VoidCallback? onGymAdded;
  final VoidCallback? onRequestSent;
  final VoidCallback? onBrowseGyms;

  @override
  State<JoinGymFlowScreen> createState() => _JoinGymFlowScreenState();
}

class _JoinGymFlowScreenState extends State<JoinGymFlowScreen> {
  _JoinStep _step = _JoinStep.checking;
  String? _selectedRole;
  String? _selectedSpecialty;
  String? _selectedRoleLabel;
  bool _submitting = false;
  String? _error;
  Map<String, dynamic>? _claimResult;
  String? _requestedAt;
  String? _gymPhotoUrl;

  static const _apiBase = 'https://passionate-grace-production-98ad.up.railway.app/api';

  String get _gymName =>
      widget.gym['name'] as String? ??
      widget.gym['gym_name'] as String? ??
      'Γυμναστήριο';

  String get _gymCity {
    final locs = (widget.gym['locations'] as List?) ?? [];
    if (locs.isNotEmpty) {
      final first = locs.first as Map;
      return (first['city'] as String? ?? first['address'] as String? ?? '').toString();
    }
    return '';
  }

  String get _resolvedLocationId {
    if (widget.locationId != null && widget.locationId!.isNotEmpty) {
      return widget.locationId!;
    }
    final locs = (widget.gym['locations'] as List?) ?? [];
    if (locs.length == 1) return (locs.first as Map)['id'] as String? ?? '';
    return '';
  }

  @override
  void initState() {
    super.initState();
    _gymPhotoUrl = _extractPhotoUrl();
    _attemptClaim();
  }

  String? _extractPhotoUrl() {
    final photos = widget.gym['photos'] as List?;
    if (photos != null && photos.isNotEmpty) {
      final first = photos.first;
      if (first is Map) return first['url'] as String?;
      if (first is String) return first;
    }
    final cover = widget.gym['cover_photo'] as String?;
    if (cover != null && cover.isNotEmpty) return cover;
    return null;
  }

  Future<void> _attemptClaim() async {
    final bizId = widget.gym['business_id'] as String?;
    if (bizId == null) {
      setState(() => _step = _JoinStep.chooseRole);
      return;
    }
    try {
      final result = await widget.globalAuth.claimGym(bizId);
      if (!mounted) return;
      if (result['status'] == 'linked') {
        _claimResult = result;
        setState(() => _step = _JoinStep.existingMembership);
      } else {
        setState(() => _step = _JoinStep.chooseRole);
      }
    } catch (_) {
      if (mounted) setState(() => _step = _JoinStep.chooseRole);
    }
  }

  Future<void> _submitRequest() async {
    final bizId = widget.gym['business_id'] as String?;
    if (bizId == null || _selectedRole == null) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      final locId = _resolvedLocationId;
      final res = await http.post(
        Uri.parse('$_apiBase/global/join-requests'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer ${widget.globalAuth.token}',
        },
        body: jsonEncode({
          'business_id': bizId,
          'role': _selectedRole,
          if (_selectedSpecialty != null) 'specialty': _selectedSpecialty,
          if ((widget.globalAuth.user?.fullName ?? '').isNotEmpty)
            'full_name': widget.globalAuth.user!.fullName,
          if ((widget.globalAuth.user?.phone ?? '').isNotEmpty)
            'phone': widget.globalAuth.user!.phone,
          if ((widget.globalAuth.user?.email ?? '').isNotEmpty)
            'email': widget.globalAuth.user!.email,
          if (locId.isNotEmpty) 'location_id': locId,
        }),
      );
      if (!mounted) return;
      final body = jsonDecode(res.body) as Map<String, dynamic>;
      if (res.statusCode == 200 || res.statusCode == 201) {
        await widget.globalAuth.refreshGyms();
        if (!mounted) return;
        if (body['status'] == 'linked') {
          _claimResult = body;
          setState(() => _step = _JoinStep.existingMembership);
          widget.onGymAdded?.call();
        } else {
          _requestedAt = _todayLabel();
          setState(() => _step = _JoinStep.pending);
          widget.onRequestSent?.call();
        }
      } else {
        setState(() =>
            _error = (body['message'] ?? body['error'] ?? tr('Σφάλμα')).toString());
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  String _todayLabel() {
    final now = DateTime.now();
    const months = [
      'Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαΐ', 'Ιουν',
      'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'
    ];
    return '${now.day} ${months[now.month - 1]} ${now.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: switch (_step) {
          _JoinStep.checking           => _buildChecking(),
          _JoinStep.chooseRole         => _buildChooseRole(),
          _JoinStep.profile            => _buildProfile(),
          _JoinStep.pending            => _buildPending(),
          _JoinStep.existingMembership => _buildExistingMembership(),
        },
      ),
    );
  }

  // ── Φόρτωση ──────────────────────────────────────────────────────────────────

  Widget _buildChecking() {
    return const Center(
      child: CircularProgressIndicator(color: _kAccent, strokeWidth: 2),
    );
  }

  // ── Οθόνη 14: Επιλογή ρόλου ──────────────────────────────────────────────────

  Widget _buildChooseRole() {
    return Column(
      children: [
        _buildHeader(title: tr('Προσθήκη στα Γυμναστήριά μου'), showBack: true),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                _StatusBadge(
                  text: _gymName.toUpperCase() +
                      (_gymCity.isNotEmpty
                          ? ' · ${_gymCity.toUpperCase()}'
                          : ''),
                ),
                const SizedBox(height: 22),
                _PageIntro(
                  eyebrow: tr('ΒΗΜΑ 1 ΑΠΟ 2'),
                  title: tr('Πώς θέλεις να κινηθείς;'),
                  body: tr(
                    'Επέλεξε τον ρόλο σου στο $_gymName. Οι ρόλοι είναι ειδικοί για κάθε γυμναστήριο, όχι για όλο τον λογαριασμό σου.',
                  ),
                ),
                const SizedBox(height: 22),
                _RoleOption(
                  icon: Icons.fitness_center_rounded,
                  title: tr('Αθλητής'),
                  subtitle: tr('Γυμνάσου, κάνε μαθήματα και παρακολούθησε τις συνεδρίες σου.'),
                  selected: _selectedRole == 'member',
                  onTap: () => setState(() {
                    _selectedRole = 'member';
                    _selectedSpecialty = null;
                    _selectedRoleLabel = tr('Αθλητής');
                  }),
                ),
                const SizedBox(height: 12),
                _RoleOption(
                  icon: Icons.assignment_outlined,
                  title: tr('Προπονητής'),
                  subtitle: tr('Καθοδήγησε συνεδρίες και διαχειρίσου τους πελάτες σου.'),
                  selected: _selectedRole == 'staff' &&
                      _selectedSpecialty == 'Trainer',
                  onTap: () => setState(() {
                    _selectedRole = 'staff';
                    _selectedSpecialty = 'Trainer';
                    _selectedRoleLabel = tr('Προπονητής');
                  }),
                ),
                const SizedBox(height: 12),
                _RoleOption(
                  icon: Icons.restaurant_menu_rounded,
                  title: tr('Διατροφολόγος'),
                  subtitle: tr('Υποστήριξε πελάτες και παρακολούθησε διατροφικά πλάνα.'),
                  selected: _selectedRole == 'staff' &&
                      _selectedSpecialty == 'Διατροφολόγος',
                  onTap: () => setState(() {
                    _selectedRole = 'staff';
                    _selectedSpecialty = 'Διατροφολόγος';
                    _selectedRoleLabel = tr('Διατροφολόγος');
                  }),
                ),
                const SizedBox(height: 12),
                _RoleOption(
                  icon: Icons.show_chart_rounded,
                  title: tr('Φυσιοθεραπευτής'),
                  subtitle: tr('Διαχειρίσου ραντεβού αποκατάστασης και φροντίδας.'),
                  selected: _selectedRole == 'staff' &&
                      _selectedSpecialty == 'Φυσιοθεραπευτής',
                  onTap: () => setState(() {
                    _selectedRole = 'staff';
                    _selectedSpecialty = 'Φυσιοθεραπευτής';
                    _selectedRoleLabel = tr('Φυσιοθεραπευτής');
                  }),
                ),
                const SizedBox(height: 22),
                _GuidanceBox(
                  icon: Icons.info_outline,
                  text: tr(
                    'Τα αιτήματα πρόσβασης ελέγχονται από το γυμναστήριο. Οι επαγγελματικοί ρόλοι απαιτούν έγκριση. Η αγορά πλάνου Αθλητή είναι ξεχωριστή διαδρομή, άμεσα ενεργή.',
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        _buildBottomAction(
          label: _selectedRole != null
              ? tr('Συνέχεια ως $_selectedRoleLabel')
              : tr('Επέλεξε ρόλο'),
          icon: Icons.arrow_forward,
          enabled: _selectedRole != null,
          onTap: () => setState(() => _step = _JoinStep.profile),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  // ── Οθόνη 15: Συμπλήρωση προφίλ ─────────────────────────────────────────────

  Widget _buildProfile() {
    final user = widget.globalAuth.user;
    return Column(
      children: [
        _buildHeader(
          title: tr('Το προφίλ σου στο γυμναστήριο'),
          showBack: true,
          onPop: () => setState(() => _step = _JoinStep.chooseRole),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                _PageIntro(
                  eyebrow: tr('ΒΗΜΑ 2 ΑΠΟ 2'),
                  title: tr('Κάντο προσωπικό.'),
                  body: tr(
                    'Πες στο $_gymName ποιος/α είσαι. Το γυμναστήριο θα εξετάσει το αίτημά σου.',
                  ),
                ),
                const SizedBox(height: 22),
                _InputGroup(
                  label: tr('Ονοματεπώνυμο'),
                  value: user?.fullName ?? '',
                ),
                const SizedBox(height: 18),
                _InputGroup(
                  label: tr('Διεύθυνση email'),
                  value: user?.email ?? '',
                ),
                const SizedBox(height: 18),
                _InputGroupWithSuffix(
                  label: tr('Επαληθευμένο κινητό'),
                  value: user?.phone ?? '',
                  suffix: const Icon(
                    Icons.verified_outlined,
                    color: _kAccent,
                    size: 18,
                  ),
                ),
                const SizedBox(height: 18),
                _GymSummaryCard(
                  gymName: _gymName,
                  gymCity: _gymCity,
                  roleLabel: _selectedRoleLabel ?? '',
                ),
                const SizedBox(height: 18),
                _GuidanceBox(
                  icon: Icons.verified_outlined,
                  text: tr(
                    'Το όνομα, email και κινητό σου κοινοποιούνται στο $_gymName για επαλήθευση της σχέσης σου με το γυμναστήριο.',
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorBanner(_error!),
                ],
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        _buildBottomAction(
          label: tr('Αίτημα πρόσβασης'),
          icon: Icons.send_outlined,
          enabled: !_submitting,
          loading: _submitting,
          onTap: _submitRequest,
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text(
            tr('Δεν απαιτείται πληρωμή για την υποβολή αιτήματος.'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _kGray, fontSize: 11, height: 1.45),
          ),
        ),
      ],
    );
  }

  // ── Οθόνη 16: Αίτημα εκκρεμεί ────────────────────────────────────────────────

  Widget _buildPending() {
    return Column(
      children: [
        _buildHeader(title: tr('Αίτημα εστάλη'), showBack: false),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      color: _kGoldBg,
                      borderRadius: BorderRadius.circular(28),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.hourglass_empty_rounded,
                      color: _kGold,
                      size: 36,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  tr('Σε γνωρίζουν.'),
                  style: GoogleFonts.inter(
                    color: _kText,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Το αίτημά σου εστάλη στο $_gymName. Θα σε ενημερώσουμε όταν το εξετάσει το γυμναστήριο.'),
                  style: GoogleFonts.inter(
                    color: _kGray, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 22),
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: _kIconBg,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.show_chart_rounded,
                              color: _kAccent,
                              size: 19,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _gymName,
                                  style: GoogleFonts.inter(
                                    color: _kText,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                  ),
                                ),
                                Text(
                                  '${_selectedRoleLabel ?? ''} · ${tr('Αιτήθηκε')} ${_requestedAt ?? _todayLabel()}',
                                  style: GoogleFonts.inter(
                                    color: _kGray, fontSize: 12, height: 1.45),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Container(height: 1, color: _kBorder),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              tr('Πρόσβαση γυμναστηρίου'),
                              style: GoogleFonts.inter(
                                color: _kGray, fontSize: 12, height: 1.45),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kGoldBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tr('Εκκρεμεί έγκριση'),
                              style: GoogleFonts.inter(
                                color: _kGold, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('Εμφανίζεται στα Γυμναστήριά μου · Δεν διατίθεται κράτηση ακόμα'),
                        style: GoogleFonts.inter(
                          color: _kGray, fontSize: 12, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                _InfoRow(
                  icon: Icons.check_rounded,
                  title: tr('Αίτημα παραδόθηκε'),
                  body: tr('Το προφίλ σου κοινοποιήθηκε στο γυμναστήριο.'),
                ),
                const SizedBox(height: 18),
                _InfoRow(
                  icon: Icons.schedule_outlined,
                  title: tr('Αναμένεται έγκριση από τη διοίκηση'),
                  body: tr('Συνήθως εντός 1–2 εργάσιμων ημερών.'),
                ),
                const SizedBox(height: 18),
                _InfoRow(
                  icon: Icons.notifications_none_outlined,
                  title: tr('Θα ενημερωθείς'),
                  body: tr('Η πρόσβαση ανοίγει μόλις εγκριθεί ο ρόλος σου.'),
                ),
                const SizedBox(height: 22),
                _GuidanceBox(
                  icon: Icons.info_outline,
                  iconColor: _kGold,
                  bgColor: _kGoldBg,
                  textColor: _kGold,
                  text: tr(
                    'Αυτό είναι αίτημα πρόσβασης σε γυμναστήριο, όχι αποθηκευμένο γυμναστήριο ή επί πληρωμή συνδρομή. Δεν μπορείς να κάνεις κράτηση στο $_gymName ακόμα.',
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
          child: _ActionButton(
            label: tr('Εξερεύνησε άλλα γυμναστήρια'),
            icon: Icons.explore_outlined,
            onTap: () {
              Navigator.of(context).popUntil((r) => r.isFirst);
              widget.onBrowseGyms?.call();
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          child: _OutlineButton(
            label: tr('Πήγαινε στα Γυμναστήριά μου'),
            icon: Icons.arrow_forward,
            onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
          ),
        ),
      ],
    );
  }

  // ── Οθόνη 17: Βρέθηκε ενεργή συνδρομή ───────────────────────────────────────

  Widget _buildExistingMembership() {
    final user = widget.globalAuth.user;
    final phoneSuffix = (user?.phone ?? '').length >= 4
        ? (user?.phone ?? '')
            .substring((user?.phone ?? '').length - 4)
        : (user?.phone ?? '');
    final membership = _claimResult?['membership'] as Map<String, dynamic>?;
    final membershipLabel =
        membership?['plan_name'] as String? ?? tr('Συνδρομή');
    final membershipExpiry = membership?['expires_at'] as String?;
    String expiryText = '';
    if (membershipExpiry != null && membershipExpiry.isNotEmpty) {
      try {
        final dt = DateTime.parse(membershipExpiry);
        const months = [
          'Ιαν', 'Φεβ', 'Μαρ', 'Απρ', 'Μαΐ', 'Ιουν',
          'Ιουλ', 'Αυγ', 'Σεπ', 'Οκτ', 'Νοε', 'Δεκ'
        ];
        expiryText =
            tr('Ισχύει έως ${dt.day} ${months[dt.month - 1]} ${dt.year}');
      } catch (_) {
        expiryText = membershipExpiry;
      }
    }
    final roles =
        (_claimResult?['roles'] as List?)?.map((r) => r.toString()).toList() ??
            [];
    final firstName = user?.fullName.split(' ').first ?? '';

    return Column(
      children: [
        _buildHeader(
          title: tr('Καλωσήρθες${firstName.isNotEmpty ? ', $firstName' : ''}'),
          showBack: false,
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 18),
                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      color: _kGreenBg,
                      borderRadius: BorderRadius.circular(26),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.verified_rounded,
                      color: _kGreen,
                      size: 38,
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                Text(
                  tr('Ανήκεις ήδη εδώ.'),
                  style: GoogleFonts.inter(
                    color: _kText,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  tr('Βρήκαμε το $_gymName μέσω του επαληθευμένου κινητού σου${phoneSuffix.isNotEmpty ? ' που τελειώνει σε $phoneSuffix' : ''}.'),
                  style: GoogleFonts.inter(
                    color: _kGray, fontSize: 14, height: 1.45),
                ),
                const SizedBox(height: 22),
                if (_gymPhotoUrl != null && _gymPhotoUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.network(
                      _gymPhotoUrl!,
                      height: 174,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                  const SizedBox(height: 22),
                ],
                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: _kCard,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: _kBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              _gymName,
                              style: GoogleFonts.inter(
                                color: _kText,
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                height: 1.45,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 5),
                            decoration: BoxDecoration(
                              color: _kGreenBg,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              tr('Ενεργή'),
                              style: GoogleFonts.inter(
                                color: _kGreen, fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      if (membershipLabel.isNotEmpty ||
                          expiryText.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text(
                          '$membershipLabel${expiryText.isNotEmpty ? ' · $expiryText' : ''}',
                          style: GoogleFonts.inter(
                            color: _kText, fontSize: 13, height: 1.45),
                        ),
                      ],
                      const SizedBox(height: 12),
                      Container(height: 1, color: _kBorder),
                      const SizedBox(height: 12),
                      Text(
                        tr('ΡΟΛΟΙ ΑΠΟ ΤΟ ΓΥΜΝΑΣΤΗΡΙΌ ΣΟΥ'),
                        style: GoogleFonts.inter(
                          color: _kGray,
                          fontSize: 11,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        children: (roles.isNotEmpty ? roles : [tr('Μέλος')])
                            .map((r) => Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 5),
                                  decoration: BoxDecoration(
                                    color: _kGuideBg,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    r,
                                    style: GoogleFonts.inter(
                                      color: _kAccent, fontSize: 10),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('Τα αρχεία του γυμναστηρίου επιβεβαιώνουν αυτούς τους ρόλους. Αλλαγή ρόλου μέσα από τον χώρο εργασίας $_gymName.'),
                        style: GoogleFonts.inter(
                          color: _kGray, fontSize: 12, height: 1.45),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _GuidanceBox(
                  icon: Icons.verified_outlined,
                  bgColor: _kGreenBg,
                  text: tr(
                    'Η αντιστοιχισμένη συνδρομή είναι άμεσα ενεργή. Δεν απαιτείται αγορά ή επιπλέον έγκριση.',
                  ),
                ),
                const SizedBox(height: 22),
              ],
            ),
          ),
        ),
        _buildBottomAction(
          label: tr('Μετάβαση στον πίνακα'),
          icon: Icons.arrow_forward,
          onTap: () {
            widget.onGymAdded?.call();
            Navigator.of(context).popUntil((r) => r.isFirst);
          },
        ),
        Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 16),
          child: Text(
            tr('Δεν είναι δική σου συνδρομή; Επικοινώνησε με υποστήριξη'),
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: _kGray, fontSize: 11, height: 1.45),
          ),
        ),
      ],
    );
  }

  // ── Κοινά UI ──────────────────────────────────────────────────────────────────

  Widget _buildHeader({
    required String title,
    bool showBack = true,
    VoidCallback? onPop,
  }) {
    return SizedBox(
      height: 56,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Row(
          children: [
            if (showBack)
              GestureDetector(
                onTap: onPop ?? () => Navigator.of(context).maybePop(),
                child: const Padding(
                  padding: EdgeInsets.only(right: 12),
                  child: Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: _kText,
                    size: 20,
                  ),
                ),
              ),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomAction({
    required String label,
    required IconData icon,
    required VoidCallback? onTap,
    bool enabled = true,
    bool loading = false,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
      child: _ActionButton(
        label: label,
        icon: icon,
        onTap: enabled ? onTap : null,
        loading: loading,
      ),
    );
  }
}

// ── Κοινά widgets ──────────────────────────────────────────────────────────────

class _PageIntro extends StatelessWidget {
  const _PageIntro({
    required this.eyebrow,
    required this.title,
    required this.body,
  });
  final String eyebrow;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          eyebrow,
          style: GoogleFonts.inter(
            color: _kAccent,
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          title,
          style: GoogleFonts.inter(
            color: _kText,
            fontSize: 30,
            fontWeight: FontWeight.w800,
            height: 1.1,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          body,
          style: GoogleFonts.inter(
            color: _kGray, fontSize: 14, height: 1.45),
        ),
      ],
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1F2B),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: GoogleFonts.inter(color: _kGray, fontSize: 10)),
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? _kGuideBg : _kCard,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? _kAccent : _kBorder,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: selected ? _kAccent : _kGray, size: 24),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      color: _kText,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.45,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      color: _kGray, fontSize: 12, height: 1.45),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Container(
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: selected ? _kAccent : Colors.transparent,
                border: Border.all(
                  color: selected ? _kAccent : _kBorder,
                  width: 1.5,
                ),
              ),
              alignment: Alignment.center,
              child: selected
                  ? const Icon(Icons.check_rounded, color: _kBg, size: 13)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidanceBox extends StatelessWidget {
  const _GuidanceBox({
    required this.icon,
    required this.text,
    this.iconColor = _kGray,
    this.bgColor = _kGuideBg,
    this.textColor = _kGray,
  });
  final IconData icon;
  final String text;
  final Color iconColor;
  final Color bgColor;
  final Color textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: bgColor, borderRadius: BorderRadius.circular(12)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: GoogleFonts.inter(
                color: textColor, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }
}

class _InputGroup extends StatelessWidget {
  const _InputGroup({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _kGray,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          alignment: Alignment.centerLeft,
          child: Text(
            value.isEmpty ? ' ' : value,
            style: GoogleFonts.inter(
              color: _kText, fontSize: 15, height: 1.45),
          ),
        ),
      ],
    );
  }
}

class _InputGroupWithSuffix extends StatelessWidget {
  const _InputGroupWithSuffix({
    required this.label,
    required this.value,
    this.suffix,
  });
  final String label;
  final String value;
  final Widget? suffix;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: _kGray,
            fontSize: 12,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: _kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _kBorder),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value.isEmpty ? ' ' : value,
                  style: GoogleFonts.inter(
                    color: _kText, fontSize: 15, height: 1.45),
                ),
              ),
              if (suffix != null) suffix!,
            ],
          ),
        ),
      ],
    );
  }
}

class _GymSummaryCard extends StatelessWidget {
  const _GymSummaryCard({
    required this.gymName,
    required this.gymCity,
    required this.roleLabel,
  });
  final String gymName;
  final String gymCity;
  final String roleLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: _kIconBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                alignment: Alignment.center,
                child: const Icon(
                  Icons.show_chart_rounded,
                  color: _kAccent,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      gymName,
                      style: GoogleFonts.inter(
                        color: _kText,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.45,
                      ),
                    ),
                    if (gymCity.isNotEmpty)
                      Text(
                        gymCity,
                        style: GoogleFonts.inter(
                          color: _kGray, fontSize: 12, height: 1.45),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  tr('Ζητούμενος ρόλος'),
                  style: GoogleFonts.inter(
                    color: _kGray, fontSize: 12, height: 1.45),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8, vertical: 5),
                decoration: BoxDecoration(
                  color: _kGuideBg,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  roleLabel,
                  style: GoogleFonts.inter(color: _kAccent, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            tr('Αυτός ο ρόλος ισχύει μόνο για το $gymName. Τα άλλα γυμναστήριά σου παραμένουν αμετάβλητα.'),
            style: GoogleFonts.inter(
              color: _kGray, fontSize: 12, height: 1.45),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: _kIconBg, borderRadius: BorderRadius.circular(10)),
          alignment: Alignment.center,
          child: Icon(icon, color: _kAccent, size: 19),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.inter(
                  color: _kText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.45,
                ),
              ),
              Text(
                body,
                style: GoogleFonts.inter(
                  color: _kGray, fontSize: 12, height: 1.45),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
  });
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: active ? _kPrimary : _kCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: active ? _kPrimary : _kBorder),
        ),
        child: loading
            ? const Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
                ),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.inter(
                      color: active ? _kText : _kGray,
                      fontSize: 14,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    icon,
                    color: active ? _kText : _kGray,
                    size: 18,
                  ),
                ],
              ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  const _OutlineButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1F2B),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _kBorder),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                color: _kText, fontSize: 14, height: 1.45),
            ),
            const SizedBox(width: 8),
            Icon(icon, color: _kText, size: 18),
          ],
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1414),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.redAccent, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(message),
              style: GoogleFonts.inter(
                color: Colors.redAccent, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
