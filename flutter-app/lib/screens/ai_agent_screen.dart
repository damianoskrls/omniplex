import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../config/tenant_config.dart';
import '../services/auth_service.dart';
import '../services/language_service.dart';
import '../theme/app_colors.dart';

class AiAgentScreen extends StatefulWidget {
  const AiAgentScreen({super.key});

  @override
  State<AiAgentScreen> createState() => _AiAgentScreenState();
}

class _AiAgentScreenState extends State<AiAgentScreen> with TickerProviderStateMixin {
  final _messages = <_Msg>[];
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _loading = false;

  // Voice
  final _speech = SpeechToText();
  bool _speechAvailable = false;
  bool _listening = false;

  // Pulse animation for mic
  late final AnimationController _pulseCtrl;
  late final Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
      ..repeat(reverse: true);
    _pulse = Tween<double>(begin: 1.0, end: 1.22).animate(
      CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut),
    );
    _pulseCtrl.stop();
    _initSpeech();
    _addWelcome();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _controller.dispose();
    _scroll.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    _speechAvailable = await _speech.initialize(onError: (_) {});
    if (mounted) setState(() {});
  }

  void _addWelcome() {
    final isEl = LanguageService.instance.isGreek;
    final config = context.read<TenantConfig>();
    final auth = context.read<AuthService>();
    final name = auth.user?.fullName.split(' ').first ?? '';
    final greeting = isEl
        ? 'Γεια σου${name.isNotEmpty ? ', $name' : ''}! 👋 Είμαι ο AI βοηθός σου στο **${config.appName}**.\n\nΜπορώ να σε βοηθήσω με:\n• Κρατήσεις & ακυρώσεις\n• Διαθέσιμα μαθήματα\n• Ωράριο & πληροφορίες γυμναστηρίου\n\nΤι θέλεις να κάνεις;'
        : 'Hey${name.isNotEmpty ? ', $name' : ''}! 👋 I\'m your AI assistant at **${config.appName}**.\n\nI can help you with:\n• Bookings & cancellations\n• Available classes\n• Schedule & gym info\n\nWhat would you like to do?';
    _messages.add(_Msg(role: 'assistant', text: greeting));
  }

  Future<void> _send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || _loading) return;

    setState(() {
      _messages.add(_Msg(role: 'user', text: trimmed));
      _loading = true;
    });
    _controller.clear();
    _scrollToBottom();

    final config = context.read<TenantConfig>();
    final auth   = context.read<AuthService>();
    final locale = LanguageService.instance.isGreek ? 'el' : 'en';

    // Build message history (skip the welcome, send only real turns)
    final history = _messages
        .where((m) => m.role == 'user' || (m.role == 'assistant' && !m.isWelcome))
        .map((m) => {'role': m.role, 'content': m.text})
        .toList();

    try {
      final resp = await auth.api.post(
        '/ai/${config.businessId}/chat',
        {'messages': history, 'locale': locale},
      );
      final reply = (resp['reply'] as String?) ?? '';
      setState(() {
        _messages.add(_Msg(role: 'assistant', text: reply));
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _messages.add(_Msg(
          role: 'assistant',
          text: LanguageService.instance.isGreek
              ? 'Συγγνώμη, κάτι πήγε στραβά. Δοκίμασε ξανά.'
              : 'Sorry, something went wrong. Please try again.',
          isError: true,
        ));
        _loading = false;
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (!_speechAvailable) return;
    if (_listening) {
      await _speech.stop();
      setState(() { _listening = false; });
      _pulseCtrl.stop();
      _pulseCtrl.reset();
      return;
    }

    final locale = LanguageService.instance.isGreek ? 'el_GR' : 'en_US';
    final started = await _speech.listen(
      localeId: locale,
      onResult: (r) {
        if (r.finalResult) {
          _controller.text = r.recognizedWords;
          setState(() { _listening = false; });
          _pulseCtrl.stop();
          _pulseCtrl.reset();
          if (r.recognizedWords.isNotEmpty) _send(r.recognizedWords);
        } else {
          setState(() { _controller.text = r.recognizedWords; });
        }
      },
      listenFor: const Duration(seconds: 30),
      pauseFor: const Duration(seconds: 4),
    );
    if (started) {
      setState(() { _listening = true; });
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEl = LanguageService.instance.isGreek;
    final config = context.read<TenantConfig>();
    final agentName = '${config.appName} Βοηθός';
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Container(
              width: 34, height: 34,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C5CFC), Color(0xFFE040FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  agentName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white),
                ),
                Text(
                  isEl ? 'Πάντα εδώ για εσένα' : 'Always here to help',
                  style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              itemCount: _messages.length + (_loading ? 1 : 0),
              itemBuilder: (_, i) {
                if (i == _messages.length) return const _TypingBubble();
                return _MessageBubble(msg: _messages[i]);
              },
            ),
          ),
          _InputBar(
            controller: _controller,
            onSend: () => _send(_controller.text),
            onMic: _speechAvailable ? _toggleListening : null,
            listening: _listening,
            pulse: _pulse,
            isEl: isEl,
          ),
        ],
      ),
    );
  }
}

// ── Data ──────────────────────────────────────────────────────────────────────

class _Msg {
  _Msg({required this.role, required this.text, this.isError = false, this.isWelcome = false});
  final String role;
  final String text;
  final bool isError;
  final bool isWelcome;
}

// ── Message bubble ────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.msg});
  final _Msg msg;

  @override
  Widget build(BuildContext context) {
    final isUser = msg.role == 'user';
    return Padding(
      padding: EdgeInsets.only(
        top: 6, bottom: 6,
        left: isUser ? 48 : 0,
        right: isUser ? 0 : 48,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isUser) ...[
            Container(
              width: 28, height: 28,
              margin: const EdgeInsets.only(right: 8, bottom: 2),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C5CFC), Color(0xFFE040FB)],
                ),
                borderRadius: BorderRadius.circular(9),
              ),
              child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
            ),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.lime.withValues(alpha: 0.12)
                    : msg.isError
                        ? Colors.red.withValues(alpha: 0.10)
                        : AppColors.surface,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: Border.all(
                  color: isUser
                      ? AppColors.lime.withValues(alpha: 0.25)
                      : AppColors.border,
                ),
              ),
              child: _MarkdownText(text: msg.text, isUser: isUser),
            ),
          ),
        ],
      ),
    );
  }
}

// Simple bold/italic markdown renderer (no package needed)
class _MarkdownText extends StatelessWidget {
  const _MarkdownText({required this.text, required this.isUser});
  final String text;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final color = isUser ? AppColors.lime : AppColors.textPrimary;
    // Split on **bold** and render
    final spans = <InlineSpan>[];
    final reg = RegExp(r'\*\*(.+?)\*\*');
    int last = 0;
    for (final m in reg.allMatches(text)) {
      if (m.start > last) {
        spans.add(TextSpan(text: text.substring(last, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ));
      last = m.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));

    return RichText(
      text: TextSpan(
        style: TextStyle(color: color, fontSize: 14.5, height: 1.5),
        children: spans,
      ),
    );
  }
}

// ── Typing indicator ──────────────────────────────────────────────────────────

class _TypingBubble extends StatefulWidget {
  const _TypingBubble();

  @override
  State<_TypingBubble> createState() => _TypingBubbleState();
}

class _TypingBubbleState extends State<_TypingBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat();
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 6, right: 48),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Container(
            width: 28, height: 28,
            margin: const EdgeInsets.only(right: 8, bottom: 2),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF7C5CFC), Color(0xFFE040FB)]),
              borderRadius: BorderRadius.circular(9),
            ),
            child: const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 14),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
                bottomRight: Radius.circular(16),
                bottomLeft: Radius.circular(4),
              ),
              border: Border.all(color: AppColors.border),
            ),
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (_, __) => Row(
                mainAxisSize: MainAxisSize.min,
                children: List.generate(3, (i) {
                  final t = (_ctrl.value - i * 0.2).clamp(0.0, 1.0);
                  final opacity = (0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2)).clamp(0.3, 1.0);
                  return Container(
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: 7, height: 7,
                    decoration: BoxDecoration(
                      color: AppColors.textSecondary.withValues(alpha: opacity),
                      shape: BoxShape.circle,
                    ),
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Input bar ─────────────────────────────────────────────────────────────────

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.onSend,
    required this.onMic,
    required this.listening,
    required this.pulse,
    required this.isEl,
  });

  final TextEditingController controller;
  final VoidCallback onSend;
  final VoidCallback? onMic;
  final bool listening;
  final Animation<double> pulse;
  final bool isEl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: Row(
        children: [
          // Mic
          if (onMic != null)
            GestureDetector(
              onTap: onMic,
              child: AnimatedBuilder(
                animation: pulse,
                builder: (_, __) => Transform.scale(
                  scale: listening ? pulse.value : 1.0,
                  child: Container(
                    width: 42, height: 42,
                    decoration: BoxDecoration(
                      color: listening
                          ? const Color(0xFFE040FB).withValues(alpha: 0.15)
                          : AppColors.bg,
                      borderRadius: BorderRadius.circular(13),
                      border: Border.all(
                        color: listening
                            ? const Color(0xFFE040FB).withValues(alpha: 0.6)
                            : AppColors.border,
                      ),
                    ),
                    child: Icon(
                      listening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: listening ? const Color(0xFFE040FB) : AppColors.textSecondary,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ),
          const SizedBox(width: 8),
          // Text field
          Expanded(
            child: TextField(
              controller: controller,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 15),
              decoration: InputDecoration(
                hintText: isEl ? 'Γράψε ή μίλα...' : 'Type or speak...',
                hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 15),
                filled: true,
                fillColor: AppColors.bg,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: AppColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppColors.lime, width: 1.5),
                ),
              ),
              maxLines: null,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          // Send
          GestureDetector(
            onTap: onSend,
            child: Container(
              width: 42, height: 42,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF7C5CFC), Color(0xFFE040FB)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(Icons.send_rounded, color: Colors.white, size: 18),
            ),
          ),
        ],
      ),
    );
  }
}
