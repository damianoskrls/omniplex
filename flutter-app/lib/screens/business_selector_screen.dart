import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/tenant_config.dart';

class BusinessSelectorScreen extends StatefulWidget {
  const BusinessSelectorScreen({
    super.key,
    required this.onConfigLoaded,
    this.showBack = false,
    this.apiBaseUrl = 'https://passionate-grace-production-98ad.up.railway.app',
  });

  final void Function(TenantConfig) onConfigLoaded;
  final bool showBack;
  final String apiBaseUrl;

  @override
  State<BusinessSelectorScreen> createState() => _BusinessSelectorScreenState();
}

class _SearchResult {
  final String slug;
  final String name;
  final String appName;
  final String businessType;
  final String primaryColor;
  final String? logoUrl;

  const _SearchResult({
    required this.slug,
    required this.name,
    required this.appName,
    required this.businessType,
    required this.primaryColor,
    this.logoUrl,
  });

  factory _SearchResult.fromJson(Map<String, dynamic> j) => _SearchResult(
    slug:         j['slug']          as String,
    name:         j['name']          as String,
    appName:      j['app_name']      as String,
    businessType: j['business_type'] as String,
    primaryColor: j['primary_color'] as String? ?? '#6200EE',
    logoUrl:      j['logo_url']      as String?,
  );
}

class _BusinessSelectorScreenState extends State<BusinessSelectorScreen> {
  final _searchCtrl = TextEditingController();
  final _focusNode  = FocusNode();

  List<_SearchResult> _results  = [];
  bool _searching   = false;
  bool _connecting  = false;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _focusNode.requestFocus();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged(String val) {
    _debounce?.cancel();
    if (val.trim().length < 2) {
      setState(() { _results = []; _error = null; });
      return;
    }
    setState(() { _searching = true; _error = null; });
    _debounce = Timer(const Duration(milliseconds: 400), () => _doSearch(val.trim()));
  }

  Future<void> _doSearch(String q) async {
    try {
      final uri = Uri.parse('${widget.apiBaseUrl}/api/tenants/search?q=${Uri.encodeComponent(q)}');
      final res = await http.get(uri).timeout(const Duration(seconds: 6));
      if (!mounted) return;
      if (res.statusCode == 200) {
        final list = (jsonDecode(res.body) as List)
            .map((e) => _SearchResult.fromJson(e as Map<String, dynamic>))
            .toList();
        setState(() { _results = list; _searching = false; });
      } else {
        setState(() { _error = 'Σφάλμα σύνδεσης (${res.statusCode})'; _searching = false; });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Δεν βρέθηκε server στο ${widget.apiBaseUrl}.\nΕπέλεξε "Προχωρημένες" για να αλλάξεις IP.';
        _searching = false;
      });
    }
  }

  Future<void> _selectBusiness(_SearchResult biz) async {
    setState(() { _connecting = true; _error = null; });
    try {
      final config = await TenantConfig.loadFromApi(
        slug:       biz.slug,
        apiBaseUrl: widget.apiBaseUrl,
      );
      if (!mounted) return;
      widget.onConfigLoaded(config);
    } catch (e) {
      if (!mounted) return;
      setState(() { _error = e.toString().replaceFirst('Exception: ', ''); _connecting = false; });
    }
  }

  Color _parseColor(String hex) {
    try { return Color(int.parse(hex.replaceFirst('#', '0xFF'))); }
    catch (_) { return const Color(0xFF6200EE); }
  }

  String _typeLabel(String t) {
    const m = {
      'gym': 'Γυμναστήριο', 'aesthetic': 'Αισθητική',
      'salon': 'Κομμωτήριο', 'barbershop': 'Barbershop',
      'spa': 'Spa', 'pilates': 'Pilates / Yoga',
      'physiotherapy': 'Φυσικοθεραπεία', 'personal_training': 'Personal Training',
    };
    return m[t] ?? t;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ergonhub wordmark
                  Row(
                    children: [
                      Container(
                        width: 32, height: 32,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6200EE), Color(0xFF03DAC6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.hub_outlined, color: Colors.white, size: 18),
                      ),
                      const SizedBox(width: 10),
                      const Text(
                        'ergonhub',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  const Text(
                    'Βρες την επιχείρησή σου',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Αναζήτησε με το όνομα του γυμναστηρίου ή κέντρου σου.',
                    style: TextStyle(color: Colors.white54, fontSize: 14, height: 1.5),
                  ),
                  const SizedBox(height: 20),

                  // Search field
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1A2E),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: TextField(
                      controller: _searchCtrl,
                      focusNode: _focusNode,
                      onChanged: _onSearchChanged,
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                      decoration: InputDecoration(
                        hintText: 'π.χ. Handstand, FitLife...',
                        hintStyle: const TextStyle(color: Colors.white30),
                        prefixIcon: _searching
                            ? const Padding(
                                padding: EdgeInsets.all(14),
                                child: SizedBox(
                                  width: 20, height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(Colors.white38),
                                  ),
                                ),
                              )
                            : const Icon(Icons.search, color: Colors.white38, size: 22),
                        suffixIcon: _searchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, color: Colors.white38, size: 18),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() { _results = []; _error = null; });
                                },
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Error
            if (_error != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                  ),
                  child: Text(_error!,
                    style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 13, height: 1.5)),
                ),
              ),

            // Results list
            Expanded(
              child: _results.isEmpty && _searchCtrl.text.trim().length >= 2 && !_searching
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.search_off, color: Colors.white24, size: 48),
                          const SizedBox(height: 12),
                          const Text('Δεν βρέθηκαν αποτελέσματα',
                              style: TextStyle(color: Colors.white38, fontSize: 15)),
                          const SizedBox(height: 6),
                          Text('Δοκίμασε διαφορετική αναζήτηση',
                              style: TextStyle(color: Colors.white24, fontSize: 13)),
                        ],
                      ),
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                      itemCount: _results.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (ctx, i) {
                        final biz   = _results[i];
                        final color = _parseColor(biz.primaryColor);
                        final logoUrl = biz.logoUrl != null
                            ? '${widget.apiBaseUrl}${biz.logoUrl}'
                            : null;

                        return GestureDetector(
                          onTap: _connecting ? null : () => _selectBusiness(biz),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 150),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF12121C),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Row(
                              children: [
                                // Logo / avatar
                                Container(
                                  width: 52, height: 52,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: color.withValues(alpha: 0.3)),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(13),
                                    child: logoUrl != null
                                        ? Image.network(logoUrl, fit: BoxFit.contain,
                                            errorBuilder: (_, __, ___) => Icon(Icons.business_center_outlined, color: color, size: 24))
                                        : Icon(Icons.business_center_outlined, color: color, size: 24),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(biz.appName,
                                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
                                      const SizedBox(height: 3),
                                      Text(_typeLabel(biz.businessType),
                                          style: const TextStyle(color: Colors.white54, fontSize: 13)),
                                    ],
                                  ),
                                ),
                                if (_connecting)
                                  const SizedBox(
                                    width: 20, height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white38)),
                                  )
                                else
                                  Icon(Icons.arrow_forward_ios, color: color, size: 16),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // Footer
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                children: [
                  if (_searchCtrl.text.isEmpty)
                    const Text(
                      'Πληκτρολόγησε τουλάχιστον 2 γράμματα για αναζήτηση',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white24, fontSize: 12),
                    ),
                  const SizedBox(height: 16),
                  const Text('Powered by ergonhub',
                      style: TextStyle(color: Colors.white12, fontSize: 11, letterSpacing: 1)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
