import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/omni_design.dart';
import '../services/auth_service.dart';

const _kAmber = Color(0xFFFFB93D);
const _kAmberBg = Color(0xFF2A210F);
const _kRed = Color(0xFFFF5D5D);
const _kRedBg = Color(0xFF2A1414);

class AdminMembersScreen extends StatefulWidget {
  const AdminMembersScreen({super.key});

  @override
  State<AdminMembersScreen> createState() => _AdminMembersScreenState();
}

class _AdminMembersScreenState extends State<AdminMembersScreen> {
  int _filterIndex = 0; // 0=Active, 1=Expired, 2=Pending
  bool _loadingData = true;
  List<_MemberData> _members = [];

  static const _statusKeys = ['active', 'expired', 'pending'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthService>().api;
      final status = _statusKeys[_filterIndex];
      final raw = await api.fetchAdminClients(status: status);
      final list = raw.map((c) {
        final credits = c['credits'] as List? ?? [];
        final pkg = credits.isNotEmpty
            ? (credits.first['service_name'] as String? ?? 'No Package')
            : 'No Package';
        final acctStatus = c['account_status'] as String? ?? 'active';
        return _MemberData(
          name: c['full_name'] as String? ?? '',
          package: pkg,
          lastVisit: c['last_visit'] as String? ?? '—',
          status: acctStatus == 'active' ? 'Active'
              : acctStatus == 'expired' ? 'Expired'
              : 'Pending',
        );
      }).toList();
      if (mounted) setState(() { _members = list; _loadingData = false; });
    } catch (_) {
      if (mounted) setState(() => _loadingData = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          // Top lime glow
          Positioned(
            left: 0, top: 0,
            child: Container(
              width: 375, height: 256,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    kLime.withValues(alpha: 0.10),
                    kLime.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.35, 0.60],
                ),
              ),
            ),
          ),
          // Bottom-right cyan glow
          Positioned(
            right: 0, top: 384,
            child: Container(
              width: 160, height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    kCyan.withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.70],
                ),
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 56, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 24),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Admin Dashboard', style: GoogleFonts.manrope(
                                    fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                                  const SizedBox(height: 4),
                                  Text('Members', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 20, fontWeight: FontWeight.w700,
                                    color: Colors.white, letterSpacing: -0.5)),
                                ],
                              ),
                              Container(
                                width: 44, height: 44,
                                decoration: BoxDecoration(
                                  color: kCard,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: kBorder),
                                ),
                                child: const Icon(Icons.person_add_outlined, color: Colors.white, size: 18),
                              ),
                            ],
                          ),
                        ),
                        // Search bar
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Container(
                            height: 48,
                            decoration: BoxDecoration(
                              color: kCard,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: kBorder),
                            ),
                            child: Row(
                              children: [
                                const SizedBox(width: 16),
                                const Icon(Icons.search, color: kGray, size: 14),
                                const SizedBox(width: 12),
                                Text('Search members', style: GoogleFonts.manrope(
                                  fontSize: 14, color: kGray)),
                              ],
                            ),
                          ),
                        ),
                        // Filter tabs
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Row(
                            children: [
                              _buildFilterChip('Active', 0),
                              const SizedBox(width: 10),
                              _buildFilterChip('Expired', 1),
                              const SizedBox(width: 10),
                              _buildFilterChip('Pending', 2),
                            ],
                          ),
                        ),
                        // Members list header
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('All Members', style: GoogleFonts.spaceGrotesk(
                                fontSize: 16, fontWeight: FontWeight.w700,
                                color: Colors.white, letterSpacing: -0.4)),
                              Text('128 total', style: GoogleFonts.manrope(
                                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                            ],
                          ),
                        ),
                        // Member cards
                        if (_loadingData)
                          const Center(child: Padding(
                            padding: EdgeInsets.all(32),
                            child: CircularProgressIndicator(color: kLime),
                          ))
                        else
                          Column(
                            children: _members.asMap().entries.map((e) => Padding(
                              padding: EdgeInsets.only(bottom: e.key < _members.length - 1 ? 12 : 0),
                              child: _buildMemberCard(e.value),
                            )).toList(),
                          ),
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int index) {
    final active = _filterIndex == index;
    return GestureDetector(
      onTap: () { setState(() { _filterIndex = index; _loadingData = true; }); _load(); },
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? kLime : kCard,
          borderRadius: BorderRadius.circular(9999),
          border: active ? null : Border.all(color: kBorder),
        ),
        child: Center(
          child: Text(label, style: active
            ? GoogleFonts.spaceGrotesk(
                fontSize: 12, fontWeight: FontWeight.w700, color: kBg)
            : GoogleFonts.manrope(
                fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
        ),
      ),
    );
  }

  Widget _buildMemberCard(_MemberData member) {
    final isActive = member.status == 'Active';
    final isPending = member.status == 'Pending';

    Color avatarBorderColor;
    Color statusBg;
    Color statusBorderColor;
    Color statusTextColor;

    if (isActive) {
      avatarBorderColor = kLime;
      statusBg = const Color(0xFF1D2410);
      statusBorderColor = kLime.withValues(alpha: 0.40);
      statusTextColor = kLime;
    } else if (isPending) {
      avatarBorderColor = _kAmber;
      statusBg = _kAmberBg;
      statusBorderColor = _kAmber.withValues(alpha: 0.40);
      statusTextColor = _kAmber;
    } else {
      avatarBorderColor = kBorder2;
      statusBg = const Color(0xFF1F2024);
      statusBorderColor = kBorder2;
      statusTextColor = kGray;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar circle
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: avatarBorderColor, width: 2),
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFF2A2B30),
                    child: Icon(
                      isActive ? Icons.person : isPending ? Icons.person_outline : Icons.person_off_outlined,
                      color: isActive ? kLime : isPending ? _kAmber : kGray,
                      size: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Member info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(member.name, style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        const SizedBox(width: 8),
                        // Status badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: statusBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: statusBorderColor),
                          ),
                          child: Text(member.status, style: GoogleFonts.spaceGrotesk(
                            fontSize: 10, fontWeight: FontWeight.w700,
                            color: statusTextColor)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(member.package, style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    const SizedBox(height: 2),
                    Text(member.lastVisit, style: GoogleFonts.manrope(
                      fontSize: 11, fontWeight: FontWeight.w600, color: kDim)),
                  ],
                ),
              ),
            ],
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(child: _buildActionButton(
                    icon: Icons.visibility_outlined,
                    label: 'View',
                    bg: const Color(0xFF1F2024),
                    borderColor: kBorder2,
                    textColor: Colors.white,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionButton(
                    icon: Icons.edit_outlined,
                    label: 'Edit',
                    bg: const Color(0xFF1F2024),
                    borderColor: kBorder2,
                    textColor: Colors.white,
                  )),
                  const SizedBox(width: 10),
                  Expanded(child: _buildActionButton(
                    icon: Icons.power_settings_new,
                    label: 'Deactivate',
                    bg: _kRedBg,
                    borderColor: _kRed.withValues(alpha: 0.30),
                    textColor: _kRed,
                  )),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color bg,
    required Color borderColor,
    required Color textColor,
  }) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: textColor, size: 12),
          const SizedBox(width: 6),
          Text(label, style: GoogleFonts.manrope(
            fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }

}

class _MemberData {
  final String name;
  final String package;
  final String lastVisit;
  final String status;

  const _MemberData({
    required this.name,
    required this.package,
    required this.lastVisit,
    required this.status,
  });
}
