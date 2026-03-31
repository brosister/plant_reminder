import 'package:flutter/material.dart';

import 'app_settings_service.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'plant_models.dart';
import 'plant_storage_service.dart';
import 'settings_tabs.dart';

void main() {
  runApp(const PlantReminderApp());
}

class PlantReminderApp extends StatelessWidget {
  const PlantReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '식물 물주기 알리미',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF2F855A)),
        scaffoldBackgroundColor: const Color(0xFFF6FBF7),
        useMaterial3: true,
      ),
      home: const PlantRootPage(),
    );
  }
}

class PlantRootPage extends StatefulWidget {
  const PlantRootPage({super.key});

  @override
  State<PlantRootPage> createState() => _PlantRootPageState();
}

class _PlantRootPageState extends State<PlantRootPage> {
  int _currentIndex = 0;
  AppAuthUser? _authUser;
  bool _isSigningIn = false;
  bool _isLoading = true;
  AppSettings _settings = const AppSettings(
    notificationsEnabled: true,
    notificationHour: 9,
    notificationMinute: 0,
  );

  final List<PlantItem> _plants = [
    PlantItem(
      id: 'p1',
      name: '거실 몬스테라',
      type: '몬스테라',
      location: '거실 창가',
      wateringCycleDays: 5,
      lastWateredAt: DateTime.now().subtract(const Duration(days: 5)),
      memo: '새 잎이 올라오는 중. 흙 마름 빠름.',
      sunlight: '밝은 간접광',
    ),
    PlantItem(
      id: 'p2',
      name: '책상 스투키',
      type: '스투키',
      location: '작업실 책상',
      wateringCycleDays: 14,
      lastWateredAt: DateTime.now().subtract(const Duration(days: 9)),
      memo: '과습 주의. 흙 완전히 마를 때 확인.',
      sunlight: '밝은 곳',
    ),
    PlantItem(
      id: 'p3',
      name: '주방 허브',
      type: '허브',
      location: '주방 창문 옆',
      wateringCycleDays: 3,
      lastWateredAt: DateTime.now().subtract(const Duration(days: 4)),
      memo: '잎 상태 자주 보기. 햇빛 충분히 받게 두기.',
      sunlight: '햇빛 필요',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    await FirebaseService.init();
    await NotificationService.init();
    final stored = await PlantStorageService.loadPlants();
    final loadedSettings = await AppSettingsService.load();
    if (stored.isNotEmpty) {
      _plants
        ..clear()
        ..addAll(stored);
    }
    _settings = loadedSettings;
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _persistPlants() async {
    await PlantStorageService.savePlants(_plants);
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
  }

  void _markWatered(PlantItem plant) {
    setState(() {
      plant.lastWateredAt = DateTime.now();
    });
    _persistPlants();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${plant.name} 물주기 완료')),
    );
  }

  void _savePlant(PlantItem plant, {bool isNew = false}) {
    setState(() {
      if (isNew) {
        _plants.add(plant);
      } else {
        final index = _plants.indexWhere((item) => item.id == plant.id);
        if (index != -1) {
          _plants[index] = plant;
        }
      }
    });
    _persistPlants();
  }

  Future<void> _openAddPlantSheet() async {
    final created = await showModalBottomSheet<PlantItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => const PlantEditSheet(),
    );
    if (created != null) {
      _savePlant(created, isNew: true);
    }
  }

  Future<void> _openEditPlantSheet(PlantItem plant) async {
    final updated = await showModalBottomSheet<PlantItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PlantEditSheet(existing: plant.copy()),
    );
    if (updated != null) {
      _savePlant(updated);
    }
  }

  Future<void> _showSettingsDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return SettingsDialog(
          authUser: _authUser,
          isSigningIn: _isSigningIn,
          settings: _settings,
          onSignInPressed: _handlePlatformSignIn,
          onSignOutPressed: _handleSignOut,
          onSettingsChanged: _handleSettingsChanged,
        );
      },
    );
  }

  Future<void> _handleSettingsChanged(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await AppSettingsService.save(settings);
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
  }

  Future<void> _handlePlatformSignIn() async {
    if (_isSigningIn) return;
    setState(() {
      _isSigningIn = true;
    });
    try {
      final user = await AuthService.instance.signInForCurrentPlatform();
      if (!mounted) return;
      if (user != null) {
        setState(() {
          _authUser = user;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${user.provider == 'google' ? '구글' : '애플'} 로그인 성공')),
        );
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('로그인에 실패했습니다: $error')),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSigningIn = false;
        });
      }
    }
  }

  Future<void> _handleSignOut() async {
    await AuthService.instance.signOut(provider: _authUser?.provider);
    if (!mounted) return;
    setState(() {
      _authUser = null;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('로그아웃 되었습니다.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      HomeTab(plants: _plants, onTapPlant: _openEditPlantSheet, onMarkWatered: _markWatered),
      MyPlantsTab(plants: _plants, onTapPlant: _openEditPlantSheet, onAddPlant: _openAddPlantSheet),
      CalendarTab(plants: _plants),
      StatsTab(plants: _plants),
    ];

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF6FBF7),
        title: Text(_navTitle(_currentIndex)),
        actions: [
          IconButton(
            onPressed: _showSettingsDialog,
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
          ),
        ],
      ),
      body: SafeArea(child: pages[_currentIndex]),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton.extended(
              onPressed: _openAddPlantSheet,
              icon: const Icon(Icons.add),
              label: const Text('식물 등록'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (value) => setState(() => _currentIndex = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(icon: Icon(Icons.local_florist_outlined), selectedIcon: Icon(Icons.local_florist), label: '나의 식물'),
          NavigationDestination(icon: Icon(Icons.calendar_month_outlined), selectedIcon: Icon(Icons.calendar_month), label: '달력'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: '통계'),
        ],
      ),
    );
  }
}

class HomeTab extends StatelessWidget {
  const HomeTab({
    super.key,
    required this.plants,
    required this.onTapPlant,
    required this.onMarkWatered,
  });

  final List<PlantItem> plants;
  final ValueChanged<PlantItem> onTapPlant;
  final ValueChanged<PlantItem> onMarkWatered;

  @override
  Widget build(BuildContext context) {
    final todayTasks = plants.where((plant) => plant.status == PlantStatus.today || plant.status == PlantStatus.overdue).toList();
    final soonTasks = plants.where((plant) => plant.status == PlantStatus.soon).toList();
    final healthyCount = plants.where((plant) => plant.status == PlantStatus.healthy).length;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2F855A),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('식집사 루틴', style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      const Text('오늘 해야 할 식물 관리', style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(
                        todayTasks.isEmpty ? '오늘 급하게 관리할 식물은 없어요. 곧 필요한 식물만 체크해보세요.' : '오늘 바로 확인할 식물 ${todayTasks.length}개가 있어요.',
                        style: const TextStyle(color: Colors.white70, height: 1.4),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          _HeroStatChip(label: '오늘 관리', value: '${todayTasks.length}개'),
                          _HeroStatChip(label: '곧 필요', value: '${soonTasks.length}개'),
                          _HeroStatChip(label: '안정 상태', value: '$healthyCount개'),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const _SectionTitle(title: '오늘 해야 할 일', subtitle: '물을 줘야 하거나 이미 늦은 식물들입니다.'),
                const SizedBox(height: 12),
                if (todayTasks.isEmpty)
                  const EmptyCard(message: '오늘 바로 처리할 식물은 없습니다.')
                else
                  ...todayTasks.map(
                    (plant) => PlantActionCard(
                      plant: plant,
                      onTap: () => onTapPlant(plant),
                      onMarkWatered: () => onMarkWatered(plant),
                    ),
                  ),
                const SizedBox(height: 20),
                const _SectionTitle(title: '곧 확인할 식물', subtitle: '내일 전후로 물주기가 다가오는 식물들입니다.'),
                const SizedBox(height: 12),
                if (soonTasks.isEmpty)
                  const EmptyCard(message: '곧 물줄 식물이 아직 없습니다.')
                else
                  ...soonTasks.map((plant) => CompactPlantCard(plant: plant, onTap: () => onTapPlant(plant))),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class MyPlantsTab extends StatelessWidget {
  const MyPlantsTab({
    super.key,
    required this.plants,
    required this.onTapPlant,
    required this.onAddPlant,
  });

  final List<PlantItem> plants;
  final ValueChanged<PlantItem> onTapPlant;
  final VoidCallback onAddPlant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('나의 식물', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text('내 식물을 등록하고 메모와 물주기 주기를 관리하세요.', style: TextStyle(color: Colors.black54)),
                  ],
                ),
              ),
              IconButton.filledTonal(onPressed: onAddPlant, icon: const Icon(Icons.add)),
            ],
          ),
          const SizedBox(height: 20),
          Expanded(
            child: ListView.separated(
              itemCount: plants.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final plant = plants[index];
                return PlantListCard(plant: plant, onTap: () => onTapPlant(plant));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CalendarTab extends StatelessWidget {
  const CalendarTab({super.key, required this.plants});

  final List<PlantItem> plants;

  @override
  Widget build(BuildContext context) {
    final sorted = [...plants]..sort((a, b) => a.nextWateringAt.compareTo(b.nextWateringAt));

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('달력', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('다음 물주기 일정을 날짜 순으로 확인합니다.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Expanded(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: ListView(
                children: [
                  Text('${_monthLabel(DateTime.now())} 관리 예정', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),
                  ...sorted.map(
                    (plant) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 52,
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              color: _statusColor(plant.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Text('${plant.nextWateringAt.day}', style: TextStyle(color: _statusColor(plant.status), fontWeight: FontWeight.bold, fontSize: 18)),
                                Text(_weekdayKor(plant.nextWateringAt.weekday), style: TextStyle(color: _statusColor(plant.status), fontSize: 12)),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(plant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(height: 4),
                                Text('${plant.type} · ${plant.location}', style: const TextStyle(color: Colors.black54)),
                              ],
                            ),
                          ),
                          Text(_statusText(plant.status), style: TextStyle(color: _statusColor(plant.status), fontWeight: FontWeight.w700)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class StatsTab extends StatelessWidget {
  const StatsTab({super.key, required this.plants});

  final List<PlantItem> plants;

  @override
  Widget build(BuildContext context) {
    final total = plants.length;
    final healthy = plants.where((plant) => plant.status == PlantStatus.healthy).length;
    final dueToday = plants.where((plant) => plant.status == PlantStatus.today).length;
    final overdue = plants.where((plant) => plant.status == PlantStatus.overdue).length;
    final avgCycle = plants.isEmpty ? 0 : (plants.map((plant) => plant.wateringCycleDays).reduce((a, b) => a + b) / plants.length).round();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        children: [
          const Text('통계', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          const Text('식물 관리 흐름을 숫자로 빠르게 확인하세요.', style: TextStyle(color: Colors.black54)),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              StatCard(title: '등록 식물', value: '$total개', color: const Color(0xFF2F855A)),
              StatCard(title: '안정 상태', value: '$healthy개', color: const Color(0xFF2B9348)),
              StatCard(title: '오늘 물주기', value: '$dueToday개', color: const Color(0xFFF59E0B)),
              StatCard(title: '오래 방치', value: '$overdue개', color: const Color(0xFFDC2626)),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('물주기 주기 분포', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ...plants.map((plant) {
                  final ratio = (plant.wateringCycleDays / 21).clamp(0.1, 1.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(plant.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                            Text('${plant.wateringCycleDays}일 주기'),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(99),
                          child: LinearProgressIndicator(
                            value: ratio,
                            minHeight: 10,
                            backgroundColor: const Color(0xFFE5E7EB),
                            color: _statusColor(plant.status),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 28),
                Text('평균 물주기 주기: ${avgCycle == 0 ? '-' : '$avgCycle일'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PlantEditSheet extends StatefulWidget {
  const PlantEditSheet({super.key, this.existing});

  final PlantItem? existing;

  @override
  State<PlantEditSheet> createState() => _PlantEditSheetState();
}

class _PlantEditSheetState extends State<PlantEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _memoController;
  late final TextEditingController _cycleController;
  late PlantPreset _selectedPreset;
  late DateTime _lastWateredAt;

  @override
  void initState() {
    super.initState();
    final current = widget.existing;
    _selectedPreset = kPlantPresets.firstWhere(
      (preset) => preset.type == current?.type,
      orElse: () => kPlantPresets.first,
    );
    _nameController = TextEditingController(text: current?.name ?? '');
    _locationController = TextEditingController(text: current?.location ?? '');
    _memoController = TextEditingController(text: current?.memo ?? _selectedPreset.tip);
    _cycleController = TextEditingController(text: '${current?.wateringCycleDays ?? _selectedPreset.defaultWateringCycleDays}');
    _lastWateredAt = current?.lastWateredAt ?? DateTime.now();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    _cycleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.existing == null ? '식물 등록' : '식물 수정', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('나의 식물을 등록하고 물주기 주기와 메모를 설정하세요.', style: TextStyle(color: Colors.black54)),
            const SizedBox(height: 20),
            DropdownButtonFormField<PlantPreset>(
              initialValue: _selectedPreset,
              decoration: _inputDecoration('식물 종류'),
              items: kPlantPresets.map((preset) => DropdownMenuItem(value: preset, child: Text('${preset.type} · ${preset.tip}'))).toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _selectedPreset = value;
                  if (_nameController.text.trim().isEmpty) {
                    _nameController.text = value.type;
                  }
                  _cycleController.text = '${value.defaultWateringCycleDays}';
                });
              },
            ),
            const SizedBox(height: 14),
            TextField(controller: _nameController, decoration: _inputDecoration('나의 식물 이름')),
            const SizedBox(height: 14),
            TextField(controller: _locationController, decoration: _inputDecoration('위치')),
            const SizedBox(height: 14),
            TextField(controller: _cycleController, keyboardType: TextInputType.number, decoration: _inputDecoration('물주기 주기 (일)')),
            const SizedBox(height: 14),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('마지막 물준 날짜'),
              subtitle: Text(_dateLabel(_lastWateredAt)),
              trailing: const Icon(Icons.calendar_today_outlined),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _lastWateredAt,
                  firstDate: DateTime(2024),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  setState(() {
                    _lastWateredAt = picked;
                  });
                }
              },
            ),
            const SizedBox(height: 14),
            TextField(controller: _memoController, maxLines: 4, decoration: _inputDecoration('식물 메모')),
            const SizedBox(height: 10),
            Text('햇빛 추천: ${_selectedPreset.sunlight}', style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () {
                final cycle = int.tryParse(_cycleController.text.trim()) ?? _selectedPreset.defaultWateringCycleDays;
                final plant = PlantItem(
                  id: widget.existing?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
                  name: _nameController.text.trim().isEmpty ? _selectedPreset.type : _nameController.text.trim(),
                  type: _selectedPreset.type,
                  location: _locationController.text.trim().isEmpty ? '위치 미입력' : _locationController.text.trim(),
                  wateringCycleDays: cycle,
                  lastWateredAt: _lastWateredAt,
                  memo: _memoController.text.trim().isEmpty ? _selectedPreset.tip : _memoController.text.trim(),
                  sunlight: _selectedPreset.sunlight,
                );
                Navigator.of(context).pop(plant);
              },
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              child: Text(widget.existing == null ? '식물 등록하기' : '수정 내용 저장'),
            ),
          ],
        ),
      ),
    );
  }
}

class PlantActionCard extends StatelessWidget {
  const PlantActionCard({super.key, required this.plant, required this.onTap, required this.onMarkWatered});

  final PlantItem plant;
  final VoidCallback onTap;
  final VoidCallback onMarkWatered;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(plant.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plant.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Text('${plant.type} · ${plant.location}'),
                  ],
                ),
              ),
              StatusChip(status: plant.status),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plant.status == PlantStatus.overdue ? '${plant.daysUntilWatering.abs()}일 지났어요. 지금 물주기를 권장합니다.' : '오늘 물줄 차례입니다. 체크 후 다음 일정이 자동 계산됩니다.',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onTap, child: const Text('상세 / 메모'))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: onMarkWatered, child: const Text('물 줬어요'))),
            ],
          ),
        ],
      ),
    );
  }
}

class CompactPlantCard extends StatelessWidget {
  const CompactPlantCard({super.key, required this.plant, required this.onTap});

  final PlantItem plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _statusColor(plant.status).withValues(alpha: 0.15),
              child: Icon(Icons.local_florist, color: _statusColor(plant.status)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plant.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text('${plant.daysUntilWatering}일 후 · ${plant.location}'),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}

class PlantListCard extends StatelessWidget {
  const PlantListCard({super.key, required this.plant, required this.onTap});

  final PlantItem plant;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(plant.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text('${plant.type} · ${plant.location}'),
                    ],
                  ),
                ),
                StatusChip(status: plant.status),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(child: _InfoTile(label: '다음 물주기', value: _dateLabel(plant.nextWateringAt))),
                const SizedBox(width: 10),
                Expanded(child: _InfoTile(label: '주기', value: '${plant.wateringCycleDays}일')),
              ],
            ),
            const SizedBox(height: 12),
            Text(plant.memo, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.black54, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  const StatusChip({super.key, required this.status});

  final PlantStatus status;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(999)),
      child: Text(_statusText(status), style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}

class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.title, required this.value, required this.color});

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Text(value, style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

class EmptyCard extends StatelessWidget {
  const EmptyCard({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Text(message, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({super.key, required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F5EC),
            child: Icon(icon, color: const Color(0xFF2F855A)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroStatChip extends StatelessWidget {
  const _HeroStatChip({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: const Color(0xFFF3F6F4), borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: Colors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(18),
      borderSide: BorderSide.none,
    ),
  );
}

Color _statusColor(PlantStatus status) {
  switch (status) {
    case PlantStatus.healthy:
      return const Color(0xFF2B9348);
    case PlantStatus.soon:
      return const Color(0xFFF59E0B);
    case PlantStatus.today:
      return const Color(0xFFEA580C);
    case PlantStatus.overdue:
      return const Color(0xFFDC2626);
  }
}

String _statusText(PlantStatus status) {
  switch (status) {
    case PlantStatus.healthy:
      return '안정';
    case PlantStatus.soon:
      return '곧 필요';
    case PlantStatus.today:
      return '오늘 물주기';
    case PlantStatus.overdue:
      return '오래 방치';
  }
}

String _dateLabel(DateTime date) {
  return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
}

String _weekdayKor(int weekday) {
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  return labels[weekday - 1];
}

String _monthLabel(DateTime date) {
  return '${date.year}년 ${date.month}월';
}

String _navTitle(int index) {
  switch (index) {
    case 0:
      return '식물 물주기 알리미';
    case 1:
      return '나의 식물';
    case 2:
      return '달력';
    case 3:
      return '통계';
    default:
      return '식물 물주기 알리미';
  }
}
