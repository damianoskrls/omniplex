import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../widgets/omni_design.dart';

class StaffMessagesScreen extends StatefulWidget {
  const StaffMessagesScreen({super.key});

  @override
  State<StaffMessagesScreen> createState() => _StaffMessagesScreenState();
}

class _StaffMessagesScreenState extends State<StaffMessagesScreen> {
  List<Map<String, dynamic>> _threads = [];
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
      final threads = await context.read<AuthService>().api.fetchTrainerMessageThreads();
      if (mounted) setState(() => _threads = threads);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openNew() async {
    try {
      final contacts = await context.read<AuthService>().api.fetchTrainerMessageContacts();
      if (!mounted) return;
      if (contacts.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Δεν υπάρχουν πελάτες για μήνυμα')),
        );
        return;
      }
      final picked = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: kCard,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (ctx) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                child: Text('Νέο μήνυμα', style: GoogleFonts.spaceGrotesk(
                  fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
              ...contacts.map((c) => ListTile(
                title: Text(c['client_name'] as String? ?? 'Πελάτης',
                  style: const TextStyle(color: Colors.white)),
                subtitle: Text(c['client_phone'] as String? ?? '',
                  style: const TextStyle(color: kGray)),
                onTap: () => Navigator.pop(ctx, c),
              )),
            ],
          ),
        ),
      );
      if (picked == null || !mounted) return;
      final opened = await context.read<AuthService>().api.openTrainerMessageThread(
        picked['client_user_id'] as String,
      );
      final thread = (opened['thread'] as Map?)?.cast<String, dynamic>()
          ?? {'id': opened['id'], 'client_name': picked['client_name']};
      if (!mounted) return;
      await Navigator.push(context, MaterialPageRoute(
        builder: (_) => _StaffChatScreen(thread: thread),
      ));
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
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
              padding: const EdgeInsets.fromLTRB(20, 16, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Μηνύματα', style: GoogleFonts.spaceGrotesk(
                    fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white))),
                  IconButton(
                    onPressed: _openNew,
                    icon: const Icon(Icons.edit_outlined, color: kCyan),
                  ),
                ],
              ),
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
                        : _threads.isEmpty
                            ? ListView(children: const [
                                Padding(
                                  padding: EdgeInsets.all(24),
                                  child: Text('Δεν υπάρχουν συνομιλίες ακόμα.',
                                    style: TextStyle(color: kGray)),
                                ),
                              ])
                            : ListView.separated(
                                itemCount: _threads.length,
                                separatorBuilder: (_, __) => const Divider(color: kBorder, height: 1),
                                itemBuilder: (_, i) {
                                  final t = _threads[i];
                                  final unread = (t['unread_count'] as num?)?.toInt() ?? 0;
                                  final when = DateTime.tryParse(t['last_message_at'] as String? ?? '');
                                  return ListTile(
                                    onTap: () async {
                                      await Navigator.push(context, MaterialPageRoute(
                                        builder: (_) => _StaffChatScreen(thread: t),
                                      ));
                                      _load();
                                    },
                                    title: Text(t['client_name'] as String? ?? 'Πελάτης',
                                      style: GoogleFonts.manrope(
                                        color: Colors.white, fontWeight: FontWeight.w700)),
                                    subtitle: Text(
                                      t['last_message_preview'] as String? ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(color: kGray),
                                    ),
                                    trailing: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        if (when != null)
                                          Text(DateFormat('d/M HH:mm').format(when.toLocal()),
                                            style: const TextStyle(color: kGray, fontSize: 11)),
                                        if (unread > 0)
                                          Container(
                                            margin: const EdgeInsets.only(top: 4),
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: kCyan,
                                              borderRadius: BorderRadius.circular(99),
                                            ),
                                            child: Text('$unread', style: const TextStyle(
                                              color: Colors.black, fontSize: 11, fontWeight: FontWeight.w700)),
                                          ),
                                      ],
                                    ),
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

class _StaffChatScreen extends StatefulWidget {
  const _StaffChatScreen({required this.thread});
  final Map<String, dynamic> thread;

  @override
  State<_StaffChatScreen> createState() => _StaffChatScreenState();
}

class _StaffChatScreenState extends State<_StaffChatScreen> {
  final _text = TextEditingController();
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _sending = false;
  String? _error;

  String get _threadId => widget.thread['id'] as String;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final api = context.read<AuthService>().api;
      final data = await api.fetchTrainerMessageThread(_threadId);
      await api.markTrainerThreadRead(_threadId);
      if (!mounted) return;
      setState(() {
        _messages = ((data['messages'] as List?) ?? []).cast<Map<String, dynamic>>();
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _send() async {
    final body = _text.text.trim();
    if (body.isEmpty || _sending) return;
    setState(() => _sending = true);
    try {
      await context.read<AuthService>().api.sendTrainerMessage(_threadId, body);
      _text.clear();
      await _load();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = widget.thread['client_name'] as String? ?? 'Πελάτης';
    return Scaffold(
      backgroundColor: kBg,
      appBar: AppBar(
        backgroundColor: kBg,
        foregroundColor: Colors.white,
        title: Text(name, style: GoogleFonts.spaceGrotesk(fontWeight: FontWeight.w700)),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: kCyan))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.white70)))
                    : ListView.builder(
                        reverse: true,
                        padding: const EdgeInsets.all(16),
                        itemCount: _messages.length,
                        itemBuilder: (_, i) {
                          final m = _messages[_messages.length - 1 - i];
                          final mine = m['is_mine'] == true;
                          return Align(
                            alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.75),
                              decoration: BoxDecoration(
                                color: mine ? const Color(0xFF1A2A3A) : kCard,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: kBorder),
                              ),
                              child: Text(m['body'] as String? ?? '',
                                style: const TextStyle(color: Colors.white)),
                            ),
                          );
                        },
                      ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _text,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'Μήνυμα',
                        hintStyle: const TextStyle(color: kGray),
                        filled: true,
                        fillColor: kCard,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: kBorder),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    icon: const Icon(Icons.send_rounded, color: kCyan),
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
