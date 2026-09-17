import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/tenant_config.dart';
import '../theme/app_colors.dart';
import '../utils/media_url.dart';
import '../utils/message_content.dart';
import 'image_lightbox.dart';

class MessageBubbleContent extends StatelessWidget {
  const MessageBubbleContent({
    super.key,
    required this.body,
    this.messageType,
    this.attachmentUrl,
  });

  final String body;
  final String? messageType;
  final String? attachmentUrl;

  Future<void> _openUrl(String url) async {
    final uri = Uri.tryParse(url);
    if (uri == null) return;
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final config = context.read<TenantConfig>();

    if (messageType == 'image') {
      if (attachmentUrl == null || attachmentUrl!.isEmpty) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Η εικόνα δεν είναι πια διαθέσιμη (έληξε μετά από 24 ώρες)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontStyle: FontStyle.italic,
              ),
            ),
            if (body.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _buildText(context, body),
            ],
          ],
        );
      }

      final imageUrl = resolveMediaUrl(config, attachmentUrl!) ?? attachmentUrl!;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: GestureDetector(
              onTap: () => ImageLightbox.show(context, imageUrl),
              child: Image.network(
                imageUrl,
                width: 220,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(
                  width: 220,
                  height: 140,
                  color: AppColors.surfaceLight,
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                ),
              ),
            ),
          ),
          if (body.trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            _buildText(context, body),
          ],
        ],
      );
    }

    return _buildText(context, body);
  }

  Widget _buildText(BuildContext context, String text) {
    final segments = splitMessageSegments(text);
    final spans = <InlineSpan>[];

    for (final seg in segments) {
      if (seg.type == MessageSegmentType.text) {
        spans.add(TextSpan(text: seg.value));
        continue;
      }
      if (seg.type == MessageSegmentType.youtube) {
        spans.add(const TextSpan(text: '\n'));
        spans.add(WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: _YouTubePreview(videoId: seg.videoId!, url: seg.value),
          ),
        ));
        spans.add(const TextSpan(text: '\n'));
        continue;
      }
      spans.add(TextSpan(
        text: seg.value,
        style: TextStyle(color: AppColors.lime, decoration: TextDecoration.underline),
        recognizer: TapGestureRecognizer()..onTap = () => _openUrl(seg.value),
      ));
    }

    return SelectableText.rich(
      TextSpan(
        style: const TextStyle(color: AppColors.textPrimary, height: 1.4),
        children: spans,
      ),
    );
  }
}

class _YouTubePreview extends StatelessWidget {
  const _YouTubePreview({required this.videoId, required this.url});

  final String videoId;
  final String url;

  @override
  Widget build(BuildContext context) {
    final thumb = 'https://img.youtube.com/vi/$videoId/hqdefault.jpg';
    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(url);
        if (uri != null) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      child: Container(
        width: 220,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
          color: AppColors.surfaceLight,
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                Image.network(
                  thumb,
                  height: 124,
                  width: 220,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 124,
                    color: AppColors.surface,
                    child: const Icon(Icons.play_circle_outline, size: 48, color: AppColors.textSecondary),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(
                'YouTube',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
