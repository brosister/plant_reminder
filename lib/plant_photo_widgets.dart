import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

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
    return FutureBuilder<AssetEntity?>(
      future: AssetEntity.fromId(assetId),
      builder: (context, snapshot) {
        final entity = snapshot.data;
        if (entity == null) {
          return _fallback();
        }
        return FutureBuilder<Uint8List?>(
          future: entity.thumbnailDataWithSize(const ThumbnailSize(300, 300)),
          builder: (context, thumbSnapshot) {
            final data = thumbSnapshot.data;
            if (data == null) return _fallback();
            return ClipRRect(
              borderRadius: BorderRadius.circular(borderRadius),
              child: Image.memory(
                data,
                width: width,
                height: height,
                fit: BoxFit.cover,
              ),
            );
          },
        );
      },
    );
  }

  Widget _fallback() {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFE5E7EB),
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: const Icon(Icons.local_florist, color: Color(0xFF2F855A)),
    );
  }
}
