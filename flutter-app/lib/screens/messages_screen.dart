import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/image_upload.dart';
import '../utils/message_content.dart';
import '../widgets/message_bubble_content.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({
    super.key,
    this.onUnreadChanged,
    this.initialPeer,
    this.initialThreadId,
  });

  final ValueChanged<int>? onUnreadChanged;
  // If set, automatically opens a conversation with this peer on mount.
  final Map<String, dynamic>? initialPeer;
  // If set, automatically opens this thread on mount.
  final String? initialThreadId;

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen> {
  List<Map<String, dynamic>> _threads = [];
  List<Map<String, dynamic>> _peers = [];
  Map<String, dynamic>? _activeThread;
  List<Map<String, dynamic>> _messages = [];
  bool _loading = true;
  bool _loadingChat = false;
  bool _sending = false;
  bool _uploadingImage = false;
  bool _showEmoji = false;
  bool _showNew = false;
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  Timer? _chatPollTimer;
  Timer? _listPollTimer;

  ApiService get _api => context.read<AuthService>().api;

  @override
  void initState() {
    super.initState();
    _loadThreads(thenOpenPeer: widget.initialPeer, thenOpenThreadId: widget.initialThreadId);
    _listPollTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (_activeThread == null && !_showNew) _loadThreads(silent: true);
    });
  }

  @override
  void dispose() {
    _chatPollTimer?.cancel();
    _listPollTimer?.cancel();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _messagesChanged(List<Map<String, dynamic>> incoming) {
    if (incoming.length != _messages.length) return true;
    for (var i = 0; i < incoming.length; i++) {
      if (incoming[i]['id'] != _messages[i]['id']) return true;
    }
    return false;
  }

  void _startChatPolling(String threadId) {
    _chatPollTimer?.cancel();
    _chatPollTimer = Timer.periodic(const Duration(seconds: 3), (_) => _pollChat(threadId));
  }

  void _stopChatPolling() {
    _chatPollTimer?.cancel();
    _chatPollTimer = null;
  }

  Future<void> _pollChat(String threadId) async {
    if (_sending || _loadingChat || !mounted) return;
    if (_activeThread?['id'] != threadId) return;
    try {
      final data = await _api.fetchMessageThread(threadId);
      if (!mounted || _activeThread?['id'] != threadId) return;
      final incoming = (data['messages'] as List? ?? []).cast<Map<String, dynamic>>();
      if (!_messagesChanged(incoming)) return;
      final hadNew = incoming.length > _messages.length;
      setState(() => _messages = incoming);
      if (hadNew) {
        await _api.markMessageThreadRead(threadId);
        await _refreshUnread();
        _scrollToBottom();
        _loadThreads(silent: true);
      }
    } catch (_) {}
  }

  Future<void> _loadThreads({bool silent = false, Map<String, dynamic>? thenOpenPeer, String? thenOpenThreadId}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final results = await Future.wait([
        _api.fetchMessageThreads(),
        _api.fetchMessagePeers(),
      ]);
      if (!mounted) return;
      setState(() {
        _threads = results[0];
        _peers = results[1];
      });
      await _refreshUnread();
      if (thenOpenThreadId != null && mounted) {
        await _openThread(thenOpenThreadId);
      } else if (thenOpenPeer != null && mounted) {
        await _startPeerChat(thenOpenPeer);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted && !silent) setState(() => _loading = false);
    }
  }

  bool _peerMatches(Map<String, dynamic> a, Map<String, dynamic> b) {
    return a['peer_role'] == b['peer_role']
        && a['peer_staff_id'] == b['peer_staff_id']
        && a['peer_nutritionist_id'] == b['peer_nutritionist_id'];
  }

  List<Map<String, dynamic>> get _conversationItems {
    final items = List<Map<String, dynamic>>.from(_threads);
    for (final peer in _peers) {
      final exists = items.any((t) => _peerMatches(t, peer));
      if (!exists) {
        items.add({
          ...peer,
          'id': null,
          'last_message_preview': 'Ξεκίνα συνομιλία',
          'unread_count': 0,
          'is_new': true,
        });
      }
    }
    items.sort((a, b) {
      final aNew = a['is_new'] == true;
      final bNew = b['is_new'] == true;
      if (aNew != bNew) return aNew ? 1 : -1;
      final ad = DateTime.tryParse('${a['last_message_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final bd = DateTime.tryParse('${b['last_message_at']}') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return bd.compareTo(ad);
    });
    return items;
  }

  Future<void> _openConversationItem(Map<String, dynamic> item) async {
    if (item['is_new'] == true) {
      await _startPeerChat(item);
      return;
    }
    final threadId = item['id'] as String?;
    if (threadId != null) await _openThread(threadId);
  }

  Future<void> _refreshUnread() async {
    try {
      final count = await _api.fetchMessageUnreadCount();
      widget.onUnreadChanged?.call(count);
    } catch (_) {}
  }

  Future<void> _loadPeers() async {
    try {
      final peers = await _api.fetchMessagePeers();
      if (!mounted) return;
      setState(() => _peers = peers);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _openThread(String threadId) async {
    setState(() {
      _showNew = false;
      _loadingChat = true;
    });
    try {
      final data = await _api.fetchMessageThread(threadId);
      if (!mounted) return;
      setState(() {
        _activeThread = data['thread'] as Map<String, dynamic>?;
        _messages = (data['messages'] as List? ?? []).cast<Map<String, dynamic>>();
      });
      await _api.markMessageThreadRead(threadId);
      await _refreshUnread();
      _scrollToBottom();
      _startChatPolling(threadId);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  Future<void> _startPeerChat(Map<String, dynamic> peer) async {
    setState(() => _loadingChat = true);
    try {
      final existing = _threads.where((t) {
        return t['peer_role'] == peer['peer_role']
            && t['peer_staff_id'] == peer['peer_staff_id']
            && t['peer_nutritionist_id'] == peer['peer_nutritionist_id'];
      }).toList();
      if (existing.isNotEmpty) {
        await _openThread(existing.first['id'] as String);
        return;
      }
      final data = await _api.openMessageThread(peer);
      if (!mounted) return;
      await _loadThreads();
      final thread = data['thread'] as Map<String, dynamic>?;
      if (thread?['id'] != null) {
        await _openThread(thread!['id'] as String);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingChat = false);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send({String? attachmentUrl, String? messageType}) async {
    final threadId = _activeThread?['id'] as String?;
    if (threadId == null) return;
    final text = _controller.text.trim();
    if ((text.isEmpty && attachmentUrl == null) || _sending || _uploadingImage) return;
    setState(() => _sending = true);
    try {
      final result = await _api.sendMessageToThread(
        threadId,
        text,
        attachmentUrl: attachmentUrl,
        messageType: messageType,
      );
      if (!mounted) return;
      setState(() {
        final msg = result['message'] as Map<String, dynamic>?;
        if (msg != null) _messages = [..._messages, msg];
      });
      _controller.clear();
      setState(() => _showEmoji = false);
      _scrollToBottom();
      await _loadThreads();
      if (!mounted || _activeThread == null) return;
      final updated = _threads.where((t) => t['id'] == threadId).toList();
      if (updated.isNotEmpty) {
        setState(() => _activeThread = updated.first);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _insertEmoji(String emoji) {
    final value = _controller.value;
    final selection = value.selection;
    final start = selection.start >= 0 ? selection.start : value.text.length;
    final end = selection.end >= 0 ? selection.end : value.text.length;
    final newText = value.text.replaceRange(start, end, emoji);
    _controller.value = value.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: start + emoji.length),
    );
  }

  Future<void> _pickImage() async {
    final threadId = _activeThread?['id'] as String?;
    if (threadId == null || _uploadingImage || _sending) return;
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
      maxWidth: 1600,
    );
    if (picked == null) return;
    setState(() => _uploadingImage = true);
    try {
      final imageBytes = await prepareMessageImageBytes(picked.path);
      final result = await _api.sendMessageToThread(
        threadId,
        '',
        imageBytes: imageBytes,
        messageType: 'image',
      );
      if (!mounted) return;
      setState(() {
        final msg = result['message'] as Map<String, dynamic>?;
        if (msg != null) _messages = [..._messages, msg];
      });
      _scrollToBottom();
      await _loadThreads();
      if (!mounted || _activeThread == null) return;
      final updated = _threads.where((t) => t['id'] == threadId).toList();
      if (updated.isNotEmpty) {
        setState(() => _activeThread = updated.first);
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } on StateError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Αποτυχία αποστολής εικόνας. Έλεγξε τη σύνδεση με το Wi‑Fi.')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingImage = false);
    }
  }

  String _formatWhen(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return '';
    final now = DateTime.now();
    if (d.year == now.year && d.month == now.month && d.day == now.day) {
      return DateFormat.Hm('el_GR').format(d.toLocal());
    }
    return DateFormat('d MMM, HH:mm', 'el_GR').format(d.toLocal());
  }

  void _backToList() {
    _stopChatPolling();
    setState(() {
      _activeThread = null;
      _messages = [];
      _showNew = false;
    });
    _loadThreads();
  }

  @override
  Widget build(BuildContext context) {
    if (_activeThread != null) {
      return _buildChat();
    }
    if (_showNew) {
      return _buildNewChat();
    }
    return _buildThreadList();
  }

  Widget _buildThreadList() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Μηνύματα'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square),
            tooltip: 'Νέα συνομιλία',
            onPressed: () async {
              setState(() => _showNew = true);
              await _loadPeers();
            },
          ),
        ],
      ),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : RefreshIndicator(
              color: AppColors.lime,
              onRefresh: _loadThreads,
              child: _conversationItems.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 120),
                        const Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              'Δεν υπάρχουν διαθέσιμες επαφές.\nΕπικοινώνησε με τη διαχείριση του γυμναστηρίου.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      itemCount: _conversationItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
                      itemBuilder: (_, i) {
                        final t = _conversationItems[i];
                        final unread = (t['unread_count'] as int?) ?? 0;
                        final isNew = t['is_new'] == true;
                        return ListTile(
                          onTap: () => _openConversationItem(t),
                          leading: CircleAvatar(
                            backgroundColor: AppColors.lime.withValues(alpha: 0.2),
                            child: Text(
                              ((t['peer_name'] as String?) ?? '?').characters.first.toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                          title: Text(
                            t['peer_name'] as String? ?? 'Συνομιλία',
                            style: TextStyle(
                              fontWeight: unread > 0 ? FontWeight.w700 : FontWeight.w500,
                            ),
                          ),
                          subtitle: Text(
                            isNew
                                ? (t['peer_subtitle'] as String? ?? 'Ξεκίνα συνομιλία')
                                : (t['last_message_preview'] as String? ?? ''),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isNew ? AppColors.textSecondary : null,
                              fontStyle: isNew ? FontStyle.italic : null,
                            ),
                          ),
                          trailing: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                _formatWhen(t['last_message_at'] as String?),
                                style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                              ),
                              if (unread > 0)
                                Container(
                                  margin: const EdgeInsets.only(top: 4),
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.lime,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '$unread',
                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
    );
  }

  Widget _buildNewChat() {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showNew = false),
        ),
        title: const Text('Νέα συνομιλία'),
      ),
      body: _peers.isEmpty
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: _peers.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: AppColors.border),
              itemBuilder: (_, i) {
                final p = _peers[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.lime.withValues(alpha: 0.2),
                    child: Text(
                      (p['peer_name'] as String? ?? '?').characters.first.toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  title: Text(p['peer_name'] as String? ?? ''),
                  subtitle: Text(p['peer_subtitle'] as String? ?? ''),
                  onTap: _loadingChat ? null : () => _startPeerChat(p),
                );
              },
            ),
    );
  }

  Widget _buildChat() {
    final title = _activeThread?['peer_name'] as String? ?? 'Συνομιλία';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: _backToList,
        ),
        title: Text(title),
      ),
      body: Column(
        children: [
          Expanded(
            child: _loadingChat
                ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    itemCount: _messages.length,
                    itemBuilder: (_, i) {
                      final m = _messages[i];
                      final isMine = m['is_mine'] == true;
                      final sender = m['sender_name'] as String? ?? '';
                      return Align(
                        alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          constraints: BoxConstraints(
                            maxWidth: MediaQuery.of(context).size.width * 0.78,
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: isMine ? AppColors.lime.withValues(alpha: 0.18) : AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isMine ? AppColors.lime.withValues(alpha: 0.35) : AppColors.border,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMine)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 4),
                                  child: Text(
                                    sender,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ),
                              MessageBubbleContent(
                                body: m['body'] as String? ?? '',
                                messageType: m['message_type'] as String?,
                                attachmentUrl: m['attachment_url'] as String?,
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _formatWhen(m['created_at'] as String?),
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (_showEmoji)
                  Container(
                    height: 160,
                    margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: GridView.builder(
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 8,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: commonEmojis.length,
                      itemBuilder: (_, i) => InkWell(
                        onTap: () => _insertEmoji(commonEmojis[i]),
                        borderRadius: BorderRadius.circular(8),
                        child: Center(child: Text(commonEmojis[i], style: const TextStyle(fontSize: 22))),
                      ),
                    ),
                  ),
                Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: (_sending || _uploadingImage) ? null : () => setState(() => _showEmoji = !_showEmoji),
                    icon: Icon(_showEmoji ? Icons.keyboard : Icons.emoji_emotions_outlined, color: AppColors.textSecondary),
                  ),
                  IconButton(
                    onPressed: (_sending || _uploadingImage) ? null : _pickImage,
                    icon: _uploadingImage
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime),
                          )
                        : const Icon(Icons.image_outlined, color: AppColors.textSecondary),
                  ),
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      decoration: InputDecoration(
                        hintText: 'Γράψε μήνυμα...',
                        filled: true,
                        fillColor: AppColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(16),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: (_sending || _uploadingImage) ? null : () => _send(),
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.send_rounded),
                    style: IconButton.styleFrom(
                      backgroundColor: AppColors.lime,
                      foregroundColor: Colors.black,
                    ),
                  ),
                ],
              ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
