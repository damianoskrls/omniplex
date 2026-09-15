import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import 'workout_complete_screen.dart';

class QrCheckinScreen extends StatefulWidget {
  const QrCheckinScreen({super.key});

  @override
  State<QrCheckinScreen> createState() => _QrCheckinScreenState();
}

class _QrCheckinScreenState extends State<QrCheckinScreen> {
  bool _processing = false;
  bool _done = false;
  bool _success = false;
  Map<String, dynamic>? _result;
  String? _errorMessage;
  Map<String, dynamic>? _errorBooking;
  final MobileScannerController _ctrl = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
    facing: CameraFacing.back,
  );

  bool get _canUseDeviceCamera {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isAndroid;
  }

  @override
  void initState() {
    super.initState();
    if (_canUseDeviceCamera) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _ctrl.start());
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _doCheckin(String bizId, String bookingId) async {
    final api = context.read<AuthService>().api;
    setState(() => _processing = true);

    try {
      final result = await api.qrCheckIn(bizId, bookingId: bookingId);
      setState(() {
        _done = true;
        _success = true;
        _result = result;
        _errorBooking = null;
        _processing = false;
      });
      Future.delayed(const Duration(seconds: 5), () {
        if (mounted) _reset();
      });
    } on ApiException catch (e) {
      setState(() {
        _done = true;
        _success = false;
        _errorMessage = e.message;
        _errorBooking = _bookingFromPayload(e.payload);
        _processing = false;
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _reset();
      });
    } catch (e) {
      setState(() {
        _done = true;
        _success = false;
        _errorMessage = _extractError(e.toString());
        _errorBooking = null;
        _processing = false;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _reset();
      });
    }
  }

  Map<String, dynamic>? _bookingFromPayload(Map<String, dynamic>? payload) {
    final raw = payload?['booking'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  Future<void> _handleQrScan(String bizId) async {
    final api = context.read<AuthService>().api;
    setState(() => _processing = true);

    try {
      final options = await api.fetchQrCheckinOptions(bizId);
      if (!mounted) return;
      setState(() => _processing = false);

      final bookingId = await _pickBookingForCheckin(options);
      if (!mounted || bookingId == null) {
        await _ctrl.start();
        return;
      }

      await _doCheckin(bizId, bookingId);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _done = true;
        _success = false;
        _errorMessage = e.message;
        _errorBooking = _bookingFromPayload(e.payload);
        _processing = false;
      });
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _reset();
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _done = true;
        _success = false;
        _errorMessage = _extractError(e.toString());
        _errorBooking = null;
        _processing = false;
      });
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) _reset();
      });
    }
  }

  Future<String?> _pickBookingForCheckin(List<Map<String, dynamic>> options) async {
    if (options.isEmpty) return null;
    if (options.length == 1) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: const Color(0xFF1A1A1A),
          title: const Text('Επιβεβαίωση check-in', style: TextStyle(color: Colors.white)),
          content: _BookingCheckinCard(booking: options.first),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Ακύρωση')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.greenAccent, foregroundColor: Colors.black),
              child: const Text('Check-in'),
            ),
          ],
        ),
      );
      return confirmed == true ? options.first['id'] as String? : null;
    }

    return showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Επέλεξε κράτηση',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Έχεις περισσότερα από ένα μάθημα διαθέσιμο για check-in τώρα.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 16),
                ...options.map((booking) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: InkWell(
                      onTap: () => Navigator.pop(ctx, booking['id'] as String?),
                      borderRadius: BorderRadius.circular(14),
                      child: _BookingCheckinCard(booking: booking, compact: false),
                    ),
                  );
                }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _simulateCheckin() async {
    final api = context.read<AuthService>().api;
    await _handleQrScan(api.bizId);
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_processing || _done) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;

    Map<String, dynamic> payload;
    try {
      payload = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return;
    }

    if (payload['action'] != 'checkin' || payload['bizId'] == null) return;

    await _ctrl.stop();
    await _handleQrScan(payload['bizId'] as String);
  }

  String _extractError(String raw) {
    try {
      final m = RegExp(r'\{.*\}').firstMatch(raw);
      if (m != null) {
        final body = jsonDecode(m.group(0)!) as Map;
        return body['error'] as String? ?? 'Σφάλμα check-in';
      }
    } catch (_) {}
    return 'Σφάλμα. Προσπάθησε ξανά.';
  }

  void _reset() {
    setState(() {
      _done = false;
      _success = false;
      _result = null;
      _errorMessage = null;
      _errorBooking = null;
      _processing = false;
    });
    _ctrl.start();
  }

  Future<void> _openManualConfirm() async {
    final raw = _errorBooking;
    final bookingId = raw?['id']?.toString();
    if (bookingId == null) return;
    final api = context.read<AuthService>().api;
    try {
      final booking = await api.fetchBookingDetail(bookingId);
      if (!mounted) return;
      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => WorkoutCompleteScreen(booking: booking, api: api),
        ),
      );
      if (mounted) _reset();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        title: const Text('Check-in με QR'),
      ),
      body: _done ? _buildResult() : _buildScanner(),
    );
  }

  Widget _buildScanner() {
    if (!_canUseDeviceCamera) return _buildDebugScanner();

    return Stack(
      fit: StackFit.expand,
      children: [
        MobileScanner(
          controller: _ctrl,
          onDetect: _onDetect,
          errorBuilder: (context, error, child) => _buildDebugScanner(
            subtitle: error.errorDetails?.message ?? 'Η κάμερα δεν είναι διαθέσιμη',
          ),
        ),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.greenAccent, width: 3),
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
        if (_processing)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: Colors.greenAccent),
            ),
          ),
        const Positioned(
          bottom: 40,
          left: 0,
          right: 0,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 24),
            child: Text(
              'Σκανάρετε το QR του γυμναστηρίου.\nΘα επιλέξετε για ποια κράτηση κάνετε check-in.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 15, height: 1.4),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDebugScanner({String? subtitle}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.greenAccent, width: 3),
                borderRadius: BorderRadius.circular(16),
                color: Colors.white10,
              ),
              child: const Icon(Icons.qr_code_scanner, size: 80, color: Colors.white24),
            ),
            const SizedBox(height: 24),
            Text(
              subtitle ?? 'Κάμερα μη διαθέσιμη σε αυτή τη συσκευή',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54, fontSize: 14),
            ),
            if (kDebugMode) ...[
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _processing ? null : _simulateCheckin,
                icon: _processing
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : const Icon(Icons.bug_report, size: 18),
                label: Text(_processing ? 'Γίνεται check-in...' : 'Simulate Scan (debug)'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildResult() {
    if (!_success) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.cancel_rounded, color: Colors.redAccent, size: 80),
              const SizedBox(height: 24),
              Text(
                _errorMessage ?? 'Σφάλμα.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 20, height: 1.5),
              ),
              if (_errorBooking != null) ...[
                const SizedBox(height: 20),
                _BookingCheckinCard(booking: _errorBooking!),
              ],
              if (_errorBooking?['id'] != null) ...[
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _openManualConfirm,
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.greenAccent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                  ),
                  child: const Text('Επιβεβαίωση χειροκίνητα'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _reset,
                  child: const Text('Δοκίμασε ξανά', style: TextStyle(color: Colors.white70)),
                ),
              ],
            ],
          ),
        ),
      );
    }

    final r = _result!;
    final booking = r['booking'] as Map<String, dynamic>?;
    final isUnlimited = r['isUnlimited'] == true;
    final remaining = r['remaining'] as int?;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_rounded, color: Colors.greenAccent, size: 80),
            const SizedBox(height: 20),
            Text(
              'Check-in ολοκληρώθηκε',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Καλώς ήρθες, ${r['userName'] ?? ''}!',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 16),
            ),
            if (booking != null) ...[
              const SizedBox(height: 20),
              _BookingCheckinCard(booking: booking, highlight: true),
            ],
            const SizedBox(height: 16),
            Text(
              isUnlimited
                  ? 'Απεριόριστη συνδρομή'
                  : 'Απομένουν $remaining συνεδρίες',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white.withOpacity(0.6), fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class _BookingCheckinCard extends StatelessWidget {
  const _BookingCheckinCard({
    required this.booking,
    this.compact = true,
    this.highlight = false,
  });

  final Map<String, dynamic> booking;
  final bool compact;
  final bool highlight;

  String? _formatWhen() {
    final starts = DateTime.tryParse(booking['startsAt']?.toString() ?? '')?.toLocal();
    if (starts == null) return null;
    final ends = DateTime.tryParse(booking['endsAt']?.toString() ?? '')?.toLocal();
    final date = DateFormat('EEE dd/MM', 'el_GR').format(starts);
    final startTime = DateFormat('HH:mm').format(starts);
    if (ends != null) {
      final endTime = DateFormat('HH:mm').format(ends);
      return '$date · $startTime–$endTime';
    }
    return '$date · $startTime';
  }

  @override
  Widget build(BuildContext context) {
    final serviceName = booking['serviceName']?.toString() ?? 'Μάθημα';
    final scheduleLabel = booking['scheduleLabel']?.toString();
    final staffName = booking['staffName']?.toString();
    final roomName = booking['roomName']?.toString();
    final when = _formatWhen();
    final showProgram = scheduleLabel != null
        && scheduleLabel.isNotEmpty
        && scheduleLabel != serviceName;

    final borderColor = highlight ? Colors.greenAccent.withOpacity(0.5) : Colors.white24;
    final bgColor = highlight ? Colors.greenAccent.withOpacity(0.12) : Colors.white10;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 14 : 16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            serviceName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (showProgram) ...[
            const SizedBox(height: 6),
            Text(
              'Πρόγραμμα: $scheduleLabel',
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
          if (when != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.schedule, size: 16, color: Colors.greenAccent),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    when,
                    style: const TextStyle(color: Colors.greenAccent, fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
          if (staffName != null && staffName.isNotEmpty) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.person_outline, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Προπονητής: $staffName',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
          if (roomName != null && roomName.isNotEmpty) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.meeting_room_outlined, size: 16, color: Colors.white54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    roomName,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
