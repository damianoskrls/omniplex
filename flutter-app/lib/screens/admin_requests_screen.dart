import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../widgets/omni_design.dart';
import '../services/auth_service.dart';

const _kAmber = Color(0xFFFFB93D);
const _kAmberBg = Color(0xFF2A210F);
const _kRed = Color(0xFFFF5D5D);
const _kRedBg = Color(0xFF2A1414);
const _kPurple = Color(0xFFB57BFF);
const _kPurpleBg = Color(0xFF20142F);

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  int _tabIndex = 0; // 0=Membership, 1=Staff
  bool _loadingData = true;
  List<Map<String, dynamic>> _pendingClients = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadPending());
  }

  Future<void> _loadPending() async {
    try {
      final api = context.read<AuthService>().api;
      final raw = await api.fetchAdminPendingClients();
      if (mounted) {
        setState(() {
          _pendingClients = raw.cast<Map<String, dynamic>>();
          _loadingData = false;
        });
      }
    } catch (_) {
      if (mounted) { setState(() => _loadingData = false); }
    }
  }

  Future<void> _approve(String userId) async {
    try {
      final api = context.read<AuthService>().api;
      await api.approveAdminClient(userId);
      setState(() => _pendingClients.removeWhere((c) => c['id'] == userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  Future<void> _reject(String userId) async {
    try {
      final api = context.read<AuthService>().api;
      await api.rejectAdminClient(userId);
      setState(() => _pendingClients.removeWhere((c) => c['id'] == userId));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
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
                                  Text('Requests', style: GoogleFonts.spaceGrotesk(
                                    fontSize: 20, fontWeight: FontWeight.w700,
                                    color: Colors.white, letterSpacing: -0.5)),
                                ],
                              ),
                              Stack(
                                children: [
                                  Container(
                                    width: 44, height: 44,
                                    decoration: BoxDecoration(
                                      color: kCard,
                                      shape: BoxShape.circle,
                                      border: Border.all(color: kBorder),
                                    ),
                                    child: const Icon(Icons.inbox_outlined, color: Colors.white, size: 16),
                                  ),
                                  Positioned(
                                    top: 8, right: 10,
                                    child: Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        color: _kAmber,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(color: _kAmber.withValues(alpha: 0.90), blurRadius: 8),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Tab filter
                        Padding(
                          padding: const EdgeInsets.only(bottom: 28),
                          child: Row(
                            children: [
                              _buildTabChip('Membership\nRequests', 2, 0),
                              const SizedBox(width: 10),
                              _buildTabChip('Staff\nRequests', 1, 1),
                            ],
                          ),
                        ),
                        // Membership Requests section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Membership Requests', style: GoogleFonts.spaceGrotesk(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: -0.4)),
                            Text('2 pending', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Membership request cards
                        if (_loadingData)
                          const Center(child: CircularProgressIndicator(color: kLime))
                        else if (_pendingClients.isEmpty)
                          Center(child: Text('No pending requests', style: GoogleFonts.manrope(
                            fontSize: 14, color: kGray)))
                        else
                          ...List.generate(_pendingClients.length, (i) {
                            final c = _pendingClients[i];
                            return Padding(
                              padding: EdgeInsets.only(bottom: i < _pendingClients.length - 1 ? 12 : 0),
                              child: _buildMembershipCard(
                                name: c['full_name'] as String? ?? '',
                                description: c['email'] as String? ?? 'Pending registration',
                                timeAgo: c['created_at'] as String? ?? '',
                                userId: c['id'] as String?,
                              ),
                            );
                          }),
                        const SizedBox(height: 32),
                        // Divider with label
                        Row(
                          children: [
                            Expanded(child: Container(height: 1, color: kBorder)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12),
                              child: Text('OTHER CATEGORY', style: GoogleFonts.manrope(
                                fontSize: 10, fontWeight: FontWeight.w700,
                                color: kDim, letterSpacing: 0.25)),
                            ),
                            Expanded(child: Container(height: 1, color: kBorder)),
                          ],
                        ),
                        const SizedBox(height: 24),
                        // Staff Requests section
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Staff Requests', style: GoogleFonts.spaceGrotesk(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: Colors.white, letterSpacing: -0.4)),
                            Text('1 pending', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildStaffRequestCard(
                          name: 'Maria Papadopoulou',
                          description: 'Requesting to join as CrossFit Coach',
                          timeAgo: '1 day ago',
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

  Widget _buildTabChip(String label, int count, int index) {
    final active = _tabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _tabIndex = index),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: active ? kLime : kCard,
          borderRadius: BorderRadius.circular(9999),
          border: active ? null : Border.all(color: kBorder),
        ),
        child: Row(
          children: [
            Text(label.replaceAll('\n', ' '), style: active
              ? GoogleFonts.spaceGrotesk(
                  fontSize: 12, fontWeight: FontWeight.w700, color: kBg)
              : GoogleFonts.manrope(
                  fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
            const SizedBox(width: 8),
            Container(
              width: 20, height: 20,
              decoration: BoxDecoration(
                color: active ? kBg : const Color(0xFF1F2024),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('$count', style: GoogleFonts.manrope(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: active ? kLime : kGray)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipCard({
    required String name,
    required String description,
    required String timeAgo,
    String? userId,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kAmber, width: 2),
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFF2A2B30),
                    child: const Icon(Icons.person, color: _kAmber, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(name, style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kAmberBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: _kAmber.withValues(alpha: 0.40)),
                          ),
                          child: Text('Pending', style: GoogleFonts.spaceGrotesk(
                            fontSize: 10, fontWeight: FontWeight.w700, color: _kAmber)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(description, style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Verified badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFF1F2024),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: kBorder2),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.verified_outlined, color: kLime, size: 10),
                const SizedBox(width: 6),
                Text('Verified via Membership ID', style: GoogleFonts.manrope(
                  fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          // Time ago
          Row(
            children: [
              const Icon(Icons.schedule_outlined, color: kGray, size: 10),
              const SizedBox(width: 6),
              Text(timeAgo, style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
            ],
          ),
          // Action buttons
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: userId != null ? () => _approve(userId) : null,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: kLime,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.check, color: kBg, size: 12),
                            const SizedBox(width: 8),
                            Text('Approve', style: GoogleFonts.spaceGrotesk(
                              fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: userId != null ? () => _reject(userId) : null,
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _kRedBg,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _kRed.withValues(alpha: 0.40)),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.close, color: _kRed, size: 12),
                            const SizedBox(width: 8),
                            Text('Reject', style: GoogleFonts.manrope(
                              fontSize: 12, fontWeight: FontWeight.w600, color: _kRed)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStaffRequestCard({
    required String name,
    required String description,
    required String timeAgo,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _kPurple, width: 2),
                ),
                child: ClipOval(
                  child: Container(
                    color: const Color(0xFF2A2B30),
                    child: const Icon(Icons.person, color: _kPurple, size: 24),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Flexible(
                          child: Text(name, style: GoogleFonts.manrope(
                            fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _kPurpleBg,
                            borderRadius: BorderRadius.circular(9999),
                            border: Border.all(color: _kPurple.withValues(alpha: 0.40)),
                          ),
                          child: Text('Staff', style: GoogleFonts.spaceGrotesk(
                            fontSize: 10, fontWeight: FontWeight.w700, color: _kPurple)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(description, style: GoogleFonts.manrope(
                      fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.schedule_outlined, color: kGray, size: 10),
              const SizedBox(width: 6),
              Text(timeAgo, style: GoogleFonts.manrope(
                fontSize: 11, fontWeight: FontWeight.w600, color: kGray)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Container(
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: kBorder)),
              ),
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: kLime,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check, color: kBg, size: 12),
                          const SizedBox(width: 8),
                          Text('Approve', style: GoogleFonts.spaceGrotesk(
                            fontSize: 12, fontWeight: FontWeight.w700, color: kBg)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Container(
                      height: 44,
                      decoration: BoxDecoration(
                        color: _kRedBg,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: _kRed.withValues(alpha: 0.40)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.close, color: _kRed, size: 12),
                          const SizedBox(width: 8),
                          Text('Reject', style: GoogleFonts.manrope(
                            fontSize: 12, fontWeight: FontWeight.w600, color: _kRed)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

}
