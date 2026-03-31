import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:photo_manager/photo_manager.dart';

class PhotoPickerPage extends StatefulWidget {
  const PhotoPickerPage({super.key, required this.initialSelectedIds});

  final List<String> initialSelectedIds;

  @override
  State<PhotoPickerPage> createState() => _PhotoPickerPageState();
}

class _PhotoPickerPageState extends State<PhotoPickerPage> {
  final List<AssetEntity> _assets = [];
  final Set<String> _selectedIds = {};
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _selectedIds.addAll(widget.initialSelectedIds);
    _loadAssets();
  }

  Future<void> _loadAssets() async {
    final permission = await PhotoManager.requestPermissionExtend();
    if (!permission.isAuth && !permission.hasAccess) {
      setState(() {
        _isLoading = false;
        _error = '사진 접근 권한이 필요합니다.';
      });
      return;
    }

    final albums = await PhotoManager.getAssetPathList(
      type: RequestType.image,
      onlyAll: true,
      filterOption: FilterOptionGroup(
        imageOption: const FilterOption(sizeConstraint: SizeConstraint(ignoreSize: true)),
      ),
    );

    if (albums.isEmpty) {
      setState(() {
        _isLoading = false;
        _error = '표시할 사진이 없습니다.';
      });
      return;
    }

    final recent = albums.first;
    final assets = await recent.getAssetListPaged(page: 0, size: 200);
    setState(() {
      _assets
        ..clear()
        ..addAll(assets);
      _isLoading = false;
    });
  }

  void _toggleAsset(AssetEntity asset) {
    setState(() {
      if (_selectedIds.contains(asset.id)) {
        _selectedIds.remove(asset.id);
      } else {
        _selectedIds.add(asset.id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('식물 사진 선택'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(_selectedIds.toList()),
            child: Text(
              '완료 (${_selectedIds.length})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, style: const TextStyle(color: Colors.white70)),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadAssets,
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          color: Colors.black,
          child: const Text(
            '여러 장을 선택할 수 있습니다. 식물 대표 사진과 기록 사진으로 활용됩니다.',
            style: TextStyle(color: Colors.white70, height: 1.4),
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(4),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 4,
              mainAxisSpacing: 4,
            ),
            itemCount: _assets.length,
            itemBuilder: (context, index) {
              final asset = _assets[index];
              final selected = _selectedIds.contains(asset.id);
              return GestureDetector(
                onTap: () => _toggleAsset(asset),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _AssetThumb(asset: asset),
                    if (selected)
                      Container(
                        color: Colors.green.withValues(alpha: 0.28),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          color: selected ? const Color(0xFF22C55E) : Colors.black54,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Icon(
                          selected ? Icons.check : Icons.add,
                          color: Colors.white,
                          size: 16,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AssetThumb extends StatelessWidget {
  const _AssetThumb({required this.asset});

  final AssetEntity asset;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: asset.thumbnailDataWithSize(const ThumbnailSize(400, 400)),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Container(color: const Color(0xFF1F2937));
        }
        final data = snapshot.data;
        if (data == null) {
          return Container(
            color: const Color(0xFF1F2937),
            child: const Icon(Icons.image_not_supported_outlined, color: Colors.white54),
          );
        }
        return Image.memory(data, fit: BoxFit.cover);
      },
    );
  }
}
