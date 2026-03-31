import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'ad_service.dart';
import 'app_localizations.dart';
import 'app_settings_service.dart';
import 'auth_session_service.dart';
import 'auth_service.dart';
import 'firebase_service.dart';
import 'notification_service.dart';
import 'photo_picker_page.dart';
import 'plant_detail_page.dart';
import 'plant_models.dart';
import 'plant_preset_service.dart';
import 'plant_photo_widgets.dart';
import 'plant_sync_service.dart';
import 'plant_storage_service.dart';
import 'settings_tabs.dart';
import 'sync_state_service.dart';

void main() {
  runApp(const PlantReminderApp());
}

class PlantReminderApp extends StatelessWidget {
  const PlantReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => context.l10n.appTitle,
      localeResolutionCallback: (locale, supportedLocales) {
        if (locale == null) return const Locale('en');
        if (['ko', 'en', 'zh', 'ja'].contains(locale.languageCode)) {
          return Locale(locale.languageCode);
        }
        return const Locale('en');
      },
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
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
  BannerAd? _bannerAd;
  bool _isBannerLoading = false;
  int? _bannerWidth;
  AppAuthUser? _authUser;
  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _isLoading = true;
  List<PlantPreset> _plantPresets = List<PlantPreset>.from(kPlantPresets);
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
    await AdService.init();
    final stored = await PlantStorageService.loadPlants();
    final loadedSettings = await AppSettingsService.load();
    final loadedPresets = await PlantPresetService.loadPresets();
    final savedAuthUser = await AuthSessionService.loadUser();
    if (stored.isNotEmpty) {
      _plants
        ..clear()
        ..addAll(stored);
    }
    if (loadedPresets.isNotEmpty) {
      _plantPresets = loadedPresets;
    }
    _settings = loadedSettings;
    _authUser = savedAuthUser;
    if (savedAuthUser != null) {
      await _restoreCloudDataIfNeeded(savedAuthUser);
    }
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _persistPlants() async {
    await PlantStorageService.savePlants(_plants);
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    await _syncCurrentStateIfLinked();
  }

  Future<void> _persistSettingsOnly() async {
    await AppSettingsService.save(_settings);
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    await _syncCurrentStateIfLinked();
  }

  Future<void> _restoreCloudDataIfNeeded(AppAuthUser user) async {
    try {
      final profile = await PlantSyncService.fetchProfile(user);
      final syncState = await SyncStateService.load();
      final sameUser = syncState.userKey == SyncStateService.userKeyFor(user);
      if (!profile.exists) {
        if (_plants.isNotEmpty) {
          final result = await PlantSyncService.replaceWithLocal(
            user: user,
            plants: List<PlantItem>.from(_plants.map((item) => item.copy())),
            settings: _settings,
          );
          await SyncStateService.markSynced(user, result.updatedAt);
        }
        return;
      }

      final hasLocalData = _plants.isNotEmpty;
      final serverNewer = profile.updatedAt != null &&
          sameUser &&
          syncState.lastSyncedAt != null &&
          profile.updatedAt!.isAfter(syncState.lastSyncedAt!);

      if (!hasLocalData || (sameUser && !syncState.isDirty && serverNewer)) {
        await _applySyncedData(user, profile.plants, profile.settings, profile.updatedAt);
      }
    } catch (_) {
      // Keep local data when cloud sync is unavailable during bootstrap.
    }
  }

  Future<void> _applySyncedData(
    AppAuthUser user,
    List<PlantItem> plants,
    AppSettings settings,
    DateTime? syncedAt,
  ) async {
    _plants
      ..clear()
      ..addAll(plants.map((item) => item.copy()));
    _settings = settings;
    await PlantStorageService.savePlants(_plants);
    await AppSettingsService.save(_settings);
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    await SyncStateService.markSynced(user, syncedAt);
  }

  Future<void> _syncCurrentStateIfLinked() async {
    final user = _authUser;
    if (user == null || _isSyncing) return;
    await SyncStateService.markDirty(user);
    _isSyncing = true;
    try {
      final result = await PlantSyncService.replaceWithLocal(
        user: user,
        plants: List<PlantItem>.from(_plants.map((item) => item.copy())),
        settings: _settings,
      );
      await SyncStateService.markSynced(user, result.updatedAt);
    } catch (_) {
      // Keep local dirty flag so we can retry later.
    } finally {
      _isSyncing = false;
    }
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
    AdService.showInterstitialIfNeeded();
    _showToast(AppLocalizations.of(context).wateredToast(plant.name));
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
    AdService.showInterstitialIfNeeded();
  }

  Future<void> _openAddPlantSheet() async {
    final created = await showModalBottomSheet<PlantItem>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PlantEditSheet(presets: _plantPresets),
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
      builder: (context) => PlantEditSheet(existing: plant.copy(), presets: _plantPresets),
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

  Future<_SyncResolution?> _showSyncChoiceDialog({
    required PlantSyncProfile profile,
  }) {
    final l10n = context.l10n;
    return showDialog<_SyncResolution>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Dialog(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.syncChoiceTitle, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                Text(l10n.syncChoiceBody, style: const TextStyle(color: Colors.black54, height: 1.5)),
                const SizedBox(height: 16),
                _SyncSummaryCard(title: l10n.syncDeviceSummary, plantCount: _plants.length),
                const SizedBox(height: 10),
                _SyncSummaryCard(title: l10n.syncServerSummary, plantCount: profile.plants.length),
                const SizedBox(height: 18),
                _SyncChoiceButton(
                  title: l10n.syncUseServer,
                  subtitle: l10n.syncChoiceServerHint,
                  accent: const Color(0xFF4C8BF5),
                  onTap: () => Navigator.of(context).pop(_SyncResolution.server),
                ),
                const SizedBox(height: 10),
                _SyncChoiceButton(
                  title: l10n.syncUseLocal,
                  subtitle: l10n.syncChoiceLocalHint,
                  accent: const Color(0xFF2F855A),
                  onTap: () => Navigator.of(context).pop(_SyncResolution.local),
                ),
                const SizedBox(height: 10),
                _SyncChoiceButton(
                  title: l10n.syncMerge,
                  subtitle: l10n.syncChoiceMergeHint,
                  accent: const Color(0xFFF59E0B),
                  onTap: () => Navigator.of(context).pop(_SyncResolution.merge),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleSettingsChanged(AppSettings settings) async {
    setState(() {
      _settings = settings;
    });
    await _persistSettingsOnly();
  }

  Future<void> _handlePlatformSignIn() async {
    if (_isSigningIn) return;
    final l10n = AppLocalizations.of(context);
    setState(() {
      _isSigningIn = true;
    });
    try {
      final user = await AuthService.instance.signInForCurrentPlatform();
      if (!mounted) return;
      if (user != null) {
        String? syncToast;
        await AuthSessionService.saveUser(user);
        final profile = await PlantSyncService.fetchProfile(user);
        final hasLocalData = _plants.isNotEmpty;
        if (profile.exists && hasLocalData) {
          final resolution = await _showSyncChoiceDialog(profile: profile);
          if (!mounted || resolution == null) return;
          switch (resolution) {
            case _SyncResolution.server:
              await _applySyncedData(user, profile.plants, profile.settings, profile.updatedAt);
              syncToast = l10n.syncImported;
              break;
            case _SyncResolution.local:
              final uploaded = await PlantSyncService.replaceWithLocal(
                user: user,
                plants: List<PlantItem>.from(_plants.map((item) => item.copy())),
                settings: _settings,
              );
              await SyncStateService.markSynced(user, uploaded.updatedAt);
              syncToast = l10n.syncUploaded;
              break;
            case _SyncResolution.merge:
              final merged = await PlantSyncService.mergeWithServer(
                user: user,
                localPlants: List<PlantItem>.from(_plants.map((item) => item.copy())),
                localSettings: _settings,
              );
              await _applySyncedData(user, merged.plants, merged.settings, merged.updatedAt);
              syncToast = l10n.syncMerged;
              break;
          }
        } else if (profile.exists && !hasLocalData) {
          await _applySyncedData(user, profile.plants, profile.settings, profile.updatedAt);
          syncToast = l10n.syncImported;
        } else if (!profile.exists && hasLocalData) {
          final uploaded = await PlantSyncService.replaceWithLocal(
            user: user,
            plants: List<PlantItem>.from(_plants.map((item) => item.copy())),
            settings: _settings,
          );
          await SyncStateService.markSynced(user, uploaded.updatedAt);
          syncToast = l10n.syncUploaded;
        }
        setState(() {
          _authUser = user;
        });
        _showToast(syncToast ?? l10n.loginSuccessToast(user.provider == 'google' ? 'Google' : 'Apple'));
      }
    } catch (error) {
      if (!mounted) return;
      _showToast(l10n.syncFailed);
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
    await AuthSessionService.clear();
    await SyncStateService.clear();
    if (!mounted) return;
    setState(() {
      _authUser = null;
    });
    _showToast(AppLocalizations.of(context).logoutDone);
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  Future<void> _loadBannerForWidth(int width) async {
    if (_isBannerLoading || width <= 0 || _bannerWidth == width) return;
    _isBannerLoading = true;
    final banner = await AdService.loadBanner(width);
    if (!mounted) {
      banner?.dispose();
      _isBannerLoading = false;
      return;
    }

    final oldBanner = _bannerAd;
    setState(() {
      _bannerAd = banner;
      _bannerWidth = banner == null ? null : width;
    });
    oldBanner?.dispose();
    _isBannerLoading = false;
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
      MyPlantsTab(
        plants: _plants,
        presets: _plantPresets,
        onTapPlant: _openPlantDetail,
        onAddPlant: _openAddPlantSheet,
      ),
      CalendarTab(plants: _plants),
      StatsTab(plants: _plants),
    ];
    final l10n = context.l10n;
    final navItems = [
      _NavItemData(
        label: l10n.home,
        subtitle: l10n.homeSubtitle,
        icon: Icons.home_rounded,
        color: const Color(0xFF53B97C),
      ),
      _NavItemData(
        label: l10n.myPlants,
        subtitle: l10n.myPlantsSubtitle,
        icon: Icons.local_florist_rounded,
        color: const Color(0xFF5BC0A5),
      ),
      _NavItemData(
        label: l10n.calendar,
        subtitle: l10n.calendarSubtitle,
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFFFFB648),
      ),
      _NavItemData(
        label: l10n.stats,
        subtitle: l10n.statsSubtitle,
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFFFF8E72),
      ),
    ];
    final activeNav = navItems[_currentIndex];
    final bannerWidth = MediaQuery.sizeOf(context).width.truncate();
    if (_bannerWidth != bannerWidth && !_isBannerLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBannerForWidth(bannerWidth);
      });
    }

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
              tooltip: l10n.settings,
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
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _GardenBottomNav(
            items: navItems,
            selectedIndex: _currentIndex,
            onSelected: (value) => setState(() => _currentIndex = value),
            extraBottomPadding: _bannerAd == null ? MediaQuery.of(context).viewPadding.bottom : 0,
          ),
          if (_bannerAd != null)
            Container(
              width: double.infinity,
              color: Colors.white,
              padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewPadding.bottom),
              child: SizedBox(
                width: double.infinity,
                height: _bannerAd!.size.height.toDouble(),
                child: AdWidget(ad: _bannerAd!),
              ),
            ),
        ],
      ),
    );
  }
}

enum _SyncResolution { server, local, merge }

class _SyncSummaryCard extends StatelessWidget {
  const _SyncSummaryCard({
    required this.title,
    required this.plantCount,
  });

  final String title;
  final int plantCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF8),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE2EBE5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text('$plantCount', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _SyncChoiceButton extends StatelessWidget {
  const _SyncChoiceButton({
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.25)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.4)),
          ],
        ),
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
    final l10n = context.l10n;
    final todayTasks = plants.where((plant) => plant.status == PlantStatus.today || plant.status == PlantStatus.overdue).toList();
    final soonTasks = plants.where((plant) => plant.status == PlantStatus.soon).toList();
    final healthyCount = plants.where((plant) => plant.status == PlantStatus.healthy).length;
    final streakMessage = l10n.todayTaskStreak(todayTasks.isNotEmpty);
    final primaryPlant = todayTasks.isNotEmpty ? todayTasks.first : (soonTasks.isNotEmpty ? soonTasks.first : (plants.isNotEmpty ? plants.first : null));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 112),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: const Color(0xFFE4ECE6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1DFC7),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(8),
                      child: Image.asset(
                        'assets/branding/app_logo.png',
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.todayRoutine,
                          style: const TextStyle(color: Color(0xFF66756C), fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.plantCount(plants.length),
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                todayTasks.isEmpty ? l10n.todayCareRelaxed : l10n.todayPlantsHeadline(todayTasks.length),
                style: const TextStyle(
                  color: Color(0xFF111A16),
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  height: 1.18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                streakMessage,
                style: const TextStyle(color: Colors.black54, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF7FAF8),
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  children: [
                    Expanded(child: _HomeMiniStat(label: l10n.todayTasks, value: l10n.highlightValueCount(todayTasks.length))),
                    const SizedBox(width: 10),
                    Expanded(child: _HomeMiniStat(label: l10n.soonNeed, value: l10n.highlightValueCount(soonTasks.length))),
                    const SizedBox(width: 10),
                    Expanded(child: _HomeMiniStat(label: l10n.healthyState, value: l10n.highlightValueCount(healthyCount))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _HomeOverviewCard(
          title: l10n.todayPriority,
          value: todayTasks.isEmpty ? l10n.relaxed : l10n.priorityValue(todayTasks.length),
          subtitle: todayTasks.isEmpty
              ? l10n.noUrgentPlants
              : (primaryPlant == null ? l10n.recommendWateringNow : '${primaryPlant.name} · ${primaryPlant.location}'),
          accent: todayTasks.isEmpty ? const Color(0xFF8AA39A) : const Color(0xFF2F855A),
        ),
        const SizedBox(height: 12),
        _HomeOverviewCard(
          title: l10n.nextCheck,
          value: soonTasks.isEmpty ? l10n.stable : l10n.scheduledValue(soonTasks.length),
          subtitle: soonTasks.isEmpty
              ? l10n.nothingScheduled
              : '${soonTasks.first.name} · ${l10n.nextDateLabel(soonTasks.first.nextWateringAt)}',
          accent: const Color(0xFF5B8DEF),
        ),
        const SizedBox(height: 24),
        _SectionTitle(title: l10n.todayTodo, subtitle: l10n.todayTodoHint),
        const SizedBox(height: 12),
        if (todayTasks.isEmpty)
          EmptyCard(message: l10n.noPlantForToday)
        else
          ...todayTasks.map(
            (plant) => PlantActionCard(
              plant: plant,
              onTap: () => onTapPlant(plant),
              onMarkWatered: () => onMarkWatered(plant),
            ),
          ),
        const SizedBox(height: 20),
        _SectionTitle(title: l10n.checkSoonPlants, subtitle: l10n.checkSoonPlantsHint),
        const SizedBox(height: 12),
        if (soonTasks.isEmpty)
          EmptyCard(message: l10n.noSoonPlants)
        else
          ...soonTasks.map((plant) => CompactPlantCard(plant: plant, onTap: () => onTapPlant(plant))),
      ],
    );
  }
}

class MyPlantsTab extends StatefulWidget {
  const MyPlantsTab({
    super.key,
    required this.plants,
    required this.presets,
    required this.onTapPlant,
    required this.onAddPlant,
  });

  final List<PlantItem> plants;
  final List<PlantPreset> presets;
  final ValueChanged<PlantItem> onTapPlant;
  final VoidCallback onAddPlant;

  @override
  State<MyPlantsTab> createState() => _MyPlantsTabState();
}

class _MyPlantsTabState extends State<MyPlantsTab> {
  PlantStatus? _selectedStatus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final filteredPlants = _selectedStatus == null
        ? widget.plants
        : widget.plants.where((plant) => plant.status == _selectedStatus).toList();

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 110),
        itemCount: filteredPlants.length + 2,
        separatorBuilder: (context, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MyPlantsIntroCard(
              guideText: l10n.myPlantsGuide,
              onAddPlant: widget.onAddPlant,
            );
          }
          if (index == 1) {
            return _MyPlantsStatusFilterCard(
              selectedStatus: _selectedStatus,
              plants: widget.plants,
              onStatusSelected: (status) {
                setState(() {
                  _selectedStatus = status;
                });
              },
            );
          }
          final plant = filteredPlants[index - 2];
          final matchedPreset = widget.presets.cast<PlantPreset?>().firstWhere(
                (preset) => preset?.type == plant.type,
                orElse: () => null,
              );
          return PlantListCard(
            plant: plant,
            presetImageUrl: matchedPreset?.imageUrl,
            onTap: () => widget.onTapPlant(plant),
          );
        },
      ),
    );
  }
}

class _MyPlantsIntroCard extends StatelessWidget {
  const _MyPlantsIntroCard({
    required this.guideText,
    required this.onAddPlant,
  });

  final String guideText;
  final VoidCallback onAddPlant;

  @override
  Widget build(BuildContext context) {
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
          Expanded(
            child: Text(
              guideText,
              style: const TextStyle(height: 1.4, color: Colors.black54),
            ),
          ),
          IconButton.filledTonal(onPressed: onAddPlant, icon: const Icon(Icons.add_rounded)),
        ],
      ),
    );
  }
}

class _MyPlantsStatusFilterCard extends StatelessWidget {
  const _MyPlantsStatusFilterCard({
    required this.selectedStatus,
    required this.plants,
    required this.onStatusSelected,
  });

  final PlantStatus? selectedStatus;
  final List<PlantItem> plants;
  final ValueChanged<PlantStatus?> onStatusSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: const Color(0xFFE5ECE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.statusFilterGuide,
            style: const TextStyle(color: Colors.black54, height: 1.45),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _PlantStatusFilterChip(
                label: l10n.allPlants,
                count: plants.length,
                color: const Color(0xFF425249),
                isSelected: selectedStatus == null,
                onTap: () => onStatusSelected(null),
              ),
              for (final status in PlantStatus.values)
                _PlantStatusFilterChip(
                  label: _statusText(status),
                  count: plants.where((plant) => plant.status == status).length,
                  color: _statusColor(status),
                  isSelected: selectedStatus == status,
                  onTap: () => onStatusSelected(status),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlantStatusFilterChip extends StatelessWidget {
  const _PlantStatusFilterChip({
    required this.label,
    required this.count,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final int count;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.16) : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected ? color.withValues(alpha: 0.45) : color.withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 8),
            Text(
              '$label $count',
              style: TextStyle(
                color: const Color(0xFF223028),
                fontSize: 13,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w700,
              ),
            ),
          ],
        ),
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
    final l10n = context.l10n;
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
                Text(l10n.pageLabelManageMonth(_visibleMonth), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                if (monthlyPlants.isEmpty)
                  Text(
                    l10n.calendarNoSchedule,
                    style: const TextStyle(color: Colors.black54),
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
                                Text(l10n.weekdayShort(plant.nextWateringAt.weekday), style: TextStyle(color: _statusColor(plant.status), fontSize: 12)),
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
    final l10n = context.l10n;
    final firstDay = DateTime(month.year, month.month, 1);
    final lastDay = DateTime(month.year, month.month + 1, 0);
    final leadingEmpty = firstDay.weekday % 7;
    final totalCells = leadingEmpty + lastDay.day;
    final trailingEmpty = (7 - (totalCells % 7)) % 7;
    final today = DateTime.now();

    final cells = <Widget>[
      for (final label in <String>['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'].asMap().entries.map((entry) {
        const weekdayMap = [7, 1, 2, 3, 4, 5, 6];
        return l10n.weekdayShort(weekdayMap[entry.key]);
      }))
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
                l10n.monthCalendarTitle(month),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            l10n.calendarBadgeHint,
            style: const TextStyle(color: Colors.black54, height: 1.4),
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
    final l10n = context.l10n;
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
                Text(
                  l10n.statsTitle,
                  style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  strongestPlant == null
                      ? l10n.noPlantsYet
                      : l10n.overallStatsHint(strongestPlant.name),
                  style: const TextStyle(color: Color(0xBFFFFFFF), height: 1.45),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(child: _DarkMetricTile(label: '등록 식물', value: l10n.registeredPlantsCount(total), accent: const Color(0xFF5BC0A5))),
                    const SizedBox(width: 10),
                    Expanded(child: _DarkMetricTile(label: '평균 주기', value: l10n.averageCycle(avgCycle), accent: const Color(0xFFFFD166))),
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
              _SoftStatCard(title: l10n.healthyState, value: l10n.healthyKeep(healthy), detail: l10n.healthyDesc, color: const Color(0xFF2B9348), icon: Icons.favorite_rounded),
              _SoftStatCard(title: l10n.todayWatering, value: l10n.dueTodayCount(dueToday), detail: l10n.todayDesc, color: const Color(0xFFF59E0B), icon: Icons.water_drop_rounded),
              _SoftStatCard(title: l10n.overdue, value: l10n.overdueCount(overdue), detail: l10n.overdueDesc, color: const Color(0xFFDC2626), icon: Icons.crisis_alert_rounded),
              _SoftStatCard(title: '전체 루틴', value: l10n.totalPlantsMetric(total), detail: '기록 중인 식물 수', color: const Color(0xFF2F855A), icon: Icons.local_florist_rounded),
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
                Text(l10n.statsCycleFlow, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(l10n.statsCycleFlowHint, style: const TextStyle(color: Colors.black54)),
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
                              child: Text(l10n.cycleDaysLabel(plant.wateringCycleDays)),
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
                Text('평균 물주기 주기: ${l10n.averageCycle(avgCycle)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
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
                          ? l10n.oldestOverdueHint
                          : l10n.stableFlowHint,
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
    required this.extraBottomPadding,
  });

  final List<_NavItemData> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final double extraBottomPadding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(14, 8, 14, 12 + extraBottomPadding),
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
  const PlantEditSheet({super.key, this.existing, required this.presets});

  final PlantItem? existing;
  final List<PlantPreset> presets;

  @override
  State<PlantEditSheet> createState() => _PlantEditSheetState();
}

class _PlantEditSheetState extends State<PlantEditSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _locationController;
  late final TextEditingController _memoController;
  late final TextEditingController _cycleController;
  late final TextEditingController _presetSearchController;
  late PlantPreset _selectedPreset;
  late DateTime _lastWateredAt;
  late List<String> _photoAssetIds;
  late List<PlantPreset> _availablePresets;

  @override
  void initState() {
    super.initState();
    final current = widget.existing;
    _availablePresets = widget.presets.isNotEmpty ? List<PlantPreset>.from(widget.presets) : List<PlantPreset>.from(kPlantPresets);
    _selectedPreset = _availablePresets.firstWhere(
      (preset) => preset.type == current?.type,
      orElse: () {
        if (current != null) {
          return PlantPreset(
            type: current.type,
            defaultWateringCycleDays: current.wateringCycleDays,
            sunlight: current.sunlight,
            tip: current.memo,
          );
        }
        return _availablePresets.first;
      },
    );
    if (!_availablePresets.any((preset) => preset.type == _selectedPreset.type)) {
      _availablePresets = [_selectedPreset, ..._availablePresets];
    }
    _nameController = TextEditingController(text: current?.name ?? '');
    _locationController = TextEditingController(text: current?.location ?? '');
    _memoController = TextEditingController(text: current?.memo ?? _selectedPreset.tip);
    _cycleController = TextEditingController(text: '${current?.wateringCycleDays ?? _selectedPreset.defaultWateringCycleDays}');
    _presetSearchController = TextEditingController(text: _selectedPreset.type);
    _lastWateredAt = current?.lastWateredAt ?? DateTime.now();
    _photoAssetIds = List<String>.from(current?.photoAssetIds ?? const []);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    _memoController.dispose();
    _cycleController.dispose();
    _presetSearchController.dispose();
    super.dispose();
  }

  void _applyPreset(PlantPreset preset) {
    final previousTip = _selectedPreset.tip;
    setState(() {
      _selectedPreset = preset;
      _presetSearchController.text = preset.type;
      if (_nameController.text.trim().isEmpty || _nameController.text.trim() == widget.existing?.name) {
        _nameController.text = preset.type;
      }
      _cycleController.text = '${preset.defaultWateringCycleDays}';
      if (_memoController.text.trim().isEmpty || _memoController.text.trim() == widget.existing?.memo || _memoController.text.trim() == previousTip) {
        _memoController.text = preset.tip;
      }
    });
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
    final l10n = context.l10n;
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
                                      isEditing ? l10n.plantInfoEdit : l10n.newPlantRegister,
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEditing
                                          ? l10n.plantInfoEditHint
                                          : l10n.newPlantRegisterHint,
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
                                label: l10n.cycleDaysLabel(int.tryParse(_cycleController.text.trim()) ?? _selectedPreset.defaultWateringCycleDays),
                                tint: const Color(0xFFE8F5EC),
                              ),
                              _InfoPill(
                                icon: Icons.wb_sunny_rounded,
                                label: _selectedPreset.sunlight,
                                tint: const Color(0xFFFFF2DE),
                              ),
                              _InfoPill(
                                icon: Icons.photo_library_rounded,
                                label: _photoAssetIds.isEmpty ? l10n.noPhoto : l10n.selectedPhotoCount(_photoAssetIds.length),
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
                      title: l10n.basicInfo,
                      subtitle: l10n.basicInfoHint,
                      child: Column(
                        children: [
                          Autocomplete<PlantPreset>(
                            initialValue: TextEditingValue(text: _selectedPreset.type),
                            displayStringForOption: (option) => option.type,
                            optionsBuilder: (textEditingValue) {
                              final query = textEditingValue.text.trim();
                              if (query.isEmpty) {
                                return _availablePresets.take(8);
                              }
                              return _availablePresets.where((preset) => preset.matchesQuery(query)).take(8);
                            },
                            onSelected: _applyPreset,
                            fieldViewBuilder: (context, textEditingController, focusNode, onFieldSubmitted) {
                              if (_presetSearchController.text != textEditingController.text) {
                                textEditingController.text = _presetSearchController.text;
                                textEditingController.selection = TextSelection.collapsed(offset: textEditingController.text.length);
                              }
                              return TextField(
                                controller: textEditingController,
                                focusNode: focusNode,
                                decoration: _sheetInputDecoration(
                                  label: l10n.searchPlantType,
                                  icon: Icons.search_rounded,
                                  hint: l10n.searchPlantTypeHint,
                                ),
                                onChanged: (value) {
                                  final exact = _availablePresets.cast<PlantPreset?>().firstWhere(
                                        (preset) => preset?.type == value.trim(),
                                        orElse: () => null,
                                      );
                                  if (exact != null && exact.type != _selectedPreset.type) {
                                    _applyPreset(exact);
                                  }
                                },
                                onSubmitted: (_) => onFieldSubmitted(),
                              );
                            },
                            optionsViewBuilder: (context, onSelected, options) {
                              final items = options.toList(growable: false);
                              return Align(
                                alignment: Alignment.topLeft,
                                child: Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    width: MediaQuery.of(context).size.width - 72,
                                    constraints: const BoxConstraints(maxHeight: 280),
                                    margin: const EdgeInsets.only(top: 8),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x14000000),
                                          blurRadius: 24,
                                          offset: Offset(0, 12),
                                        ),
                                      ],
                                    ),
                                    child: ListView.separated(
                                      padding: const EdgeInsets.all(10),
                                      shrinkWrap: true,
                                      itemCount: items.length,
                                      separatorBuilder: (context, index) => const SizedBox(height: 6),
                                      itemBuilder: (context, index) {
                                        final preset = items[index];
                                        return InkWell(
                                          onTap: () => onSelected(preset),
                                          borderRadius: BorderRadius.circular(18),
                                          child: _PlantPresetOptionTile(preset: preset),
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                          const SizedBox(height: 14),
                          _SelectedPlantPresetCard(preset: _selectedPreset),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _nameController,
                            decoration: _sheetInputDecoration(
                              label: l10n.myPlantName,
                              icon: Icons.local_florist_rounded,
                              hint: l10n.myPlantNameExample,
                            ),
                          ),
                          const SizedBox(height: 14),
                          TextField(
                            controller: _locationController,
                            decoration: _sheetInputDecoration(
                              label: l10n.location,
                              icon: Icons.place_rounded,
                              hint: l10n.locationExample,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.schedule_rounded,
                      title: l10n.careRoutine,
                      subtitle: l10n.careRoutineHint,
                      accent: const Color(0xFFFFA94D),
                      child: Column(
                        children: [
                          TextField(
                            controller: _cycleController,
                            keyboardType: TextInputType.number,
                            decoration: _sheetInputDecoration(
                              label: l10n.wateringCycle,
                              icon: Icons.water_drop_rounded,
                              hint: l10n.enterNumbersOnly,
                            ).copyWith(suffixText: l10n.days),
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
                                        Text(
                                          l10n.lastWateredDate,
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
                      title: l10n.memo,
                      subtitle: l10n.memoHintTitle,
                      accent: const Color(0xFF6C8CF6),
                      child: TextField(
                        controller: _memoController,
                        maxLines: 5,
                        decoration: _sheetInputDecoration(
                          label: l10n.memo,
                          icon: Icons.edit_note_rounded,
                          hint: l10n.memoExample,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSectionCard(
                      icon: Icons.photo_library_rounded,
                      title: l10n.plantPhoto,
                      subtitle: l10n.plantPhotoHint,
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
                              label: Text(l10n.selectPhoto),
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
                              child: Text(
                                l10n.noRegisteredPhotos,
                                style: const TextStyle(color: Colors.black54, height: 1.4),
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
                                              child: Text(
                                                l10n.representativePhoto,
                                                style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800),
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
                                ? l10n.photoReorderHint
                                : '${l10n.sunlight}: ${_selectedPreset.sunlight}',
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
                      location: _locationController.text.trim().isEmpty ? l10n.noLocationEnteredFallback() : _locationController.text.trim(),
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
                    isEditing ? l10n.saveChanges : l10n.registerPlant,
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
    final l10n = context.l10n;
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
                    plant.status == PlantStatus.overdue ? l10n.overdueRecommendation(plant.daysUntilWatering.abs()) : l10n.todayWateringTurn,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: OutlinedButton(onPressed: onTap, child: Text(l10n.detailMemo))),
              const SizedBox(width: 10),
              Expanded(child: FilledButton(onPressed: onMarkWatered, child: Text(l10n.markWatered))),
            ],
          ),
        ],
      ),
    );
  }
}

class _PlantPresetAvatar extends StatelessWidget {
  const _PlantPresetAvatar({
    required this.preset,
    this.size = 52,
    this.radius = 18,
  });

  final PlantPreset preset;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final imageUrl = preset.imageUrl;
    if (imageUrl != null && imageUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.network(
          imageUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _fallback(),
        ),
      );
    }
    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFFE8F5EC),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: const Icon(Icons.local_florist_rounded, color: Color(0xFF2F855A), size: 24),
    );
  }
}

class _PlantPresetOptionTile extends StatelessWidget {
  const _PlantPresetOptionTile({required this.preset});

  final PlantPreset preset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          _PlantPresetAvatar(preset: preset, size: 50, radius: 16),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.type,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.cycleDaysLabel(preset.defaultWateringCycleDays)} · ${preset.sunlight}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  preset.tip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPlantPresetCard extends StatelessWidget {
  const _SelectedPlantPresetCard({required this.preset});

  final PlantPreset preset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3ECE6)),
      ),
      child: Row(
        children: [
          _PlantPresetAvatar(preset: preset, size: 58, radius: 18),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  preset.type,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.defaultCycleDaysLabel(preset.defaultWateringCycleDays)} · ${preset.sunlight}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  preset.tip,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
              ],
            ),
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
    final l10n = context.l10n;
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
                  Text(l10n.afterDaysLabel(plant.daysUntilWatering, plant.location)),
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
  const PlantListCard({
    super.key,
    required this.plant,
    required this.onTap,
    this.presetImageUrl,
  });

  final PlantItem plant;
  final VoidCallback onTap;
  final String? presetImageUrl;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(plant.status);
    final l10n = context.l10n;
    final statusGlow = switch (plant.status) {
      PlantStatus.overdue => color.withValues(alpha: 0.18),
      PlantStatus.today => color.withValues(alpha: 0.14),
      PlantStatus.soon => color.withValues(alpha: 0.10),
      PlantStatus.healthy => const Color(0x11000000),
    };
    final statusBanner = switch (plant.status) {
      PlantStatus.overdue => const LinearGradient(colors: [Color(0xFFFFE2E0), Color(0xFFFFF5F4)]),
      PlantStatus.today => const LinearGradient(colors: [Color(0xFFFFF0D7), Color(0xFFFFF8EC)]),
      PlantStatus.soon => const LinearGradient(colors: [Color(0xFFEAF3FF), Color(0xFFF6FAFF)]),
      PlantStatus.healthy => const LinearGradient(colors: [Color(0xFFEAF6EE), Color(0xFFF6FBF8)]),
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: color.withValues(alpha: 0.18)),
          boxShadow: [BoxShadow(color: statusGlow, blurRadius: 20, offset: const Offset(0, 10))],
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
              decoration: BoxDecoration(gradient: statusBanner),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
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
                  StatusChip(status: plant.status),
                ],
              ),
            ),
            IntrinsicHeight(
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
                        else if (presetImageUrl != null && presetImageUrl!.isNotEmpty)
                          Image.network(
                            presetImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: color.withValues(alpha: 0.14),
                              child: Icon(Icons.local_florist_rounded, color: color, size: 42),
                            ),
                          )
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
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
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
                          const SizedBox(height: 12),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              _InfoPill(
                                icon: Icons.calendar_month_rounded,
                                label: l10n.nextDateLabel(plant.nextWateringAt),
                                tint: const Color(0xFFEAF5EE),
                              ),
                              _InfoPill(
                                icon: Icons.water_drop_rounded,
                                label: l10n.cycleDaysLabel(plant.wateringCycleDays),
                                tint: const Color(0xFFFFF0D9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            plant.memo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.black54, height: 1.45),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
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

class _HomeMiniStat extends StatelessWidget {
  const _HomeMiniStat({
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE6EDE8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF66756C), fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(value, style: const TextStyle(color: Color(0xFF111A16), fontSize: 22, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _HomeOverviewCard extends StatelessWidget {
  const _HomeOverviewCard({
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
        border: Border.all(color: const Color(0xFFE4ECE6)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(Icons.circle, color: accent, size: 14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Color(0xFF66756C), fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Text(subtitle, style: const TextStyle(color: Colors.black54, height: 1.4)),
              ],
            ),
          ),
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
  final l10n = AppLocalizations.forLocale(WidgetsBinding.instance.platformDispatcher.locale);
  switch (status) {
    case PlantStatus.healthy:
      return l10n.healthy;
    case PlantStatus.soon:
      return l10n.soon;
    case PlantStatus.today:
      return l10n.todayWatering;
    case PlantStatus.overdue:
      return l10n.overdue;
  }
}

String _statusDescription(PlantStatus status) {
  final l10n = AppLocalizations.forLocale(WidgetsBinding.instance.platformDispatcher.locale);
  switch (status) {
    case PlantStatus.healthy:
      return l10n.healthyDesc;
    case PlantStatus.soon:
      return l10n.soonDesc;
    case PlantStatus.today:
      return l10n.todayDesc;
    case PlantStatus.overdue:
      return l10n.overdueDesc;
  }
}

String _dateLabel(DateTime date) {
  return AppLocalizations.forLocale(WidgetsBinding.instance.platformDispatcher.locale).dateLabel(date);
}
