import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../theme/app_colors.dart';

class DropinConfirmScreen extends StatelessWidget {
  const DropinConfirmScreen({super.key, required this.booking});

  final Map<String, dynamic> booking;

  String get _serviceName => booking['service_name'] as String? ?? '';
  String get _date => booking['booking_date'] as String? ?? '';
  String get _time => (booking['booking_time'] as String? ?? '').substring(0, 5);
  String get _qrToken => booking['qr_token'] as String? ?? booking['id'] as String? ?? '';
  int get _priceCents => (booking['price_cents'] as num?)?.toInt() ?? 0;
  String get _priceStr => '${(_priceCents / 100).toStringAsFixed(2)} €';
  String get _payMethod => booking['payment_method'] as String? ?? 'venue';
  String get _payStatus => booking['payment_status'] as String? ?? 'pending';

  String _fmtDate(String iso) {
    if (iso.isEmpty) return '';
    try {
      final d = DateTime.parse(iso);
      const months = ['Ιαν','Φεβ','Μαρ','Απρ','Μαΐ','Ιουν','Ιουλ','Αυγ','Σεπ','Οκτ','Νοε','Δεκ'];
      return '${d.day} ${months[d.month - 1]} ${d.year}';
    } catch (_) { return iso; }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      // Pop all the way back to home
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    child: const Icon(Icons.close_rounded, color: AppColors.textPrimary, size: 24),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    // Success icon
                    Container(
                      width: 72, height: 72,
                      decoration: BoxDecoration(
                        color: AppColors.lime.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_circle_rounded, color: AppColors.lime, size: 40),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Κράτηση Επιβεβαιώθηκε!',
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Δείξε το QR στην υποδοχή για να μπεις',
                      style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 32),

                    // QR Code
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.lime.withValues(alpha: 0.2),
                            blurRadius: 32,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: QrImageView(
                        data: _qrToken,
                        version: QrVersions.auto,
                        size: 200,
                        backgroundColor: Colors.white,
                        eyeStyle: const QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: Colors.black,
                        ),
                        dataModuleStyle: const QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: Colors.black,
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Booking details card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _detailRow(Icons.fitness_center_rounded, 'Μάθημα', _serviceName),
                          const SizedBox(height: 12),
                          _detailRow(Icons.calendar_today_rounded, 'Ημερομηνία', _fmtDate(_date)),
                          const SizedBox(height: 12),
                          _detailRow(Icons.access_time_rounded, 'Ώρα', _time),
                          const SizedBox(height: 12),
                          _detailRow(
                            Icons.euro_rounded,
                            'Πληρωμή',
                            '$_priceStr · ${_payMethod == 'card' ? 'Κάρτα' : 'Στο χώρο'}'
                            + (_payStatus == 'paid' ? ' ✓' : _payMethod == 'venue' ? ' (εκκρεμεί)' : ''),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),
                    if (_payMethod == 'venue')
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFD97706), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Θυμήσου να πληρώσεις $_priceStr στην υποδοχή',
                                style: const TextStyle(fontSize: 13, color: Color(0xFF92400E)),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            // Bottom button
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).popUntil((route) => route.isFirst),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.lime,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  ),
                  child: const Text('Επιστροφή στην αρχή', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.lime),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
            Text(value, style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600)),
          ],
        ),
      ],
    );
  }
}
