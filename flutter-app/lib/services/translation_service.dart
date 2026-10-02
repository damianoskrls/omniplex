import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/seed_en.dart';
import 'language_service.dart';

class TranslationService extends ChangeNotifier {
  TranslationService._();
  static final TranslationService instance = TranslationService._();

  static const _prefsKey = 'ai_tr_en_v1';
  static const _endpoint =
      'https://passionate-grace-production-98ad.up.railway.app/api/i18n/translate';
  static final _greek = RegExp(r'[\u0370-\u03FF\u1F00-\u1FFF]');

  final Map<String, String> _cache = {};
  final Set<String> _pending = {};
  final Set<String> _failed = {};
  Timer? _timer;
  bool _loaded = false;

  Future<void> load() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefsKey);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          decoded.forEach((key, value) {
            if (key is String && value is String && value.isNotEmpty) {
              _cache[key] = value;
            }
          });
        }
      }
    } catch (_) {}
  }

  String lookup(String text) {
    if (text.isEmpty || LanguageService.instance.isGreek || !_greek.hasMatch(text)) {
      return text;
    }
    final seeded = kEnglishSeed[text];
    if (seeded != null) return seeded;
    final cached = _cache[text];
    if (cached != null) return cached;
    if (!_failed.contains(text)) _enqueue(text);
    return text;
  }

  void _enqueue(String text) {
    if (text.length > 2000) return;
    _pending.add(text);
    _timer ??= Timer(const Duration(milliseconds: 350), () {
      _timer = null;
      final batch = _pending.toList();
      _pending.clear();
      unawaited(_flush(batch));
    });
  }

  Future<void> _flush(List<String> texts) async {
    if (texts.isEmpty || LanguageService.instance.isGreek) return;
    final missing = texts.where((t) => !_cache.containsKey(t) && kEnglishSeed[t] == null).toList();
    if (missing.isEmpty) return;

    var changed = false;
    for (var i = 0; i < missing.length; i += 30) {
      final chunk = missing.sublist(i, i + 30 > missing.length ? missing.length : i + 30);
      try {
        final res = await http
            .post(
              Uri.parse(_endpoint),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({'target': 'en', 'texts': chunk}),
            )
            .timeout(const Duration(seconds: 25));
        if (res.statusCode < 200 || res.statusCode >= 300) {
          chunk.forEach(_failed.add);
          continue;
        }
        final body = jsonDecode(res.body);
        final map = body is Map ? body['translations'] : null;
        if (map is! Map) {
          chunk.forEach(_failed.add);
          continue;
        }
        for (final source in chunk) {
          final value = map[source];
          if (value is String && value.trim().isNotEmpty && value.trim() != source) {
            _cache[source] = value.trim();
            changed = true;
          } else {
            _failed.add(source);
          }
        }
      } catch (_) {
        chunk.forEach(_failed.add);
      }
    }
    if (changed) {
      await _persist();
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final entries = _cache.entries.toList();
      final kept = entries.length > 2500 ? entries.sublist(entries.length - 2500) : entries;
      await prefs.setString(_prefsKey, jsonEncode(Map.fromEntries(kept)));
    } catch (_) {}
  }
}
