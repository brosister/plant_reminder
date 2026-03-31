import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'plant_models.dart';
import 'plant_photo_widgets.dart';

class PlantDetailPage extends StatelessWidget {
  const PlantDetailPage({
    super.key,
    required this.plant,
    required this.onEdit,
    required this.onWatered,
  });

  final PlantItem plant;
  final VoidCallback onEdit;
  final VoidCallback onWatered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFF6FBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6FBF7),
        title: Text(plant.name),
        actions: [
          IconButton(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined),
            tooltip: l10n.edit,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 120),
        children: [
          if (plant.photoAssetIds.isNotEmpty)
            SizedBox(
              height: 220,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plant.photoAssetIds.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final assetId = plant.photoAssetIds[index];
                  return GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PlantPhotoGalleryPage(
                            assetIds: plant.photoAssetIds,
                            initialIndex: index,
                          ),
                        ),
                      );
                    },
                    child: Stack(
                      children: [
                        PlantPhotoThumb(
                          assetId: assetId,
                          width: 280,
                          height: 220,
                          borderRadius: 24,
                        ),
                        if (index == 0)
                          Positioned(
                            left: 12,
                            top: 12,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                l10n.representativePhoto,
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            )
          else
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Center(
                child: Text(l10n.noPlantPhoto, style: const TextStyle(color: Colors.black54)),
              ),
            ),
          const SizedBox(height: 20),
          _DetailCard(
            title: l10n.basicInfo,
            child: Column(
              children: [
                _DetailRow(label: l10n.plantType, value: plant.type),
                _DetailRow(label: l10n.location, value: plant.location),
                _DetailRow(label: l10n.sunlight, value: plant.sunlight),
                _DetailRow(label: l10n.wateringCycle, value: l10n.cycleDays(plant.wateringCycleDays)),
                _DetailRow(label: l10n.lastWateredDate, value: l10n.dateLabel(plant.lastWateredAt)),
                _DetailRow(label: l10n.nextWatering, value: l10n.dateLabel(plant.nextWateringAt), isLast: true),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _DetailCard(
            title: l10n.memo,
            child: Text(
              plant.memo.isEmpty ? l10n.noMemo : plant.memo,
              style: const TextStyle(height: 1.6, color: Colors.black87),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: onWatered,
            icon: const Icon(Icons.water_drop_outlined),
            label: Text(l10n.markWatered),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
          ),
        ],
      ),
    );
  }
}

class PlantPhotoGalleryPage extends StatelessWidget {
  const PlantPhotoGalleryPage({
    super.key,
    required this.assetIds,
    required this.initialIndex,
  });

  final List<String> assetIds;
  final int initialIndex;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final controller = PageController(initialPage: initialIndex);
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text(l10n.photoIndexLabel(initialIndex + 1, assetIds.length)),
      ),
      body: PageView.builder(
        controller: controller,
        itemCount: assetIds.length,
        itemBuilder: (context, index) {
          return Center(
            child: InteractiveViewer(
              child: PlantPhotoThumb(
                assetId: assetIds[index],
                width: MediaQuery.of(context).size.width,
                height: MediaQuery.of(context).size.height * 0.72,
                borderRadius: 0,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  const _DetailCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value, this.isLast = false});

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(label, style: const TextStyle(color: Colors.black54)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
