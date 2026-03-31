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

  static final Map<String, Future<AssetEntity?>> _entityFutures = <String, Future<AssetEntity?>>{};
  static final Map<String, Future<Uint8List?>> _thumbnailFutures = <String, Future<Uint8List?>>{};

  @override
  Widget build(BuildContext context) {
    final cacheWidth = width.isFinite ? width.round().clamp(1, 512) : 300;
    final cacheHeight = height.isFinite ? height.round().clamp(1, 512) : 300;
    final entityFuture = _entityFutures.putIfAbsent(assetId, () => AssetEntity.fromId(assetId));

    return FutureBuilder<AssetEntity?>(
      future: entityFuture,
      builder: (context, snapshot) {
        final entity = snapshot.data;
        if (entity == null) {
          return _fallback();
        }
        final thumbKey = '$assetId:$cacheWidth:$cacheHeight';
        final thumbFuture = _thumbnailFutures.putIfAbsent(
          thumbKey,
          () => entity.thumbnailDataWithSize(ThumbnailSize(cacheWidth, cacheHeight)),
        );
        return FutureBuilder<Uint8List?>(
          future: thumbFuture,
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
                gaplessPlayback: true,
                filterQuality: FilterQuality.medium,
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
