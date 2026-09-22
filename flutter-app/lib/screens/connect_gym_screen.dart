import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class ConnectGymScreen extends StatefulWidget {
  const ConnectGymScreen({super.key});

  @override
  State<ConnectGymScreen> createState() => _ConnectGymScreenState();
}

class _ConnectGymScreenState extends State<ConnectGymScreen> {
  int _selectedMethod = 1; // Membership ID selected by default
  final _membershipIdController = TextEditingController();
  final _searchController = TextEditingController(text: 'Fitness Club Athens');

  final _methods = [
    (Icons.phone_android_outlined, 'Mobile number on file',
      "We'll send an SMS code to verify."),
    (Icons.badge_outlined, 'Membership ID',
      'Enter the ID printed on your gym card.'),
    (Icons.key_outlined, 'Gym-provided code',
      'Ask your front desk for a linking code.'),
    (Icons.check_circle_outline, 'Request gym approval',
      'Staff manually approves your request.'),
  ];

  @override
  void dispose() {
    _membershipIdController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTopBar(context),
                const SizedBox(height: 24),
                _buildHeading(),
                const SizedBox(height: 24),
                _buildSearchBox(),
                const SizedBox(height: 20),
                _buildGymResult(),
                const SizedBox(height: 24),
                _buildVerificationSection(),
                const SizedBox(height: 32),
                _buildMembershipIdInput(),
                const SizedBox(height: 24),
                _buildStatusReference(),
                const SizedBox(height: 16),
                _buildInfoNote(),
              ],
            ),
          ),
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: _buildBottomBar(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GestureDetector(
          onTap: () => Navigator.maybePop(context),
          child: Container(
            width: 44, height: 44,
            decoration: BoxDecoration(
              color: kCard, shape: BoxShape.circle,
              border: Border.all(color: kBorder)),
            child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
          ),
        ),
        Row(
          children: [
            Container(
              width: 24, height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: kLime, width: 2),
              ),
              child: Center(
                child: Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    color: kLime, shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: kLime.withValues(alpha: 0.9), blurRadius: 10)
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: 'OMNI', style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                  TextSpan(text: 'PLEX', style: GoogleFonts.spaceGrotesk(
                    fontSize: 14, fontWeight: FontWeight.w700, color: kLime)),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(width: 44),
      ],
    );
  }

  Widget _buildHeading() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Already a member?', style: GoogleFonts.spaceGrotesk(
          fontSize: 30, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.75)),
        const SizedBox(height: 10),
        Text('Connect your existing gym to OmniPlex.',
          style: GoogleFonts.manrope(fontSize: 14, color: kGray)),
      ],
    );
  }

  Widget _buildSearchBox() {
    return Container(
      height: 56,
      padding: const EdgeInsets.only(left: 44, right: 16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Stack(
        children: [
          const Positioned(
            left: -28, top: 0, bottom: 0,
            child: Icon(Icons.search, color: kGray, size: 16),
          ),
          TextField(
            controller: _searchController,
            style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              border: InputBorder.none,
              hintText: 'Search gyms...',
              hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
              contentPadding: const EdgeInsets.only(top: 20),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGymResult() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kLime),
        boxShadow: [
          BoxShadow(color: kLime.withValues(alpha: 0.15), blurRadius: 24),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFF1D2410),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: kLime.withValues(alpha: 0.30)),
            ),
            child: const Icon(Icons.fitness_center, color: kLime, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Fitness Club Athens', style: GoogleFonts.spaceGrotesk(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: Colors.white, letterSpacing: -0.4)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.location_on_outlined, color: kGray, size: 10),
                    const SizedBox(width: 4),
                    Text('24 Syngrou Avenue, Athens 11742',
                      style: GoogleFonts.manrope(fontSize: 12, color: kGray)),
                  ],
                ),
              ],
            ),
          ),
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: kLime,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: kLime.withValues(alpha: 0.55), blurRadius: 7)
              ],
            ),
            child: const Icon(Icons.check, color: kBg, size: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Verification method', style: GoogleFonts.spaceGrotesk(
          fontSize: 18, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.45)),
        const SizedBox(height: 4),
        Text('Choose how we should confirm your membership.',
          style: GoogleFonts.manrope(fontSize: 12, color: kGray)),
        const SizedBox(height: 16),
        Column(
          children: List.generate(_methods.length, (i) {
            final active = _selectedMethod == i;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GestureDetector(
                onTap: () => setState(() => _selectedMethod = i),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: kCard,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: active ? kLime : kBorder),
                    boxShadow: active ? [
                      BoxShadow(color: kLime.withValues(alpha: 0.12), blurRadius: 12)
                    ] : null,
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44, height: 44,
                        decoration: BoxDecoration(
                          color: active
                            ? const Color(0xFF1D2410)
                            : const Color(0xFF1F2024),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: active
                              ? kLime.withValues(alpha: 0.30)
                              : kBorder2),
                        ),
                        child: Icon(_methods[i].$1,
                          color: active ? kLime : kGray, size: 18),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(_methods[i].$2, style: GoogleFonts.manrope(
                              fontSize: 14, fontWeight: FontWeight.w600,
                              color: Colors.white)),
                            const SizedBox(height: 2),
                            Text(_methods[i].$3, style: GoogleFonts.manrope(
                              fontSize: 12, color: kGray)),
                          ],
                        ),
                      ),
                      Container(
                        width: 24, height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: active ? kLime : kBorder2, width: 2),
                        ),
                        child: active
                          ? Center(
                              child: Container(
                                width: 12, height: 12,
                                decoration: BoxDecoration(
                                  color: kLime, shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: kLime.withValues(alpha: 0.7),
                                      blurRadius: 8)
                                  ],
                                ),
                              ),
                            )
                          : null,
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ],
    );
  }

  Widget _buildMembershipIdInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('ENTER MEMBERSHIP ID', style: GoogleFonts.manrope(
          fontSize: 12, fontWeight: FontWeight.w600,
          color: kGray, letterSpacing: 0.3)),
        const SizedBox(height: 8),
        Container(
          height: 56,
          padding: const EdgeInsets.only(left: 44, right: 16),
          decoration: BoxDecoration(
            color: kCard,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: kBorder),
          ),
          child: Stack(
            children: [
              const Positioned(
                left: -28, top: 0, bottom: 0,
                child: Icon(Icons.badge_outlined, color: kGray, size: 16),
              ),
              TextField(
                controller: _membershipIdController,
                style: GoogleFonts.manrope(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'e.g. FCA-208441',
                  hintStyle: GoogleFonts.manrope(fontSize: 14, color: kDim),
                  contentPadding: const EdgeInsets.only(top: 20),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatusReference() {
    final statuses = [
      ('Pending', const Color(0xFFFFB74D),
        const Color(0xFF2A2410), const Color(0xFFFFB74D)),
      ('Connected', kLime, const Color(0xFF1D2410), kLime),
      ('Rejected', const Color(0xFFFF5C5C),
        const Color(0xFF241717), const Color(0xFFFF5C5C)),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Membership status reference', style: GoogleFonts.manrope(
            fontSize: 12, color: kDim)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: statuses.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: s.$3,
                borderRadius: BorderRadius.circular(9999),
                border: Border.all(color: s.$4.withValues(alpha: 0.30)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6, height: 6,
                    decoration: BoxDecoration(
                      color: s.$2, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 8),
                  Text(s.$1, style: GoogleFonts.manrope(
                    fontSize: 12, fontWeight: FontWeight.w600, color: s.$2)),
                ],
              ),
            )).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoNote() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: kBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline, color: kDim, size: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              "Verification may take up to 24 hours depending on your gym's system.",
              style: GoogleFonts.manrope(fontSize: 12, color: kDim)),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return Container(
      decoration: BoxDecoration(
        color: kBg,
        border: const Border(top: BorderSide(color: kBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: kLime,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(color: kLime.withValues(alpha: 0.35), blurRadius: 12),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Connect My Membership', style: GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700,
              color: kBg, letterSpacing: -0.4)),
            const SizedBox(width: 8),
            const Icon(Icons.arrow_forward, color: kBg, size: 14),
          ],
        ),
      ),
    );
  }
}
