enum MessageSegmentType { text, link, youtube }

class MessageSegment {
  const MessageSegment({
    required this.type,
    required this.value,
    this.videoId,
  });

  final MessageSegmentType type;
  final String value;
  final String? videoId;
}

final _urlRegex = RegExp(
  r'(https?:\/\/[^\s<]+[^\s<.,;:!?)\]}' "'" r'"])',
  caseSensitive: false,
);

final _youtubeRegex = RegExp(
  r'(?:https?:\/\/)?(?:www\.)?(?:youtube\.com\/(?:watch\?v=|embed\/|shorts\/)|youtu\.be\/)([a-zA-Z0-9_-]{11})',
  caseSensitive: false,
);

String? extractYouTubeId(String url) {
  final match = _youtubeRegex.firstMatch(url);
  return match?.group(1);
}

List<MessageSegment> splitMessageSegments(String text) {
  if (text.isEmpty) return [];

  final segments = <MessageSegment>[];
  var lastIndex = 0;

  for (final match in _urlRegex.allMatches(text)) {
    if (match.start > lastIndex) {
      segments.add(MessageSegment(
        type: MessageSegmentType.text,
        value: text.substring(lastIndex, match.start),
      ));
    }
    final url = match.group(0)!;
    final videoId = extractYouTubeId(url);
    segments.add(MessageSegment(
      type: videoId != null ? MessageSegmentType.youtube : MessageSegmentType.link,
      value: url,
      videoId: videoId,
    ));
    lastIndex = match.end;
  }

  if (lastIndex < text.length) {
    segments.add(MessageSegment(
      type: MessageSegmentType.text,
      value: text.substring(lastIndex),
    ));
  }

  return segments.isEmpty
      ? [MessageSegment(type: MessageSegmentType.text, value: text)]
      : segments;
}

const commonEmojis = [
  '😀', '😂', '😊', '😍', '🥰', '😎', '🤔', '😅', '🙏', '👍',
  '👏', '💪', '🔥', '✅', '❤️', '🎉', '⭐', '💯', '🏋️', '🥗',
  '📅', '📷', '💬', '👋', '🙂', '😢', '😡', '🤝', '✨', '🚀',
];
