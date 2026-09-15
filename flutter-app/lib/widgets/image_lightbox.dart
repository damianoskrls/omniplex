import 'package:flutter/material.dart';

class ImageLightbox extends StatelessWidget {
  const ImageLightbox({super.key, required this.imageUrl});

  final String imageUrl;

  static Future<void> show(BuildContext context, String imageUrl) {
    return showDialog<void>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (_) => ImageLightbox(imageUrl: imageUrl),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Stack(
        alignment: Alignment.center,
        children: [
          InteractiveViewer(
            minScale: 0.8,
            maxScale: 4,
            child: Image.network(
              imageUrl,
              fit: BoxFit.contain,
              loadingBuilder: (_, child, progress) {
                if (progress == null) return child;
                return const SizedBox(
                  width: 48,
                  height: 48,
                  child: CircularProgressIndicator(color: Colors.white),
                );
              },
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white70,
                size: 64,
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close, color: Colors.white, size: 28),
              style: IconButton.styleFrom(
                backgroundColor: Colors.black45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
