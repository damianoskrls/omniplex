import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../theme/app_colors.dart';

class RewardsScreen extends StatefulWidget {
  const RewardsScreen({super.key, required this.apiBase, required this.token});

  final String apiBase;
  final String token;

  @override
  State<RewardsScreen> createState() => _RewardsScreenState();
}

class _RewardsScreenState extends State<RewardsScreen> {
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
      final res = await http.get(
        Uri.parse('${widget.apiBase}/loyalty/mine'),
        headers: {'Authorization': 'Bearer ${widget.token}'},
      );
      final body = jsonDecode(res.body);
      if (res.statusCode != 200) {
        _error = body['error']?.toString() ?? 'Σφάλμα';
      } else {
        _data = Map<String, dynamic>.from(body as Map);
      }
    } catch (_) {
      _error = 'Σφάλμα σύνδεσης';
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _redeem(String id) async {
    final res = await http.post(
      Uri.parse('${widget.apiBase}/loyalty/mine/$id/redeem'),
      headers: {
        'Authorization': 'Bearer ${widget.token}',
        'Content-Type': 'application/json',
      },
      body: '{}',
    );
    if (!mounted) return;
    if (res.statusCode != 200) {
      final body = jsonDecode(res.body);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(body['error']?.toString() ?? 'Δεν ενεργοποιήθηκε')),
      );
      return;
    }
    await _load();
  }

  String _perk(Map reward) {
    if (reward['reward_type'] == 'discount_percent') return '${reward['discount_percent']}% στην επόμενη drop-in';
    if (reward['reward_type'] == 'discount_fixed') {
      final euros = ((reward['discount_cents'] as num?) ?? 0) / 100;
      return '${euros.toStringAsFixed(2)}€ στην επόμενη drop-in';
    }
    return 'Αποκλειστικά για συχνούς επισκέπτες';
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    final rewards = (data?['rewards'] as List?)?.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() ?? [];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Επιβράβευση')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Text(
                        '${data?['points'] ?? 0} πόντοι · ${data?['visits_30d'] ?? 0} παρουσίες τις τελευταίες 30 ημέρες',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Οι προσφορές ανοίγουν μόνο όταν έχεις τις παρουσίες και τους πόντους που ζητά το γυμναστήριο.',
                        style: TextStyle(color: AppColors.textSecondary, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      if (rewards.isEmpty)
                        const Text('Το γυμναστήριο δεν έχει ακόμα προσφορές.', style: TextStyle(color: AppColors.textSecondary))
                      else
                        ...rewards.map((reward) {
                          final claimed = reward['claimed'] == true || reward['claimed'] == 1;
                          final eligible = reward['eligible'] == true || reward['eligible'] == 1;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(reward['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(_perk(reward), style: const TextStyle(color: AppColors.textSecondary)),
                                if ((reward['description']?.toString() ?? '').isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(reward['description'].toString(), style: const TextStyle(color: Colors.white70)),
                                  ),
                                const SizedBox(height: 8),
                                Text(
                                  '${reward['points_cost'] ?? 0} πόντοι · ${reward['min_visits'] ?? 0} παρουσίες',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const SizedBox(height: 8),
                                if (claimed)
                                  const Text('Ενεργή', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600))
                                else
                                  FilledButton(
                                    onPressed: eligible ? () => _redeem(reward['id'].toString()) : null,
                                    child: Text(eligible ? 'Ενεργοποίηση' : 'Κλειδωμένη'),
                                  ),
                              ],
                            ),
                          );
                        }),
                    ],
                  ),
                ),
    );
  }
}
