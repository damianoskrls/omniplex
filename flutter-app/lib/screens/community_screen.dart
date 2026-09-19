import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../l10n/app_strings.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../utils/image_upload.dart';
import '../widgets/image_lightbox.dart';
import '../widgets/message_bubble_content.dart';
import 'messages_screen.dart';

// Notifier used by HomeScreen to tell CommunityScreen which post to highlight
final _highlightPostNotifier = ValueNotifier<String?>(null);

class CommunityScreen extends StatefulWidget {
  const CommunityScreen({super.key});

  static void highlightPost(String postId) {
    _highlightPostNotifier.value = postId;
  }

  @override
  State<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends State<CommunityScreen> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;
  String? _nextCursor;
  bool _loadingMore = false;
  Timer? _pollTimer;
  String? _highlightedPostId;
  final _scrollController = ScrollController();
  final _postKeys = <String, GlobalKey>{};

  ApiService get _api => context.read<AuthService>().api;
  String get _base => _api.config.apiBaseUrl.replaceAll(RegExp(r'/$'), '');

  @override
  void initState() {
    super.initState();
    _load();
    _pollTimer = Timer.periodic(const Duration(seconds: 30), (_) => _load(silent: true));
    _highlightPostNotifier.addListener(_onHighlightRequest);
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _scrollController.dispose();
    _highlightPostNotifier.removeListener(_onHighlightRequest);
    super.dispose();
  }

  void _onHighlightRequest() {
    final postId = _highlightPostNotifier.value;
    if (postId == null || !mounted) return;
    _highlightPostNotifier.value = null;
    setState(() => _highlightedPostId = postId);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _postKeys[postId];
      if (key?.currentContext != null) {
        Scrollable.ensureVisible(key!.currentContext!, duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
      }
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _highlightedPostId = null);
      });
    });
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final r = await _api.getCommunityPosts();
      if (!mounted) return;
      setState(() {
        _posts = List<Map<String, dynamic>>.from(r['posts'] ?? []);
        _nextCursor = r['next_cursor'] as String?;
        _loading = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_nextCursor == null || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final r = await _api.getCommunityPosts(cursor: _nextCursor);
      if (!mounted) return;
      setState(() {
        _posts.addAll(List<Map<String, dynamic>>.from(r['posts'] ?? []));
        _nextCursor = r['next_cursor'] as String?;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _react(String postId, int index) async {
    final post = _posts[index];
    final wasLiked = post['liked'] == true;
    setState(() {
      _posts[index] = {
        ...post,
        'liked': !wasLiked,
        'reaction_count': (post['reaction_count'] as int? ?? 0) + (wasLiked ? -1 : 1),
      };
    });
    try {
      await _api.reactCommunityPost(postId);
    } catch (_) {
      if (mounted) setState(() { _posts[index] = post; });
    }
  }

  Future<void> _deletePost(String postId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppStrings.of(context).communityDeleteTitle, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(AppStrings.of(context).communityDeletePost, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.of(context).cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.of(context).communityDeleteAction, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true) return;
    await _api.deleteCommunityPost(postId);
    setState(() => _posts.removeWhere((p) => p['id'] == postId));
  }

  void _openComments(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CommentsSheet(
        post: _posts[index],
        api: _api,
        base: _base,
        onCommentAdded: (comment) {
          if (!mounted) return;
          setState(() {
            final comments = List<Map<String, dynamic>>.from(_posts[index]['comments'] ?? []);
            comments.add(comment);
            _posts[index] = {..._posts[index], 'comments': comments};
          });
        },
      ),
    );
  }

  Future<void> _openMessagePicker() async {
    List<Map<String, dynamic>> peers;
    try {
      peers = await _api.fetchMessagePeers();
    } catch (_) {
      peers = [];
    }
    if (!mounted) return;

    if (peers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppStrings.of(context).communityNoContacts)),
      );
      return;
    }

    Map<String, dynamic>? peer;
    if (peers.length == 1) {
      peer = peers.first;
    } else {
      peer = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (_) => Container(
          decoration: const BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(AppStrings.of(context).communityContactWith, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
              const SizedBox(height: 12),
              ...peers.map((p) => ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppColors.lime.withValues(alpha: 0.15),
                  child: Text(
                    (p['peer_name'] as String? ?? '?').isNotEmpty ? (p['peer_name'] as String)[0].toUpperCase() : '?',
                    style: TextStyle(color: AppColors.lime, fontWeight: FontWeight.bold),
                  ),
                ),
                title: Text(p['peer_name'] as String? ?? '', style: const TextStyle(color: AppColors.textPrimary)),
                subtitle: Text(_roleLabel(p['peer_role'] as String? ?? ''), style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                onTap: () => Navigator.pop(context, p),
              )),
            ],
          ),
        ),
      );
    }

    if (peer == null || !mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => MessagesScreen(initialPeer: peer)),
    );
  }

  String _roleLabel(String role) {
    switch (role) {
      case 'admin': return AppStrings.of(context).communityRoleAdmin;
      case 'secretary': return AppStrings.of(context).communityRoleSecretary;
      case 'receptionist': return AppStrings.of(context).communityRoleReceptionist;
      default: return role;
    }
  }

  void _openNewPost() async {
    final result = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NewPostSheet(api: _api, base: _base),
    );
    if (result == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(AppStrings.of(context).communityTitle, style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w700)),
        backgroundColor: AppColors.surface,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.message_outlined, color: AppColors.lime),
            onPressed: _openMessagePicker,
            tooltip: AppStrings.of(context).communityMessageTooltip,
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_outline, color: AppColors.lime),
            onPressed: _openNewPost,
            tooltip: AppStrings.of(context).communityNewPostTooltip,
          ),
        ],
      ),
      body: _loading
          ? Center(child: const CircularProgressIndicator(color: AppColors.lime))
          : RefreshIndicator(
              color: AppColors.lime,
              onRefresh: _load,
              child: _posts.isEmpty
                  ? ListView(
                      children: [
                        SizedBox(height: MediaQuery.of(context).size.height * 0.25),
                        const Icon(Icons.people_outline, size: 64, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Center(child: Text(AppStrings.of(context).communityNoPosts, style: const TextStyle(color: AppColors.textSecondary, fontSize: 16))),
                        const SizedBox(height: 12),
                        Center(
                          child: TextButton.icon(
                            onPressed: _openNewPost,
                            icon: const Icon(Icons.add, color: AppColors.lime),
                            label: Text(AppStrings.of(context).communityFirstPost, style: const TextStyle(color: AppColors.lime)),
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 100),
                      itemCount: _posts.length + (_nextCursor != null ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == _posts.length) {
                          return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Center(
                              child: _loadingMore
                                  ? const CircularProgressIndicator(color: AppColors.lime)
                                  : TextButton(onPressed: _loadMore, child: Text(AppStrings.of(context).communityLoadMore, style: const TextStyle(color: AppColors.lime))),
                            ),
                          );
                        }
                        final postId = _posts[i]['id'] as String;
                        _postKeys[postId] ??= GlobalKey();
                        return _PostCard(
                          key: _postKeys[postId],
                          post: _posts[i],
                          base: _base,
                          onReact: () => _react(postId, i),
                          onComment: () => _openComments(i),
                          onDelete: _posts[i]['user_id'] != null ? () => _deletePost(postId) : null,
                          highlighted: _highlightedPostId == postId,
                        );
                      },
                    ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openNewPost,
        icon: const Icon(Icons.edit_outlined),
        label: Text(AppStrings.of(context).communityNewPost),
        backgroundColor: AppColors.lime,
        foregroundColor: Colors.black,
      ),
    );
  }
}

// ── Post Card ─────────────────────────────────────────────────────────────────

class _PostCard extends StatelessWidget {
  final Map<String, dynamic> post;
  final String base;
  final VoidCallback onReact;
  final VoidCallback onComment;
  final bool highlighted;
  final VoidCallback? onDelete;

  const _PostCard({super.key, required this.post, required this.base, required this.onReact, required this.onComment, this.onDelete, this.highlighted = false});

  String _fmtDate(String iso, BuildContext context) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    final now = DateTime.now();
    final diff = now.difference(d);
    if (diff.inSeconds < 60) return AppStrings.of(context).communityJustNow;
    if (diff.inMinutes < 60) return AppStrings.of(context).communityMinutesAgo(diff.inMinutes);
    if (diff.inHours < 24) return AppStrings.of(context).communityHoursAgo(diff.inHours);
    return '${d.day}/${d.month}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final authorName = (post['staff_name'] ?? post['user_name'] ?? AppStrings.of(context).communityUnknownAuthor) as String;
    final isStaff = post['staff_id'] != null;
    final body = post['body'] as String?;
    final media = List<Map<String, dynamic>>.from(post['media'] ?? []);
    final reactions = post['reaction_count'] as int? ?? 0;
    final liked = post['liked'] == true;
    final comments = List<Map<String, dynamic>>.from(post['comments'] ?? []);
    final isPinned = post['is_pinned'] == true;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: highlighted ? AppColors.lime.withValues(alpha: 0.08) : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: highlighted
            ? Border.all(color: AppColors.lime, width: 2)
            : isPinned
                ? Border.all(color: const Color(0xFFF59E0B), width: 1.5)
                : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isPinned)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Row(
                children: [
                  const Text('📌', style: TextStyle(fontSize: 13)),
                  const SizedBox(width: 4),
                  Text(AppStrings.of(context).communityPinned, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Color(0xFFD97706))),
                ],
              ),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(14, isPinned ? 6 : 14, 14, 0),
            child: Row(
              children: [
                _Avatar(name: authorName, imageUrl: post['staff_avatar'] != null ? '$base${post['staff_avatar']}' : null, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(authorName, style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 14)),
                          if (isStaff) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                              decoration: BoxDecoration(color: AppColors.lime.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(20)),
                              child: Text('Staff', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.lime)),
                            ),
                          ],
                        ],
                      ),
                      Text(_fmtDate(post['created_at'] as String? ?? '', context), style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    ],
                  ),
                ),
                if (onDelete != null)
                  PopupMenuButton<String>(
                    color: AppColors.surfaceLight,
                    onSelected: (v) { if (v == 'delete') onDelete!(); },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'delete', child: Row(children: [const Icon(Icons.delete_outline, color: Colors.red, size: 16), const SizedBox(width: 8), Text(AppStrings.of(context).communityDeleteAction, style: const TextStyle(color: Colors.red))])),
                    ],
                    icon: const Icon(Icons.more_horiz, color: AppColors.textSecondary),
                  ),
              ],
            ),
          ),
          if (body != null && body.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: MessageBubbleContent(body: body),
            ),
          if (media.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: media.length == 1
                  ? _MediaItem(item: media[0], base: base)
                  : GridView.count(
                      crossAxisCount: 2,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 2,
                      crossAxisSpacing: 2,
                      children: media.take(4).map((m) => _MediaItem(item: m, base: base, fit: BoxFit.cover)).toList(),
                    ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
            child: Row(
              children: [
                _ActionBtn(
                  icon: liked ? Icons.favorite : Icons.favorite_border,
                  color: liked ? Colors.red : AppColors.textSecondary,
                  label: reactions > 0 ? '$reactions' : '',
                  onTap: onReact,
                ),
                const SizedBox(width: 4),
                _ActionBtn(
                  icon: Icons.chat_bubble_outline,
                  color: AppColors.textSecondary,
                  label: comments.isNotEmpty ? '${comments.length}' : '',
                  onTap: onComment,
                ),
              ],
            ),
          ),
          if (comments.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: GestureDetector(
                onTap: onComment,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _CommentRow(comment: comments.first, base: base),
                    if (comments.length > 1)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(AppStrings.of(context).communityMoreComments(comments.length - 1), style: const TextStyle(fontSize: 12, color: AppColors.lime, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
              ),
            )
          else
            const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;
  const _ActionBtn({required this.icon, required this.color, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(20),
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          if (label.isNotEmpty) ...[const SizedBox(width: 4), Text(label, style: TextStyle(fontSize: 13, color: color))],
        ],
      ),
    ),
  );
}

class _MediaItem extends StatelessWidget {
  final Map<String, dynamic> item;
  final String base;
  final BoxFit fit;
  const _MediaItem({required this.item, required this.base, this.fit = BoxFit.contain});

  @override
  Widget build(BuildContext context) {
    if (item['type'] == 'video') {
      return Container(color: Colors.black87, child: const Center(child: Icon(Icons.play_circle_outline, color: Colors.white, size: 48)));
    }
    final imageUrl = '$base${item['url']}';
    return GestureDetector(
      onTap: () => ImageLightbox.show(context, imageUrl),
      child: Image.network(imageUrl, fit: fit, errorBuilder: (_, __, ___) => const SizedBox()),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String name;
  final String? imageUrl;
  final double size;
  const _Avatar({required this.name, this.imageUrl, this.size = 36});

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().split(' ').map((w) => w.isEmpty ? '' : w[0]).take(2).join().toUpperCase();
    if (imageUrl != null) return CircleAvatar(radius: size / 2, backgroundImage: NetworkImage(imageUrl!));
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: AppColors.lime.withValues(alpha: 0.15),
      child: Text(initials, style: TextStyle(fontWeight: FontWeight.bold, fontSize: size * 0.35, color: AppColors.lime)),
    );
  }
}

class _CommentRow extends StatelessWidget {
  final Map<String, dynamic> comment;
  final String base;
  const _CommentRow({required this.comment, required this.base});

  @override
  Widget build(BuildContext context) {
    final name = (comment['staff_name'] ?? comment['user_name'] ?? '') as String;
    final avatarUrl = comment['staff_avatar'] as String?;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Avatar(name: name, imageUrl: avatarUrl != null ? '$base$avatarUrl' : null, size: 24),
        const SizedBox(width: 8),
        Expanded(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)),
            child: RichText(
              text: TextSpan(
                children: [
                  TextSpan(text: '$name ', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary, fontSize: 12)),
                  TextSpan(text: comment['body'] as String? ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 12)),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ── Comments Bottom Sheet ─────────────────────────────────────────────────────

class _CommentsSheet extends StatefulWidget {
  final Map<String, dynamic> post;
  final ApiService api;
  final String base;
  final void Function(Map<String, dynamic>) onCommentAdded;
  const _CommentsSheet({required this.post, required this.api, required this.base, required this.onCommentAdded});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final _controller = TextEditingController();
  final _scrollCtrl = ScrollController();
  List<Map<String, dynamic>> _comments = [];
  List<Map<String, dynamic>> _mentionables = [];
  List<Map<String, dynamic>> _pendingMentions = [];
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _sending = false;
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    _comments = List<Map<String, dynamic>>.from(widget.post['comments'] ?? []);
    _myUserId = context.read<AuthService>().user?.id;
    _controller.addListener(_onTextChanged);
    widget.api.fetchCommunityMentionables().then((m) { if (mounted) setState(() => _mentionables = m); });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx >= 0 && (atIdx == 0 || before[atIdx - 1] == ' ' || before[atIdx - 1] == '\n')) {
      final query = before.substring(atIdx + 1).toLowerCase();
      final suggestions = _mentionables
          .where((m) => (m['full_name'] as String? ?? '').toLowerCase().contains(query))
          .take(5)
          .toList();
      setState(() => _mentionSuggestions = suggestions);
    } else {
      setState(() => _mentionSuggestions = []);
    }
  }

  void _insertMention(Map<String, dynamic> person) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    final after = text.substring(cursor);
    final name = person['full_name'] as String;
    final newText = '${text.substring(0, atIdx)}@$name $after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIdx + name.length + 2),
    );
    setState(() {
      _mentionSuggestions = [];
      if (!_pendingMentions.any((m) => m['user_id'] == person['user_id'] && m['staff_id'] == person['staff_id'])) {
        _pendingMentions.add(person);
      }
    });
  }

  Future<void> _deleteComment(int index) async {
    final comment = _comments[index];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(AppStrings.of(context).communityDeleteTitle, style: const TextStyle(color: AppColors.textPrimary)),
        content: Text(AppStrings.of(context).communityDeleteComment, style: const TextStyle(color: AppColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(AppStrings.of(context).cancel)),
          TextButton(onPressed: () => Navigator.pop(context, true), child: Text(AppStrings.of(context).communityDeleteAction, style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    try {
      await widget.api.deleteCommunityComment(widget.post['id'] as String, comment['id'] as String);
      setState(() => _comments.removeAt(index));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(AppStrings.of(context).communityError(e.toString()))));
    }
  }

  Future<void> _send() async {
    final body = _controller.text.trim();
    if (body.isEmpty) return;
    setState(() => _sending = true);
    try {
      final comment = await widget.api.addCommunityCommentWithMentions(
        widget.post['id'] as String, body,
        mentions: _pendingMentions.isNotEmpty ? _pendingMentions : null,
      );
      _controller.clear();
      _pendingMentions.clear();
      setState(() => _comments.add(comment));
      widget.onCommentAdded(comment);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollCtrl.hasClients) {
          _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent, duration: const Duration(milliseconds: 200), curve: Curves.easeOut);
        }
      });
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      builder: (_, scrollCtrl) => Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 8),
            Container(width: 36, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Text(AppStrings.of(context).communityComments, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.textPrimary)),
            ),
            const Divider(height: 1, color: AppColors.border),
            Expanded(
              child: _comments.isEmpty
                  ? const Center(child: Text('Δεν υπάρχουν σχόλια', style: TextStyle(color: AppColors.textSecondary)))
                  : ListView.separated(
                      controller: _scrollCtrl,
                      padding: const EdgeInsets.all(16),
                      itemCount: _comments.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final c = _comments[i];
                        final isOwn = c['user_id'] == _myUserId;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(child: _CommentRow(comment: c, base: widget.base)),
                            if (isOwn)
                              GestureDetector(
                                onTap: () => _deleteComment(i),
                                child: const Padding(
                                  padding: EdgeInsets.only(left: 6, top: 4),
                                  child: Icon(Icons.delete_outline, size: 16, color: Colors.red),
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
            // @mention suggestions
            if (_mentionSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                decoration: BoxDecoration(color: AppColors.surfaceLight, border: Border(top: BorderSide(color: AppColors.border))),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (_, i) {
                    final p = _mentionSuggestions[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 14, backgroundColor: AppColors.lime.withValues(alpha: 0.15),
                        child: Text((p['full_name'] as String? ?? '?')[0], style: TextStyle(fontSize: 12, color: AppColors.lime, fontWeight: FontWeight.bold))),
                      title: Text(p['full_name'] as String? ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      subtitle: p['staff_id'] != null ? Text('Staff', style: TextStyle(color: AppColors.lime, fontSize: 11)) : null,
                      onTap: () => _insertMention(p),
                    );
                  },
                ),
              ),
            Padding(
              padding: EdgeInsets.only(left: 12, right: 12, bottom: MediaQuery.of(context).viewInsets.bottom + 12, top: 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      style: const TextStyle(color: AppColors.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Γράψε σχόλιο... (@ για mention)',
                        hintStyle: const TextStyle(color: AppColors.textSecondary),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                      ),
                      onSubmitted: (_) => _send(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: _sending
                        ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                        : const Icon(Icons.send_rounded, color: AppColors.lime),
                    onPressed: _sending ? null : _send,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── New Post Bottom Sheet ─────────────────────────────────────────────────────

class _NewPostSheet extends StatefulWidget {
  final ApiService api;
  final String base;
  const _NewPostSheet({required this.api, required this.base});

  @override
  State<_NewPostSheet> createState() => _NewPostSheetState();
}

class _NewPostSheetState extends State<_NewPostSheet> {
  final _controller = TextEditingController();
  List<Map<String, dynamic>> _media = [];
  List<Map<String, dynamic>> _mentionables = [];
  List<Map<String, dynamic>> _pendingMentions = [];
  List<Map<String, dynamic>> _mentionSuggestions = [];
  bool _uploading = false;
  bool _posting = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onTextChanged);
    widget.api.fetchCommunityMentionables().then((m) { if (mounted) setState(() => _mentionables = m); });
  }

  @override
  void dispose() {
    _controller.removeListener(_onTextChanged);
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    if (cursor < 0) return;
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    if (atIdx >= 0 && (atIdx == 0 || before[atIdx - 1] == ' ' || before[atIdx - 1] == '\n')) {
      final query = before.substring(atIdx + 1).toLowerCase();
      final suggestions = _mentionables
          .where((m) => (m['full_name'] as String? ?? '').toLowerCase().contains(query))
          .take(5)
          .toList();
      setState(() => _mentionSuggestions = suggestions);
    } else {
      setState(() => _mentionSuggestions = []);
    }
  }

  void _insertMention(Map<String, dynamic> person) {
    final text = _controller.text;
    final cursor = _controller.selection.baseOffset;
    final before = text.substring(0, cursor);
    final atIdx = before.lastIndexOf('@');
    final after = text.substring(cursor);
    final name = person['full_name'] as String;
    final newText = '${text.substring(0, atIdx)}@$name $after';
    _controller.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: atIdx + name.length + 2),
    );
    setState(() {
      _mentionSuggestions = [];
      if (!_pendingMentions.any((m) => m['user_id'] == person['user_id'] && m['staff_id'] == person['staff_id'])) {
        _pendingMentions.add(person);
      }
    });
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.surface,
      builder: (_) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(leading: const Icon(Icons.photo_library, color: AppColors.lime), title: Text('Από γκαλερί', style: TextStyle(color: AppColors.textPrimary)), onTap: () => Navigator.pop(context, 'gallery')),
          ListTile(leading: const Icon(Icons.camera_alt, color: AppColors.lime), title: Text('Κάμερα', style: TextStyle(color: AppColors.textPrimary)), onTap: () => Navigator.pop(context, 'camera')),
          ListTile(leading: const Icon(Icons.videocam, color: AppColors.lime), title: Text('Βίντεο', style: TextStyle(color: AppColors.textPrimary)), onTap: () => Navigator.pop(context, 'video')),
          const SizedBox(height: 16),
        ],
      ),
    );
    if (choice == null || !mounted) return;

    XFile? file;
    if (choice == 'video') {
      file = await picker.pickVideo(source: ImageSource.gallery);
    } else {
      file = await picker.pickImage(source: choice == 'camera' ? ImageSource.camera : ImageSource.gallery, imageQuality: 85);
    }
    if (file == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      // Upload via multipart to community endpoint
      final bytes = choice == 'video'
          ? await File(file.path).readAsBytes()
          : await prepareMessageImageBytes(file.path);
      final url = await widget.api.uploadCommunityMedia(bytes, choice == 'video' ? 'video.mp4' : 'photo.jpg');
      if (url != null && mounted) {
        setState(() => _media.add({'url': url, 'type': choice == 'video' ? 'video' : 'image'}));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e')));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _post() async {
    final body = _controller.text.trim();
    if (body.isEmpty && _media.isEmpty) return;
    setState(() => _posting = true);
    try {
      await widget.api.createCommunityPostWithMentions(body: body.isEmpty ? null : body, media: _media, mentions: _pendingMentions.isNotEmpty ? _pendingMentions : null);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e')));
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Text('Νέα ανάρτηση', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 17, color: AppColors.textPrimary)),
                const Spacer(),
                TextButton(
                  onPressed: _posting ? null : _post,
                  child: _posting
                      ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                      : Text('Δημοσίευση', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.lime)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _controller,
              maxLines: 5,
              minLines: 3,
              autofocus: true,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: 'Τι θες να μοιραστείς; (@ για mention)',
                hintStyle: const TextStyle(color: AppColors.textSecondary),
                filled: true,
                fillColor: AppColors.surfaceLight,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.all(12),
              ),
            ),
            if (_mentionSuggestions.isNotEmpty)
              Container(
                constraints: const BoxConstraints(maxHeight: 160),
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(color: AppColors.surfaceLight, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _mentionSuggestions.length,
                  itemBuilder: (_, i) {
                    final p = _mentionSuggestions[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(radius: 14, backgroundColor: AppColors.lime.withValues(alpha: 0.15),
                        child: Text((p['full_name'] as String? ?? '?')[0], style: TextStyle(fontSize: 12, color: AppColors.lime, fontWeight: FontWeight.bold))),
                      title: Text(p['full_name'] as String? ?? '', style: const TextStyle(color: AppColors.textPrimary, fontSize: 13)),
                      subtitle: p['staff_id'] != null ? Text('Staff', style: TextStyle(color: AppColors.lime, fontSize: 11)) : null,
                      onTap: () => _insertMention(p),
                    );
                  },
                ),
              ),
            if (_media.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 80,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: _media.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (_, i) => Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _media[i]['type'] == 'video'
                            ? Container(width: 80, height: 80, color: Colors.black, child: const Icon(Icons.play_circle, color: Colors.white, size: 36))
                            : Image.network('${widget.base}${_media[i]['url']}', width: 80, height: 80, fit: BoxFit.cover),
                      ),
                      Positioned(
                        top: 2, right: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _media.removeAt(i)),
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                            child: const Icon(Icons.close, color: Colors.white, size: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  icon: _uploading
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.lime))
                      : const Icon(Icons.image_outlined, color: AppColors.lime),
                  onPressed: _uploading ? null : _pickMedia,
                  tooltip: 'Προσθήκη εικόνας/βίντεο',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
