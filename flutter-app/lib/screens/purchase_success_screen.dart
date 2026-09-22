import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../widgets/omni_design.dart';

class PurchaseSuccessScreen extends StatelessWidget {
  const PurchaseSuccessScreen({super.key,
    this.gymName = 'Fitness Club Athens',
    this.itemPurchased = '10 Class Pack',
    this.amount = '€90.00',
    this.cardLast4 = '4242',
    this.date = 'Today, 14:20',
    this.transactionId = 'TXN-8827-4F2C-91AE',
  });

  final String gymName;
  final String itemPurchased;
  final String amount;
  final String cardLast4;
  final String date;
  final String transactionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Lime top radial glow
          Positioned(
            left: 0, top: 0,
            child: Container(
              width: 375, height: 420,
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.topCenter,
                  radius: 1.0,
                  colors: [
                    kLime.withValues(alpha: 0.10),
                    kLime.withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.45, 0.7],
                ),
              ),
            ),
          ),
          // Cyan bottom-right glow
          Positioned(
            right: -64, bottom: 0,
            child: Container(
              width: 320, height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [kCyan.withValues(alpha: 0.08), Colors.transparent],
                  stops: const [0.0, 0.7],
                ),
              ),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 40),
              child: Column(
                children: [
                  // OmniPlex logo
                  _buildLogo(),
                  const SizedBox(height: 32),
                  // Success hero
                  _buildSuccessHero(),
                  const SizedBox(height: 28),
                  // Receipt card
                  _buildReceiptCard(),
                  const SizedBox(height: 24),
                  // CTA button
                  _buildViewMembershipButton(),
                  const SizedBox(height: 16),
                  // Back to home
                  GestureDetector(
                    child: Text('Back to Home', style: GoogleFonts.manrope(
                      fontSize: 14, fontWeight: FontWeight.w700,
                      color: kGray)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: const Color(0xFF1F2024),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: kBorder),
          ),
          child: const Icon(Icons.bolt, color: kLime, size: 14),
        ),
        const SizedBox(width: 8),
        Text('OMNIPLEX', style: GoogleFonts.spaceGrotesk(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: 1.4)),
      ],
    );
  }

  Widget _buildSuccessHero() {
    return Column(
      children: [
        // Concentric ring + check circle
        SizedBox(
          width: 144, height: 144,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Outer radial glow
              Container(
                width: 144, height: 144,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      kLime.withValues(alpha: 0.35),
                      kLime.withValues(alpha: 0.12),
                      kLime.withValues(alpha: 0.0),
                    ],
                    stops: const [0.0, 0.45, 0.75],
                  ),
                ),
              ),
              // Outer ring
              Container(
                width: 112, height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kLime.withValues(alpha: 0.20), width: 1),
                ),
              ),
              // Inner ring
              Container(
                width: 72, height: 72,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: kLime.withValues(alpha: 0.30), width: 1),
                ),
              ),
              // Check circle
              Container(
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: const Color(0xFF1D2410),
                  shape: BoxShape.circle,
                  border: Border.all(color: kLime, width: 2),
                  boxShadow: [
                    BoxShadow(color: kLime.withValues(alpha: 0.55), blurRadius: 30, spreadRadius: 6),
                    BoxShadow(color: kLime.withValues(alpha: 0.25), blurRadius: 60, spreadRadius: 12),
                  ],
                ),
                child: const Icon(Icons.check, color: kLime, size: 32),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text("You're all set!", style: GoogleFonts.spaceGrotesk(
          fontSize: 24, fontWeight: FontWeight.w700,
          color: Colors.white, letterSpacing: -0.6)),
        const SizedBox(height: 8),
        Text('Your purchase was completed successfully.', style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
      ],
    );
  }

  Widget _buildReceiptCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: kCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: kBorder),
      ),
      child: Column(
        children: [
          // Gym header row
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1F2024),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: kBorder),
                  ),
                  child: const Icon(Icons.fitness_center, color: kGray, size: 18),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(gymName, style: GoogleFonts.manrope(
                        fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                      const SizedBox(height: 3),
                      Text('Membership Provider', style: GoogleFonts.manrope(
                        fontSize: 12, fontWeight: FontWeight.w600, color: kGray)),
                    ],
                  ),
                ),
                Container(
                  width: 32, height: 32,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1D2410),
                    shape: BoxShape.circle,
                    border: Border.all(color: kLime),
                  ),
                  child: const Icon(Icons.check, color: kLime, size: 14),
                ),
              ],
            ),
          ),
          const Divider(color: kBorder, thickness: 1, height: 1),
          const SizedBox(height: 12),
          // Row data
          _buildRow('Item Purchased', null, itemPurchased, Colors.white),
          const SizedBox(height: 12),
          _buildRow('Amount', null, amount, kLime),
          const SizedBox(height: 12),
          // Payment method row with card icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Payment Method', style: GoogleFonts.manrope(
                fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
              Row(
                children: [
                  Container(
                    width: 28, height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A54A3),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Center(
                      child: Text('VISA', style: GoogleFonts.spaceGrotesk(
                        fontSize: 7, fontWeight: FontWeight.w700,
                        color: Colors.white, letterSpacing: 0.5)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('•••• $cardLast4', style: GoogleFonts.manrope(
                    fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildRow('Date', null, date, Colors.white),
          const SizedBox(height: 12),
          const Divider(color: kBorder, thickness: 1, height: 1),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Transaction ID: $transactionId', style: GoogleFonts.manrope(
              fontSize: 12, fontWeight: FontWeight.w600,
              color: kDim, letterSpacing: 0.3)),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, IconData? icon, String value, Color valueColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.manrope(
          fontSize: 14, fontWeight: FontWeight.w600, color: kGray)),
        Text(value, style: value == amount
          ? GoogleFonts.spaceGrotesk(
              fontSize: 16, fontWeight: FontWeight.w700, color: valueColor)
          : GoogleFonts.manrope(
              fontSize: 14, fontWeight: FontWeight.w700, color: valueColor)),
      ],
    );
  }

  Widget _buildViewMembershipButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        color: kLime,
        borderRadius: BorderRadius.circular(9999),
        boxShadow: [
          BoxShadow(color: kLime.withValues(alpha: 0.45), blurRadius: 24, spreadRadius: 4),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('View Membership', style: GoogleFonts.spaceGrotesk(
            fontSize: 16, fontWeight: FontWeight.w700,
            color: Colors.black, letterSpacing: 0.05)),
          const SizedBox(width: 8),
          const Icon(Icons.arrow_forward, color: Colors.black, size: 16),
        ],
      ),
    );
  }
}
