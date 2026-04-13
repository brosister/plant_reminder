import 'dart:io';

import 'package:flutter/material.dart';

class PlantPhotoThumb extends StatelessWidget {
  const PlantPhotoThumb({
    super.key,
    required this.assetId,
    this.width = 72,
    this.height = 72,
    this.borderRadius = 16,
  });

  final String assetId;
  final double width;
  final double height;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final file = File(assetId);
    if (!file.existsSync()) {
      return _fallback();
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Image.file(
        file,
        width: width,
        height: height,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        filterQuality: FilterQuality.medium,
        errorBuilder: (context, error, stackTrace) => _fallback(),
      ),
    );
  }

  Widget _fallback() {
    final logoSize = (width < height ? width : height) * 0.72;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(borderRadius * 0.72),
          child: SizedBox(
            width: logoSize,
            height: logoSize,
            child: Image.asset(
              'assets/branding/app_logo.png',
              fit: BoxFit.cover,
            ),
          ),
        ),
      ),
    );
  }
}
