import 'package:flutter/material.dart';
import 'package:fluttertoast/fluttertoast.dart';

import 'app_settings_service.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'photo_picker_page.dart';
import 'plant_detail_page.dart';
import 'plant_models.dart';
import 'plant_photo_widgets.dart';
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
        dialogTheme: DialogThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFF6FBF7),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          hourMinuteShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          dayPeriodShape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
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
      photoAssetIds: const [],
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

  void _showToast(String message) {
    Fluttertoast.cancel();
    Fluttertoast.showToast(msg: message, gravity: ToastGravity.BOTTOM);
  }

  void _markWatered(PlantItem plant) {
    setState(() {
      plant.lastWateredAt = DateTime.now();
    });
    _persistPlants();
    _showToast('${plant.name} 물주기 완료');
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

  Future<void> _openPlantDetail(PlantItem plant) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (detailContext) => PlantDetailPage(
          plant: plant,
          onEdit: () async {
            Navigator.of(detailContext).pop();
            await _openEditPlantSheet(plant);
          },
          onWatered: () {
            _markWatered(plant);
            Navigator.of(detailContext).pop();
          },
        ),
      ),
    );
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
        _showToast('${user.provider == 'google' ? '구글' : '애플'} 로그인 성공');
      }
    } catch (error) {
      if (!mounted) return;
      _showToast('로그인에 실패했습니다.');
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
    _showToast('로그아웃 되었습니다.');
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final pages = [
      HomeTab(plants: _plants, onTapPlant: _openPlantDetail, onMarkWatered: _markWatered),
      MyPlantsTab(plants: _plants, onTapPlant: _openPlantDetail, onAddPlant: _openAddPlantSheet),
      CalendarTab(plants: _plants),
      StatsTab(plants: _plants),
    ];
    final navItems = [
      const _NavItemData(
        label: '홈',
        subtitle: '오늘 할 일을 먼저 챙겨봐요.',
        icon: Icons.home_rounded,
        color: Color(0xFF53B97C),
      ),
      const _NavItemData(
        label: '나의 식물',
        subtitle: '내 식물을 등록하고 메모와 물주기 주기를 관리하세요.',
        icon: Icons.local_florist_rounded,
        color: Color(0xFF5BC0A5),
      ),
      const _NavItemData(
        label: '달력',
        subtitle: '다음 물주기 일정을 날짜 순으로 확인합니다.',
        icon: Icons.calendar_month_rounded,
        color: Color(0xFFFFB648),
      ),
      const _NavItemData(
        label: '통계',
        subtitle: '식물 관리 흐름을 숫자로 빠르게 확인하세요.',
        icon: Icons.bar_chart_rounded,
        color: Color(0xFFFF8E72),
      ),
    ];
    final activeNav = navItems[_currentIndex];

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 92,
        backgroundColor: const Color(0xFFF6FBF7),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              activeNav.label,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              activeNav.subtitle,
              style: const TextStyle(color: Colors.black54, fontSize: 13, height: 1.3),
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: IconButton(
              onPressed: _showSettingsDialog,
              icon: const Icon(Icons.settings_rounded),
              tooltip: '설정',
            ),
          ),
        ],
      ),
      body: SafeArea(child: pages[_currentIndex]),
      floatingActionButton: _currentIndex == 1
          ? FloatingActionButton(
              onPressed: _openAddPlantSheet,
              backgroundColor: const Color(0xFF2F855A),
              foregroundColor: Colors.white,
              elevation: 0,
              highlightElevation: 0,
              hoverElevation: 0,
              focusElevation: 0,
              disabledElevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              child: const Icon(Icons.add_rounded, size: 30),
            )
          : null,
      bottomNavigationBar: _GardenBottomNav(
        items: navItems,
        selectedIndex: _currentIndex,
        onSelected: (value) => setState(() => _currentIndex = value),
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
    final streakMessage = todayTasks.isEmpty ? '오늘은 한결 여유로운 날이에요.' : '지금 챙기면 식물 컨디션을 더 예쁘게 유지할 수 있어요.';

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: const LinearGradient(
              colors: [Color(0xFF275F47), Color(0xFF4BAF7C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1F2F855A),
                blurRadius: 28,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(Icons.spa_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      '오늘의 가드닝 루틴',
                      style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '식물 ${plants.length}개',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                todayTasks.isEmpty ? '오늘은 쉬어가는\n가벼운 식물 케어' : '오늘 바로 확인할\n식물이 ${todayTasks.length}개 있어요',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  height: 1.15,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                streakMessage,
                style: const TextStyle(color: Colors.white70, height: 1.5),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(child: _HighlightMetric(label: '오늘 관리', value: '${todayTasks.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: _HighlightMetric(label: '곧 필요', value: '${soonTasks.length}')),
                  const SizedBox(width: 10),
                  Expanded(child: _HighlightMetric(label: '안정 상태', value: '$healthyCount')),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _GlassSummaryCard(
                title: '오늘 우선순위',
                subtitle: todayTasks.isEmpty ? '급한 식물 없음' : '바로 물주기 추천',
                value: todayTasks.isEmpty ? '여유로움' : '${todayTasks.length}개 우선',
                accent: const Color(0xFFFFB648),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _GlassSummaryCard(
                title: '다음 체크',
                subtitle: soonTasks.isEmpty ? '예정 없음' : '곧 다가옴',
                value: soonTasks.isEmpty ? '안정적' : '${soonTasks.length}개 예정',
                accent: const Color(0xFF5BC0A5),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const _SectionTitle(title: '오늘 해야 할 일', subtitle: '급한 순서대로 바로 처리할 수 있게 정리했어요.'),
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
        const _SectionTitle(title: '곧 확인할 식물', subtitle: '하루 이틀 안에 체크하면 좋은 식물들이에요.'),
        const SizedBox(height: 12),
        if (soonTasks.isEmpty)
          const EmptyCard(message: '곧 물줄 식물이 아직 없습니다.')
        else
          ...soonTasks.map((plant) => CompactPlantCard(plant: plant, onTap: () => onTapPlant(plant))),
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
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 110),
        itemCount: plants.length + 1,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE6F8EF),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.eco_rounded, color: Color(0xFF2F855A)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Text(
                      '등록한 식물을 눌러 사진, 메모, 물주기 주기를 바로 수정할 수 있어요.',
                      style: TextStyle(height: 1.4, color: Colors.black54),
                    ),
                  ),
                  IconButton.filledTonal(onPressed: onAddPlant, icon: const Icon(Icons.add_rounded)),
                ],
              ),
            );
          }
          final plant = plants[index - 1];
          return PlantListCard(plant: plant, onTap: () => onTapPlant(plant));
        },
      ),
    );
  }
}

class CalendarTab extends StatefulWidget {
  const CalendarTab({super.key, required this.plants});

  final List<PlantItem> plants;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  static const int _initialPage = 1200;
  late final PageController _pageController;
  late DateTime _visibleMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _visibleMonth = DateTime(now.year, now.month);
    _pageController = PageController(initialPage: _initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final monthlyPlants = [...widget.plants]
      ..retainWhere(
        (plant) =>
            plant.nextWateringAt.year == _visibleMonth.year &&
            plant.nextWateringAt.month == _visibleMonth.month,
      )
      ..sort((a, b) => a.nextWateringAt.compareTo(b.nextWateringAt));

    return ListView(
      padding: const EdgeInsets.only(bottom: 90),
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final calendarWidth = constraints.maxWidth - 40;
            final calendarHeight = _calendarCardHeightForMonth(
              month: _visibleMonth,
              width: calendarWidth,
            );
            return AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: SizedBox(
                height: calendarHeight,
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (page) {
                    setState(() {
                      _visibleMonth = _monthFromPage(page);
                    });
                  },
                  itemBuilder: (context, index) {
                    final month = _monthFromPage(index);
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: _MonthCalendarCard(month: month, plants: widget.plants),
                    );
                  },
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${_monthLabel(_visibleMonth)} 관리 예정', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (monthlyPlants.isEmpty)
                  const Text(
                    '이 달에 예정된 물주기 일정이 없습니다.',
                    style: TextStyle(color: Colors.black54),
                  )
                else
                  ...monthlyPlants.map(
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
    );
  }

  DateTime _monthFromPage(int page) {
    final offset = page - _initialPage;
    final base = DateTime.now();
    return DateTime(base.year, base.month + offset);
  }

  double _calendarCardHeightForMonth({
    required DateTime month,
    required double width,
  }) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leadingEmpty = firstDay.weekday % 7;
    final daySlots = leadingEmpty + lastDay.day;
    final weekRows = (daySlots / 7).ceil();
    const childAspectRatio = 0.76;
    final cellWidth = width / 7;
    final cellHeight = cellWidth / childAspectRatio;
    final gridRows = weekRows + 1;
    const topSectionHeight = 104.0;
    return topSectionHeight + (cellHeight * gridRows);
  }
}

class _MonthCalendarCard extends StatelessWidget {
  const _MonthCalendarCard({
    required this.month,
    required this.plants,
  });

  final DateTime month;
  final List<PlantItem> plants;

  @override
  Widget build(BuildContext context) {
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leadingEmpty = firstDay.weekday % 7;
    final totalCells = leadingEmpty + lastDay.day;
    final trailingEmpty = (7 - (totalCells % 7)) % 7;
    final today = DateTime.now();

    final cells = <Widget>[
      for (final label in const ['일', '월', '화', '수', '목', '금', '토'])
        Center(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.black45,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ),
      for (var i = 0; i < leadingEmpty; i++) const SizedBox.shrink(),
      for (var day = 1; day <= lastDay.day; day++)
        _CalendarDayCell(
          date: DateTime(month.year, month.month, day),
          isToday: today.year == month.year && today.month == month.month && today.day == day,
          dueCount: _dueCountForDay(DateTime(month.year, month.month, day)),
        ),
      for (var i = 0; i < trailingEmpty; i++) const SizedBox.shrink(),
    ];

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF5FBF7),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.calendar_today_rounded, size: 18, color: Color(0xFF2F855A)),
              const SizedBox(width: 8),
              Text(
                '${month.year}년 ${month.month}월 캘린더',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '물주기 일정이 있는 날에는 초록 점과 개수로 표시돼요.',
            style: TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 16),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 7,
            childAspectRatio: 0.76,
            children: cells,
          ),
        ],
      ),
    );
  }

  int _dueCountForDay(DateTime target) {
    return plants.where((plant) {
      final next = plant.nextWateringAt;
      return next.year == target.year && next.month == target.month && next.day == target.day;
    }).length;
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.dueCount,
  });

  final DateTime date;
  final bool isToday;
  final int dueCount;

  @override
  Widget build(BuildContext context) {
    final hasEvent = dueCount > 0;
    return Container(
      margin: const EdgeInsets.all(3),
      padding: const EdgeInsets.symmetric(vertical: 5),
      decoration: BoxDecoration(
        color: isToday
            ? const Color(0xFF2F855A)
            : hasEvent
                ? const Color(0xFFE7F7EE)
                : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday ? const Color(0xFF2F855A) : const Color(0x11000000),
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${date.day}',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: isToday ? Colors.white : const Color(0xFF24332A),
            ),
          ),
          const SizedBox(height: 4),
          if (hasEvent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: isToday ? Colors.white.withValues(alpha: 0.2) : const Color(0xFF53B97C),
                borderRadius: BorderRadius.circular(99),
              ),
              child: Text(
                '$dueCount',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: isToday ? Colors.white : Colors.white,
                ),
              ),
            )
          else
            Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: isToday ? Colors.white30 : const Color(0x14000000),
                shape: BoxShape.circle,
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
    final strongestPlant = plants.isEmpty ? null : ([...plants]..sort((a, b) => a.daysUntilWatering.compareTo(b.daysUntilWatering))).first;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        padding: const EdgeInsets.only(bottom: 90),
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: const Color(0xFF111A16),
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '한눈에 보는 식물 상태',
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  strongestPlant == null
                      ? '등록된 식물이 아직 없어요.'
                      : '${strongestPlant.name}부터 루틴을 챙기면 오늘 관리가 훨씬 쉬워져요.',
                  style: const TextStyle(color: Color(0xBFFFFFFF), height: 1.45),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _DarkMetricTile(label: '등록 식물', value: '$total개', accent: const Color(0xFF5BC0A5))),
                    const SizedBox(width: 10),
                    Expanded(child: _DarkMetricTile(label: '평균 주기', value: avgCycle == 0 ? '-' : '$avgCycle일', accent: const Color(0xFFFFD166))),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 0.9,
            children: [
              _SoftStatCard(title: '안정 상태', value: '$healthy개', detail: '건강하게 유지 중', color: const Color(0xFF2B9348), icon: Icons.favorite_rounded),
              _SoftStatCard(title: '오늘 물주기', value: '$dueToday개', detail: '오늘 체크 필요', color: const Color(0xFFF59E0B), icon: Icons.water_drop_rounded),
              _SoftStatCard(title: '오래 방치', value: '$overdue개', detail: '가장 먼저 챙겨주세요', color: const Color(0xFFDC2626), icon: Icons.crisis_alert_rounded),
              _SoftStatCard(title: '전체 루틴', value: '$total개', detail: '기록 중인 식물 수', color: const Color(0xFF2F855A), icon: Icons.local_florist_rounded),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(26),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x0C000000),
                  blurRadius: 20,
                  offset: Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('물주기 주기 흐름', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                const Text('식물마다 주기가 얼마나 다른지 한 번에 볼 수 있어요.', style: TextStyle(color: Colors.black54)),
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
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: _statusColor(plant.status).withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text('${plant.wateringCycleDays}일 주기'),
                            ),
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
                Text('평균 물주기 주기: ${avgCycle == 0 ? '-' : '$avgCycle일'}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (plants.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBF2),
                borderRadius: BorderRadius.circular(26),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7B3),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.tips_and_updates_rounded, color: Color(0xFFC08400)),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Text(
                      overdue > 0
                          ? '오래 방치된 식물이 $overdue개 있어요. 오늘은 급한 식물부터 물주기 체크를 시작해보세요.'
                          : '전체적으로 관리 흐름이 안정적이에요. 오늘 물주기 예정 식물만 가볍게 확인하면 됩니다.',
                      style: const TextStyle(height: 1.5, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _GardenBottomNav extends StatelessWidget {
  const _GardenBottomNav({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<_NavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, bottomInset + 12),
      child: Container(
        height: 92,
        padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(30),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: List.generate(items.length, (index) {
            final item = items[index];
            return Expanded(
              child: _GardenNavItem(
                data: item,
                isSelected: index == selectedIndex,
                onTap: () => onSelected(index),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _GardenNavItem extends StatelessWidget {
  const _GardenNavItem({
    required this.data,
    required this.isSelected,
    required this.onTap,
  });

  final _NavItemData data;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isSelected ? data.color.withValues(alpha: 0.16) : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: isSelected ? 40 : 36,
                    height: isSelected ? 40 : 36,
                    decoration: BoxDecoration(
                      color: isSelected ? data.color : const Color(0xFFF0F4F1),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Icon(
                      data.icon,
                      color: isSelected ? Colors.white : const Color(0xFF5F6F65),
                      size: 20,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    data.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      height: 1,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? data.color : const Color(0xFF5F6F65),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItemData {
  const _NavItemData({
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
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
  late List<String> _photoAssetIds;

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
    _photoAssetIds = List<String>.from(current?.photoAssetIds ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    _cycleController.dispose();
    super.dispose();
  }

  Future<void> _openPhotoPicker() async {
    final result = await Navigator.of(context).push<List<String>>(
      MaterialPageRoute(
        builder: (_) => PhotoPickerPage(initialSelectedIds: _photoAssetIds),
      ),
    );
    if (result != null) {
      setState(() {
        _photoAssetIds = result;
      });
    }
  }

  InputDecoration _sheetInputDecoration({
    required String label,
    required IconData icon,
    String? hint,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon, color: const Color(0xFF5E6D64)),
      filled: true,
      fillColor: const Color(0xFFF8FBF8),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFFE3ECE6)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(22),
        borderSide: const BorderSide(color: Color(0xFF2F855A), width: 1.4),
      ),
      labelStyle: const TextStyle(color: Color(0xFF66756C)),
      hintStyle: const TextStyle(color: Color(0xFF9AA8A0)),
    );
  }

  Widget _buildSectionCard({
    required String title,
    required String subtitle,
    required Widget child,
    IconData? icon,
    Color accent = const Color(0xFF2F855A),
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFE5EEE8)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A244034),
            blurRadius: 24,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54, height: 1.35),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final bottomInset = mediaQuery.viewInsets.bottom;
    final bottomSafeArea = mediaQuery.viewPadding.bottom;
    final sheetHeight = mediaQuery.size.height * 0.8;
    final isEditing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SizedBox(
        height: sheetHeight,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(22),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(30),
                        gradient: const LinearGradient(
                          colors: [Color(0xFFEEF8F1), Color(0xFFF7FBF7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        border: Border.all(color: const Color(0xFFDDEBE2)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 52,
                                height: 52,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2F855A),
                                  borderRadius: BorderRadius.circular(18),
                                ),
                                child: Icon(
                                  isEditing ? Icons.edit_rounded : Icons.add_rounded,
                                  color: Colors.white,
                                  size: 26,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isEditing ? '식물 정보 다듬기' : '새 식물 등록하기',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEditing
                                          ? '사진, 메모, 물주기 루틴을 한 번에 정리해보세요.'
                                          : '식물 이름과 루틴을 가볍게 입력하고 바로 관리 시작할 수 있어요.',
                                      style: const TextStyle(color: Colors.black54, height: 1.4),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: [
                              _InfoPill(
                                icon: Icons.water_drop_rounded,
                                label: '${_cycleController.text.trim().isEmpty ? _selectedPreset.defaultWateringCycleDays : _cycleController.text.trim()}일 주기',
                                tint: const Color(0xFFE8F5EC),
                              ),
                              _InfoPill(
                                icon: Icons.wb_sunny_rounded,
                                label: _selectedPreset.sunlight,
                                tint: const Color(0xFFFFF2DE),
                              ),
                              _InfoPill(
                                icon: Icons.photo_library_rounded,
                                label: _photoAssetIds.isEmpty ? '사진 없음' : '${_photoAssetIds.length}장 선택',
                                tint: const Color(0xFFEAF1FF),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildSectionCard(
                      icon: Icons.local_florist_rounded,
                      title: '기본 정보',
                      subtitle: '식물 종류와 이름, 위치를 먼저 정리해둘게요.',
                      child: Column(
                        children: [
                          DropdownButtonFormField<PlantPreset>(
                            initialValue: _selectedPreset,
                            dropdownColor: Colors.white,
                            decoration: _sheetInputDecoration(label: '식물 종류', icon: Icons.category_rounded),
                            items: kPlantPresets
                                .map((preset) => DropdownMenuItem(
                                      value: preset,
                                      child: Text('${preset.type} · ${preset.tip}'),
                                    ))
                                .toList(),
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
                          TextField(
                            controller: _nameController,
                            decoration: _sheetInputDecoration(
                              label: '나의 식물 이름',
                              icon: Icons.local_florist_rounded,
                              hint: '예: 거실 몬스테라',
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _locationController,
                            decoration: _sheetInputDecoration(
                              label: '위치',
                              icon: Icons.place_rounded,
                              hint: '예: 거실 창가',
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.schedule_rounded,
                      title: '관리 루틴',
                      subtitle: '물주기 간격과 마지막 물준 날짜를 깔끔하게 기록해둘 수 있어요.',
                      accent: const Color(0xFFFFA94D),
                      child: Column(
                        children: [
                          TextField(
                            controller: _cycleController,
                            keyboardType: TextInputType.number,
                            decoration: _sheetInputDecoration(
                              label: '물주기 주기',
                              icon: Icons.water_drop_rounded,
                              hint: '숫자만 입력',
                            ).copyWith(suffixText: '일'),
                          ),
                          const SizedBox(height: 14),
                          InkWell(
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
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBF8),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFE3ECE6)),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 42,
                                    height: 42,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFFFF1DF),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(Icons.calendar_today_rounded, color: Color(0xFFFFA94D), size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          '마지막 물준 날짜',
                                          style: TextStyle(color: Color(0xFF66756C), fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _dateLabel(_lastWateredAt),
                                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right_rounded, color: Colors.black45),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.notes_rounded,
                      title: '메모',
                      subtitle: '기억해두고 싶은 상태나 관리 포인트를 남겨보세요.',
                      accent: const Color(0xFF6C8CF6),
                      child: TextField(
                        controller: _memoController,
                        maxLines: 5,
                        decoration: _sheetInputDecoration(
                          label: '식물 메모',
                          icon: Icons.edit_note_rounded,
                          hint: '예: 새 잎이 올라오는 중, 과습 주의',
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.photo_library_rounded,
                      title: '식물 사진',
                      subtitle: '대표 사진을 맨 앞으로 두고 순서도 직접 바꿀 수 있어요.',
                      accent: const Color(0xFF5B8DEF),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Align(
                            alignment: Alignment.centerLeft,
                            child: FilledButton.tonalIcon(
                              onPressed: _openPhotoPicker,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFEAF1FF),
                                foregroundColor: const Color(0xFF335EC7),
                                elevation: 0,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              ),
                              icon: const Icon(Icons.add_photo_alternate_outlined),
                              label: const Text('사진 선택'),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_photoAssetIds.isEmpty)
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBF8),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(color: const Color(0xFFE3ECE6)),
                              ),
                              child: const Text(
                                '등록된 사진이 없습니다. 여러 장을 선택해서 대표 사진 순서까지 정리할 수 있어요.',
                                style: TextStyle(color: Colors.black54, height: 1.4),
                              ),
                            )
                          else
                            SizedBox(
                              height: 96,
                              child: ReorderableListView.builder(
                                scrollDirection: Axis.horizontal,
                                buildDefaultDragHandles: true,
                                padding: EdgeInsets.zero,
                                itemCount: _photoAssetIds.length,
                                proxyDecorator: (child, index, animation) {
                                  return Material(
                                    color: Colors.transparent,
                                    child: ScaleTransition(
                                      scale: Tween<double>(begin: 1, end: 1.04).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }
                                    final moved = _photoAssetIds.removeAt(oldIndex);
                                    _photoAssetIds.insert(newIndex, moved);
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final assetId = _photoAssetIds[index];
                                  return Padding(
                                    key: ValueKey(assetId),
                                    padding: EdgeInsets.only(right: index == _photoAssetIds.length - 1 ? 0 : 12),
                                    child: Stack(
                                      children: [
                                        PlantPhotoThumb(assetId: assetId, width: 96, height: 96, borderRadius: 22),
                                        Positioned(
                                          left: 8,
                                          bottom: 8,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(alpha: 0.38),
                                              borderRadius: BorderRadius.circular(999),
                                            ),
                                            child: const Icon(Icons.drag_indicator_rounded, color: Colors.white, size: 18),
                                          ),
                                        ),
                                        if (index == 0)
                                          Positioned(
                                            left: 8,
                                            top: 8,
                                            child: Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(alpha: 0.92),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Text(
                                                '대표',
                                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
                                              ),
                                            ),
                                          ),
                                        Positioned(
                                          top: 8,
                                          right: 8,
                                          child: GestureDetector(
                                            onTap: () {
                                              setState(() {
                                                _photoAssetIds.removeAt(index);
                                              });
                                            },
                                            child: Container(
                                              width: 28,
                                              height: 28,
                                              decoration: BoxDecoration(
                                                color: Colors.black.withValues(alpha: 0.68),
                                                borderRadius: BorderRadius.circular(999),
                                              ),
                                              child: const Icon(Icons.close, color: Colors.white, size: 17),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                            ),
                          const SizedBox(height: 12),
                          Text(
                            _photoAssetIds.length > 1
                                ? '사진을 길게 눌러 드래그하면 순서를 바꿀 수 있어요. 첫 번째 사진이 대표로 보여집니다.'
                                : '햇빛 추천은 ${_selectedPreset.sunlight} 환경이에요.',
                            style: const TextStyle(color: Colors.black54, height: 1.4),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomSafeArea),
              decoration: const BoxDecoration(
                color: Color(0xFFF6FBF7),
                border: Border(top: BorderSide(color: Color(0x12000000))),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF2F855A), Color(0xFF43A26C)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: FilledButton(
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
                      photoAssetIds: List<String>.from(_photoAssetIds),
                    );
                    Navigator.of(context).pop(plant);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    minimumSize: const Size.fromHeight(58),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                  ),
                  child: Text(
                    isEditing ? '수정 내용 저장' : '식물 등록하기',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
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
              if (plant.photoAssetIds.isNotEmpty) ...[
                PlantPhotoThumb(assetId: plant.photoAssetIds.first, width: 56, height: 56, borderRadius: 16),
                const SizedBox(width: 12),
              ],
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
    final color = _statusColor(plant.status);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [BoxShadow(color: Color(0x11000000), blurRadius: 16, offset: Offset(0, 8))],
        ),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 126,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (plant.photoAssetIds.isNotEmpty)
                      PlantPhotoThumb(assetId: plant.photoAssetIds.first, width: 126, height: 220, borderRadius: 0)
                    else
                      Container(
                        color: color.withValues(alpha: 0.14),
                        child: Icon(Icons.local_florist_rounded, color: color, size: 42),
                      ),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [Colors.transparent, Colors.black.withValues(alpha: 0.22)],
                        ),
                      ),
                    ),
                    if (plant.photoAssetIds.length > 1)
                      Positioned(
                        top: 10,
                        right: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.42),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '+${plant.photoAssetIds.length - 1}',
                            style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plant.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${plant.type} · ${plant.location}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: Colors.black54),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          StatusChip(status: plant.status),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          _InfoPill(
                            icon: Icons.calendar_month_rounded,
                            label: '다음 ${_dateLabel(plant.nextWateringAt)}',
                            tint: const Color(0xFFEAF5EE),
                          ),
                          _InfoPill(
                            icon: Icons.water_drop_rounded,
                            label: '${plant.wateringCycleDays}일 주기',
                            tint: const Color(0xFFFFF0D9),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        plant.memo,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.black54, height: 1.45),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 9,
                            height: 9,
                            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _statusDescription(plant.status),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(color: color, fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
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

class _InfoPill extends StatelessWidget {
  const _InfoPill({
    required this.icon,
    required this.label,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF425249)),
          const SizedBox(width: 6),
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF425249),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

class _HighlightMetric extends StatelessWidget {
  const _HighlightMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _GlassSummaryCard extends StatelessWidget {
  const _GlassSummaryCard({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.accent,
  });

  final String title;
  final String subtitle;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_awesome_rounded, color: accent, size: 18),
          ),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.4)),
        ],
      ),
    );
  }
}

class _DarkMetricTile extends StatelessWidget {
  const _DarkMetricTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(height: 12),
          Text(label, style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
          ),
        ],
      ),
    );
  }
}

class _SoftStatCard extends StatelessWidget {
  const _SoftStatCard({
    required this.title,
    required this.value,
    required this.detail,
    required this.color,
    required this.icon,
  });

  final String title;
  final String value;
  final String detail;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const Spacer(),
          Text(title, style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 6),
          Text(detail, style: const TextStyle(color: Colors.black54, height: 1.35)),
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

String _statusDescription(PlantStatus status) {
  switch (status) {
    case PlantStatus.healthy:
      return '루틴이 안정적이에요';
    case PlantStatus.soon:
      return '곧 물주기 타이밍';
    case PlantStatus.today:
      return '오늘 챙기면 좋아요';
    case PlantStatus.overdue:
      return '가장 먼저 확인해주세요';
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
