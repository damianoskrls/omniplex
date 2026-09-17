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

  bool get _hasUserMessage => _messages.any((m) => m.role == 'user');

  void _addWelcome() {
    // welcome message kept for history context but UI shows welcome card instead
  }

  void _sendQuick(String text) => _send(text);

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
    final agentName = 'AI ${config.appName}';
    final hasChat = _hasUserMessage;

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
            const _AiAvatar(size: 34, small: true),
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
            child: hasChat
                ? ListView.builder(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length + (_loading ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i == _messages.length) return const _TypingBubble();
                      return _MessageBubble(msg: _messages[i]);
                    },
                  )
                : _WelcomeCard(
                    agentName: agentName,
                    isEl: isEl,
                    onQuick: _sendQuick,
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

// ── AI Avatar (cartoon girl) ──────────────────────────────────────────────────

class _AiAvatar extends StatelessWidget {
  const _AiAvatar({this.size = 72, this.small = false});
  final double size;
  final bool small;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF7C5CFC), Color(0xFFE040FB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: small ? [] : [
          BoxShadow(
            color: const Color(0xFF7C5CFC).withValues(alpha: 0.4),
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _CartoonFacePainter(),
      ),
    );
  }
}

class _CartoonFacePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r = size.width / 2;

    // Face skin
    final skinPaint = Paint()..color = const Color(0xFFFFDBAC);
    canvas.drawCircle(Offset(cx, cy + r * 0.08), r * 0.62, skinPaint);

    // Hair (dark, top arc)
    final hairPaint = Paint()..color = const Color(0xFF2D1B00);
    final hairRect = Rect.fromCircle(center: Offset(cx, cy - r * 0.05), radius: r * 0.62);
    canvas.drawArc(hairRect, 3.14, 3.14, true, hairPaint);

    // Hair sides
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.52, cy + r * 0.10), width: r * 0.28, height: r * 0.5),
      hairPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.52, cy + r * 0.10), width: r * 0.28, height: r * 0.5),
      hairPaint,
    );

    // Eyes
    final eyePaint = Paint()..color = const Color(0xFF1A1A2E);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.22, cy + r * 0.02), width: r * 0.18, height: r * 0.22),
      eyePaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.22, cy + r * 0.02), width: r * 0.18, height: r * 0.22),
      eyePaint,
    );

    // Eye shine
    final shinePaint = Paint()..color = Colors.white;
    canvas.drawCircle(Offset(cx - r * 0.18, cy - r * 0.02), r * 0.05, shinePaint);
    canvas.drawCircle(Offset(cx + r * 0.26, cy - r * 0.02), r * 0.05, shinePaint);

    // Cheeks
    final cheekPaint = Paint()..color = const Color(0xFFFFB3BA).withValues(alpha: 0.55);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx - r * 0.34, cy + r * 0.22), width: r * 0.24, height: r * 0.14),
      cheekPaint,
    );
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx + r * 0.34, cy + r * 0.22), width: r * 0.24, height: r * 0.14),
      cheekPaint,
    );

    // Smile
    final smilePaint = Paint()
      ..color = const Color(0xFFD97F6E)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.055
      ..strokeCap = StrokeCap.round;
    final smilePath = Path();
    smilePath.moveTo(cx - r * 0.18, cy + r * 0.28);
    smilePath.quadraticBezierTo(cx, cy + r * 0.42, cx + r * 0.18, cy + r * 0.28);
    canvas.drawPath(smilePath, smilePaint);
  }

  @override
  bool shouldRepaint(_CartoonFacePainter oldDelegate) => false;
}

// ── Welcome card (shown before first user message) ─────────────────────────────

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({
    required this.agentName,
    required this.isEl,
    required this.onQuick,
  });

  final String agentName;
  final bool isEl;
  final void Function(String) onQuick;

  @override
  Widget build(BuildContext context) {
    final quickEn = ['Book a class', 'My upcoming bookings', 'View schedule', 'Cancel a booking'];
    final quickEl = ['Κλείσε μάθημα', 'Οι κρατήσεις μου', 'Δες πρόγραμμα', 'Ακύρωση κράτησης'];
    final quick = isEl ? quickEl : quickEn;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _AiAvatar(size: 96),
            const SizedBox(height: 20),
            Text(
              agentName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isEl ? 'Πώς μπορώ να σε βοηθήσω;' : 'How can I help you?',
              style: const TextStyle(fontSize: 15, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: quick.map((q) => GestureDetector(
                onTap: () => onQuick(q),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Text(
                    q,
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                  ),
                ),
              )).toList(),
            ),
          ],
        ),
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
                  borderSide: BorderSide(color: AppColors.lime, width: 1.5),
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
