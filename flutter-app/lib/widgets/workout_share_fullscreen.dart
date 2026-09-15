import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WorkoutShareFullscreen extends StatelessWidget {
  const WorkoutShareFullscreen({super.key, required this.imageFile});

  final File imageFile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Φωτογραφία προπόνησης'),
        systemOverlayStyle: SystemUiOverlayStyle.light,
      ),
      body: InteractiveViewer(
        minScale: 0.5,
        maxScale: 4,
        child: Center(
          child: Image.file(
            imageFile,
            fit: BoxFit.contain,
            width: double.infinity,
            height: double.infinity,
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Σύρε για zoom • Πάτα πίσω για κλείσιμο',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withValues(alpha: 0.6), fontSize: 13),
          ),
        ),
      ),
    );
  }
}

class WorkoutShareThumbnail extends StatelessWidget {
  const WorkoutShareThumbnail({
    super.key,
    required this.imageFile,
    required this.onTap,
  });

  final File imageFile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: AspectRatio(
          aspectRatio: 4 / 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.file(imageFile, fit: BoxFit.cover),
              Positioned(
                right: 10,
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.55),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.zoom_in, color: Colors.white, size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Μεγέθυνση',
                        style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
