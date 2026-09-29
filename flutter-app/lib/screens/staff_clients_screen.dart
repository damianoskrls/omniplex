import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/omni_design.dart';

class StaffClientsScreen extends StatefulWidget {
  const StaffClientsScreen({super.key});

  @override
  State<StaffClientsScreen> createState() => _StaffClientsScreenState();
}

class _StaffClientsScreenState extends State<StaffClientsScreen> {
  List<Map<String, dynamic>> _clients = [];
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
      final rows = await context.read<AuthService>().api.fetchTrainerClients();
      if (mounted) setState(() => _clients = rows);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kBg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text('Πελάτες', style: GoogleFonts.spaceGrotesk(
                fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            Expanded(
              child: RefreshIndicator(
                color: kCyan,
                onRefresh: _load,
                child: _loading
                    ? const Center(child: CircularProgressIndicator(color: kCyan))
                    : _error != null
                        ? ListView(children: [
                            Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(_error!, style: const TextStyle(color: Colors.white70)),
                            ),
                          ])
                        : _clients.isEmpty
                            ? ListView(children: const [
                                Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text(
                                    'Δεν έχεις ακόμα πελάτες με κρατήσεις μαζί σου.',
                                    style: TextStyle(color: kGray),
                                  ),
                                ),
                              ])
                            : ListView.separated(
                                itemCount: _clients.length,
                                separatorBuilder: (_, __) => const Divider(color: kBorder, height: 1),
                                itemBuilder: (_, i) {
                                  final c = _clients[i];
                                  final next = DateTime.tryParse(c['next_session_at'] as String? ?? '');
                                  final upcoming = (c['upcoming_sessions'] as num?)?.toInt() ?? 0;
                                  final goal = c['fitness_goal_label'] as String?;
                                  return ListTile(
                                    title: Text(c['full_name'] as String? ?? '',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white, fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                      [
                                        if (goal != null && goal.isNotEmpty) goal,
                                        if (c['phone'] != null) c['phone'],
                                        if (next != null)
                                          'Επόμενη: ${DateFormat('d/M HH:mm').format(next.toLocal())}',
                                      ].join(' · '),
                                      style: const TextStyle(color: kGray),
                                    ),
                                    trailing: Text('$upcoming',
                                      style: GoogleFonts.spaceGrotesk(
                                        color: kCyan, fontWeight: FontWeight.w700, fontSize: 18)),
                                  );
                                },
                              ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
