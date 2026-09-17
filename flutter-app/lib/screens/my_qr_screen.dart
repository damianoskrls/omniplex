import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';

class MyQrScreen extends StatefulWidget {
  const MyQrScreen({super.key});

  @override
  State<MyQrScreen> createState() => _MyQrScreenState();
}

class _MyQrScreenState extends State<MyQrScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await context.read<AuthService>().api.fetchMyCheckinCode();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Το QR μου')),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : _error != null
              ? Center(child: Text(_error!))
              : _QrBody(data: _data!),
    );
  }
}

class _QrBody extends StatelessWidget {
  const _QrBody({required this.data});
  final Map<String, dynamic> data;

  @override
  Widget build(BuildContext context) {
    final token      = data['token'] as String? ?? '';
    final fullName   = data['fullName'] as String? ?? '';
    final remaining  = data['remaining'];
    final isUnlimited = data['isUnlimited'] == true;
    final hasActive  = data['hasActiveMembership'] == true;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(fullName,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 22,
                    color: AppColors.textPrimary)),
            const SizedBox(height: 4),
            if (hasActive)
              Text(
                isUnlimited ? 'Απεριόριστες συνεδρίες' : 'Απομένουν $remaining συνεδρίες',
                style: TextStyle(
                  fontSize: 14,
                  color: isUnlimited ? AppColors.lime : (remaining as int) > 3
                      ? AppColors.lime : AppColors.orange,
                  fontWeight: FontWeight.w600,
                ),
              )
            else
              const Text('Δεν υπάρχει ενεργή συνδρομή',
                  style: TextStyle(fontSize: 14, color: AppColors.orange)),

            const SizedBox(height: 32),

            // QR code
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 20,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: QrImageView(
                data: token,
                version: QrVersions.auto,
                size: 220,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Color(0xFF1A1A2E),
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Color(0xFF1A1A2E),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Hint text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.qr_code_scanner, size: 16, color: AppColors.textSecondary),
                  SizedBox(width: 8),
                  Text('Δείξε το στον scanner εισόδου',
                      style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
