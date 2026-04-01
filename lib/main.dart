import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:photo_manager/photo_manager.dart';

import 'ad_service.dart';
import 'app_localizations.dart';
import 'app_settings_service.dart';
import 'app_user_service.dart';
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

const double _baseBottomOverlayPadding = 112;

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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: Color(0xFFF6FBF7),
          surfaceTintColor: Colors.transparent,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
        ),
        timePickerTheme: TimePickerThemeData(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          hourMinuteShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          dayPeriodShape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
        datePickerTheme: DatePickerThemeData(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
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
  AppUserIdentity? _appUserIdentity;
  bool _isSigningIn = false;
  bool _isSyncing = false;
  bool _isLoading = true;
  List<PlantPreset> _plantPresets = List<PlantPreset>.from(kPlantPresets);
  List<PlantActivityEntry> _activityLog = [];
  AppSettings _settings = const AppSettings(
    notificationsEnabled: true,
    notificationHour: 9,
    notificationMinute: 0,
    notifyDayBefore: true,
    notifySameDay: true,
    allowSnooze: true,
  );

  final List<PlantItem> _plants = [];

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
    final activityLog = await PlantStorageService.loadActivityLog();
    final loadedSettings = await AppSettingsService.load();
    final loadedPresets = await PlantPresetService.loadPresets();
    final savedAuthUser = await AuthSessionService.loadUser();
    final appUserIdentity = await AppUserIdentityService.ensureIdentity();
    if (stored.isNotEmpty) {
      _plants
        ..clear()
        ..addAll(stored);
    }
    _activityLog = activityLog;
    if (_activityLog.isEmpty && _plants.isNotEmpty) {
      _activityLog = _plants
          .map(
            (plant) => _buildActivityEntry(
              plant: plant,
              type: PlantActivityType.registered,
              occurredAt: plant.lastWateredAt,
              detail: null,
            ),
          )
          .toList();
    }
    if (loadedPresets.isNotEmpty) {
      _plantPresets = loadedPresets;
    }
    final backfilledPresetImages = _applyPresetImagesToPlants(
      _plants,
      _plantPresets,
    );
    _settings = loadedSettings;
    await _syncNotificationPermissionState(showToast: false);
    _authUser = savedAuthUser;
    _appUserIdentity = appUserIdentity;
    try {
      _appUserIdentity = savedAuthUser == null
          ? await AppUserService.registerDeviceUser(appUserIdentity)
          : await AppUserService.linkSocialAccount(
              identity: appUserIdentity,
              authUser: savedAuthUser,
            );
      await AppUserIdentityService.save(_appUserIdentity!);
    } catch (_) {
      _appUserIdentity = appUserIdentity;
    }
    if (savedAuthUser != null) {
      await _restoreCloudDataIfNeeded(savedAuthUser);
    }
    if (backfilledPresetImages) {
      await PlantStorageService.savePlants(_plants);
    }
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _persistPlants() async {
    await PlantStorageService.savePlants(_plants);
    await PlantStorageService.saveActivityLog(_activityLog);
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    await _syncCurrentStateIfLinked();
  }

  Future<void> _persistSettingsOnly() async {
    await AppSettingsService.save(_settings);
    await NotificationService.rescheduleForPlants(_plants, settings: _settings);
    await _syncCurrentStateIfLinked();
  }

  void _appendActivity(PlantActivityEntry entry) {
    _appendActivityToList(_activityLog, entry);
  }

  Future<void> _syncNotificationPermissionState({required bool showToast}) async {
    final allowed = await NotificationService.areNotificationsAllowed();
    if (!mounted) return;
    if (allowed || !_settings.notificationsEnabled) return;

    setState(() {
      _settings = _settings.copyWith(notificationsEnabled: false);
    });
    await _persistSettingsOnly();
    if (!mounted || !showToast) return;
    _showToast(context.l10n.notificationPermissionDenied);
  }

  Future<void> _sendTestNotification() async {
    await NotificationService.scheduleLockScreenTestNotifications(
      _plants,
      settings: _settings,
    );
    if (!mounted) return;
    _showToast(context.l10n.testNotificationScheduled);
  }

  Future<void> _togglePinnedHomePlant(PlantItem plant) async {
    setState(() {
      _settings = _settings.copyWith(
        pinnedHomePlantId: _settings.pinnedHomePlantId == plant.id
            ? null
            : plant.id,
        clearPinnedHomePlantId: _settings.pinnedHomePlantId == plant.id,
      );
    });
    await _persistSettingsOnly();
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
            activityLog: List<PlantActivityEntry>.from(_activityLog),
            settings: _settings,
          );
          await SyncStateService.markSynced(user, result.updatedAt);
        }
        return;
      }

      final hasLocalData = _plants.isNotEmpty;
      final serverNewer =
          profile.updatedAt != null &&
          sameUser &&
          syncState.lastSyncedAt != null &&
          profile.updatedAt!.isAfter(syncState.lastSyncedAt!);

      if (!hasLocalData || (sameUser && !syncState.isDirty && serverNewer)) {
        await _applySyncedData(
          user,
          profile.plants,
          profile.activityLog,
          profile.settings,
          profile.updatedAt,
        );
      }
    } catch (_) {
      // Keep local data when cloud sync is unavailable during bootstrap.
    }
  }

  Future<void> _applySyncedData(
    AppAuthUser user,
    List<PlantItem> plants,
    List<PlantActivityEntry> activityLog,
    AppSettings settings,
    DateTime? syncedAt,
  ) async {
    _plants
      ..clear()
      ..addAll(plants.map((item) => item.copy()));
    _applyPresetImagesToPlants(_plants, _plantPresets);
    _activityLog
      ..clear()
      ..addAll(activityLog);
    _settings = settings;
    await PlantStorageService.savePlants(_plants);
    await PlantStorageService.saveActivityLog(_activityLog);
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
        activityLog: List<PlantActivityEntry>.from(_activityLog),
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

  PlantItem? _findPlantById(String plantId) {
    final index = _plants.indexWhere((item) => item.id == plantId);
    if (index == -1) {
      return null;
    }
    return _plants[index];
  }

  void _markWatered(PlantItem plant) {
    final wateredAt = DateTime.now();
    final target = _findPlantById(plant.id) ?? plant;
    setState(() {
      target.lastWateredAt = wateredAt;
      _appendActivity(
        _buildActivityEntry(
          plant: target,
          type: PlantActivityType.watered,
          occurredAt: wateredAt,
        ),
      );
    });
    _persistPlants();
    AdService.showInterstitialIfNeeded();
    _showToast(AppLocalizations.of(context).wateredToast(target.name));
  }

  void _markPlantsWatered(List<PlantItem> plants) {
    if (plants.isEmpty) return;
    setState(() {
      final wateredAt = DateTime.now();
      for (final plant in plants) {
        final target = _findPlantById(plant.id) ?? plant;
        target.lastWateredAt = wateredAt;
        _appendActivity(
          _buildActivityEntry(
            plant: target,
            type: PlantActivityType.watered,
            occurredAt: wateredAt,
          ),
        );
      }
    });
    _persistPlants();
    AdService.showInterstitialIfNeeded();
    _showToast(context.l10n.bulkTasksDoneToast(plants.length));
  }

  void _savePlant(PlantItem plant, {bool isNew = false}) {
    setState(() {
      if (isNew) {
        _plants.add(plant);
        _appendActivity(
          _buildActivityEntry(
            plant: plant,
            type: PlantActivityType.registered,
          ),
        );
      } else {
        final index = _plants.indexWhere((item) => item.id == plant.id);
        if (index != -1) {
          final previous = _plants[index];
          if (previous.location != plant.location) {
            _appendActivity(
              _buildActivityEntry(
                plant: plant,
                type: PlantActivityType.moved,
                detail: '${previous.location} -> ${plant.location}',
              ),
            );
          }
          if (previous.name != plant.name ||
              previous.type != plant.type ||
              previous.wateringCycleDays != plant.wateringCycleDays ||
              previous.memo != plant.memo ||
              previous.sunlight != plant.sunlight ||
              previous.photoAssetIds.join(',') != plant.photoAssetIds.join(',')) {
            _appendActivity(
              _buildActivityEntry(
                plant: plant,
                type: PlantActivityType.updated,
              ),
            );
          }
          _plants[index] = plant;
        }
      }
    });
    _persistPlants();
    AdService.showInterstitialIfNeeded();
    _showToast(
      isNew ? context.l10n.plantAddedToast : context.l10n.plantUpdatedToast,
    );
  }

  void _deletePlant(String plantId) {
    setState(() {
      final targetIndex = _plants.indexWhere((item) => item.id == plantId);
      if (targetIndex != -1) {
        _appendActivity(
          _buildActivityEntry(
            plant: _plants[targetIndex],
            type: PlantActivityType.deleted,
          ),
        );
      }
      _plants.removeWhere((item) => item.id == plantId);
    });
    _persistPlants();
    _showToast(context.l10n.plantDeletedToast);
  }

  void _markRepotted(PlantItem plant) {
    final target = _findPlantById(plant.id) ?? plant;
    setState(() {
      _appendActivity(
        _buildActivityEntry(
          plant: target,
          type: PlantActivityType.repotted,
        ),
      );
    });
    _persistPlants();
    _showToast(context.l10n.repottedToast(target.name));
  }

  Future<void> _openAddPlantSheet() async {
    final result = await showModalBottomSheet<PlantEditSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => PlantEditSheet(presets: _plantPresets),
    );
    if (result?.plant != null) {
      _savePlant(result!.plant!, isNew: true);
    }
  }

  Future<void> _openEditPlantSheet(PlantItem plant) async {
    final result = await showModalBottomSheet<PlantEditSheetResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) =>
          PlantEditSheet(existing: plant.copy(), presets: _plantPresets),
    );
    if (result == null) return;
    if (result.deletedPlantId != null) {
      _deletePlant(result.deletedPlantId!);
      return;
    }
    if (result.plant != null) {
      _savePlant(result.plant!);
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
          onRepotted: () {
            _markRepotted(plant);
            Navigator.of(detailContext).pop();
          },
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog() async {
    await _syncNotificationPermissionState(showToast: false);
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) {
        return SettingsDialog(
          authUser: _authUser,
          isSigningIn: _isSigningIn,
          settings: _settings,
          onSendTestNotification: _sendTestNotification,
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
                Text(
                  l10n.syncChoiceTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  l10n.syncChoiceBody,
                  style: const TextStyle(color: Colors.black54, height: 1.5),
                ),
                const SizedBox(height: 16),
                _SyncSummaryCard(
                  title: l10n.syncDeviceSummary,
                  plantCount: _plants.length,
                ),
                const SizedBox(height: 10),
                _SyncSummaryCard(
                  title: l10n.syncServerSummary,
                  plantCount: profile.plants.length,
                ),
                const SizedBox(height: 18),
                _SyncChoiceButton(
                  title: l10n.syncUseServer,
                  subtitle: l10n.syncChoiceServerHint,
                  accent: const Color(0xFF4C8BF5),
                  onTap: () =>
                      Navigator.of(context).pop(_SyncResolution.server),
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
    final l10n = context.l10n;
    final turnedOn = !_settings.notificationsEnabled && settings.notificationsEnabled;

    if (turnedOn) {
      final granted = await NotificationService.requestNotificationPermission();
      if (!mounted) return;
      if (!granted) {
        setState(() {
          _settings = settings.copyWith(notificationsEnabled: false);
        });
        await _persistSettingsOnly();
        if (!mounted) return;
        _showToast(l10n.notificationPermissionRequired);
        return;
      }
    }

    setState(() {
      _settings = settings;
    });
    await _persistSettingsOnly();
    await _syncNotificationPermissionState(showToast: false);
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
        final currentIdentity =
            _appUserIdentity ?? await AppUserIdentityService.ensureIdentity();
        try {
          _appUserIdentity = await AppUserService.linkSocialAccount(
            identity: currentIdentity,
            authUser: user,
          );
          await AppUserIdentityService.save(_appUserIdentity!);
        } catch (_) {
          _appUserIdentity = currentIdentity;
        }
        final profile = await PlantSyncService.fetchProfile(user);
        final hasLocalData = _plants.isNotEmpty;
        if (profile.exists && hasLocalData) {
          final resolution = await _showSyncChoiceDialog(profile: profile);
          if (!mounted || resolution == null) return;
          switch (resolution) {
            case _SyncResolution.server:
              await _applySyncedData(
                user,
                profile.plants,
                profile.activityLog,
                profile.settings,
                profile.updatedAt,
              );
              syncToast = l10n.syncImported;
              break;
            case _SyncResolution.local:
              final uploaded = await PlantSyncService.replaceWithLocal(
                user: user,
                plants: List<PlantItem>.from(
                  _plants.map((item) => item.copy()),
                ),
                activityLog: List<PlantActivityEntry>.from(_activityLog),
                settings: _settings,
              );
              await SyncStateService.markSynced(user, uploaded.updatedAt);
              syncToast = l10n.syncUploaded;
              break;
            case _SyncResolution.merge:
              final merged = await PlantSyncService.mergeWithServer(
                user: user,
                localPlants: List<PlantItem>.from(
                  _plants.map((item) => item.copy()),
                ),
                localActivityLog: List<PlantActivityEntry>.from(_activityLog),
                localSettings: _settings,
              );
              await _applySyncedData(
                user,
                merged.plants,
                merged.activityLog,
                merged.settings,
                merged.updatedAt,
              );
              syncToast = l10n.syncMerged;
              break;
          }
        } else if (profile.exists && !hasLocalData) {
          await _applySyncedData(
            user,
            profile.plants,
            profile.activityLog,
            profile.settings,
            profile.updatedAt,
          );
          syncToast = l10n.syncImported;
        } else if (!profile.exists && hasLocalData) {
          final uploaded = await PlantSyncService.replaceWithLocal(
            user: user,
            plants: List<PlantItem>.from(_plants.map((item) => item.copy())),
            activityLog: List<PlantActivityEntry>.from(_activityLog),
            settings: _settings,
          );
          await SyncStateService.markSynced(user, uploaded.updatedAt);
          syncToast = l10n.syncUploaded;
        }
        setState(() {
          _authUser = user;
        });
        _showToast(
          syncToast ??
              l10n.loginSuccessToast(
                user.provider == 'google' ? 'Google' : 'Apple',
              ),
        );
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
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final bottomInset = MediaQuery.of(context).viewPadding.bottom;
    final bannerHeight = _bannerAd?.size.height.toDouble() ?? 0;
    final bottomOverlayPadding =
        _baseBottomOverlayPadding + bottomInset + bannerHeight;

    final pages = [
      HomeDashboardTab(
        plants: _plants,
        presets: _plantPresets,
        bottomPadding: bottomOverlayPadding,
        pinnedPlantId: _settings.pinnedHomePlantId,
        onTapPlant: _openPlantDetail,
        onMarkWatered: _markWatered,
        onMarkAllWatered: _markPlantsWatered,
      ),
      OrganizedMyPlantsTab(
        plants: _plants,
        presets: _plantPresets,
        bottomPadding: bottomOverlayPadding,
        onTapPlant: _openPlantDetail,
        onEditPlant: _openEditPlantSheet,
        onWaterPlant: _markWatered,
        onRepotPlant: _markRepotted,
        pinnedPlantId: _settings.pinnedHomePlantId,
        onTogglePinnedPlant: _togglePinnedHomePlant,
        onAddPlant: _openAddPlantSheet,
      ),
      CalendarTab(
        plants: _plants,
        bottomPadding: bottomOverlayPadding,
        onMarkPlantsWatered: _markPlantsWatered,
      ),
      StatsTab(
        plants: _plants,
        activities: _activityLog,
        bottomPadding: bottomOverlayPadding + 56,
      ),
    ];
    final l10n = context.l10n;
    final navItems = [
      _NavItemData(
        label: l10n.home,
        subtitle: l10n.homeSubtitle,
        icon: Icons.home_rounded,
        color: const Color(0xFF2F855A),
      ),
      _NavItemData(
        label: l10n.myPlants,
        subtitle: l10n.myPlantsSubtitle,
        icon: Icons.local_florist_rounded,
        color: const Color(0xFF2F855A),
      ),
      _NavItemData(
        label: l10n.calendar,
        subtitle: l10n.calendarSubtitle,
        icon: Icons.calendar_month_rounded,
        color: const Color(0xFF2F855A),
      ),
      _NavItemData(
        label: l10n.stats,
        subtitle: l10n.statsSubtitle,
        icon: Icons.bar_chart_rounded,
        color: const Color(0xFF2F855A),
      ),
    ];
    final activeNav = navItems[_currentIndex];
    final isHomeTab = _currentIndex == 0;
    final bannerWidth = MediaQuery.sizeOf(context).width.truncate();
    if (_bannerWidth != bannerWidth && !_isBannerLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadBannerForWidth(bannerWidth);
      });
    }

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: isHomeTab,
      appBar: AppBar(
        toolbarHeight: 92,
        backgroundColor: isHomeTab
            ? Colors.transparent
            : const Color(0xFFF6FBF7),
        surfaceTintColor: Colors.transparent,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleSpacing: 20,
        title: isHomeTab
            ? null
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    activeNav.label,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    activeNav.subtitle,
                    maxLines: 2,
                    softWrap: true,
                    overflow: TextOverflow.visible,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.3,
                    ),
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
      body: Stack(
        children: [
          Positioned.fill(
            child: SafeArea(
              top: !isHomeTab,
              bottom: false,
              child: pages[_currentIndex],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GardenBottomNav(
                  items: navItems,
                  selectedIndex: _currentIndex,
                  onSelected: (value) => setState(() => _currentIndex = value),
                  extraBottomPadding: _bannerAd == null
                      ? MediaQuery.of(context).viewPadding.bottom
                      : 0,
                ),
                if (_bannerAd != null)
                  Container(
                    width: double.infinity,
                    color: Colors.transparent,
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewPadding.bottom,
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: _bannerAd!.size.height.toDouble(),
                      child: AdWidget(ad: _bannerAd!),
                    ),
                  ),
              ],
            ),
          ),
          if (_currentIndex == 1)
            Positioned(
              right: 20,
              bottom:
                  (_bannerAd?.size.height.toDouble() ?? 0) +
                  MediaQuery.of(context).viewPadding.bottom +
                  108,
              child: FloatingActionButton(
                onPressed: _openAddPlantSheet,
                backgroundColor: const Color(0xFF2F855A),
                foregroundColor: Colors.white,
                elevation: 0,
                highlightElevation: 0,
                hoverElevation: 0,
                focusElevation: 0,
                disabledElevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Icon(Icons.add_rounded, size: 30),
              ),
            ),
        ],
      ),
    );
  }
}

enum _SyncResolution { server, local, merge }

class _SyncSummaryCard extends StatelessWidget {
  const _SyncSummaryCard({required this.title, required this.plantCount});

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
            child: Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            '$plantCount',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
          ),
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
            Text(
              title,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: const TextStyle(color: Colors.black54, height: 1.4),
            ),
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
    required this.onMarkAllWatered,
  });

  final List<PlantItem> plants;
  final ValueChanged<PlantItem> onTapPlant;
  final ValueChanged<PlantItem> onMarkWatered;
  final ValueChanged<List<PlantItem>> onMarkAllWatered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final todayTasks = plants
        .where(
          (plant) =>
              plant.status == PlantStatus.today ||
              plant.status == PlantStatus.overdue,
        )
        .toList();
    final soonTasks = plants
        .where((plant) => plant.status == PlantStatus.soon)
        .toList();
    final healthyCount = plants
        .where((plant) => plant.status == PlantStatus.healthy)
        .length;
    final streakMessage = l10n.todayTaskStreak(todayTasks.isNotEmpty);
    final primaryPlant = todayTasks.isNotEmpty
        ? todayTasks.first
        : (soonTasks.isNotEmpty
              ? soonTasks.first
              : (plants.isNotEmpty ? plants.first : null));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 112),
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
                          style: const TextStyle(
                            color: Color(0xFF66756C),
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.plantCount(plants.length),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                todayTasks.isEmpty
                    ? l10n.todayCareRelaxed
                    : l10n.todayPlantsHeadline(todayTasks.length),
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
                    Expanded(
                      child: _HomeMiniStat(
                        label: l10n.todayTasks,
                        value: l10n.highlightValueCount(todayTasks.length),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HomeMiniStat(
                        label: l10n.soonNeed,
                        value: l10n.highlightValueCount(soonTasks.length),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _HomeMiniStat(
                        label: l10n.healthyState,
                        value: l10n.highlightValueCount(healthyCount),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _HomeOverviewCard(
          title: l10n.todayPriority,
          value: todayTasks.isEmpty
              ? l10n.relaxed
              : l10n.priorityValue(todayTasks.length),
          subtitle: todayTasks.isEmpty
              ? l10n.noUrgentPlants
              : (primaryPlant == null
                    ? l10n.recommendWateringNow
                    : '${primaryPlant.name} · ${primaryPlant.location}'),
          accent: todayTasks.isEmpty
              ? const Color(0xFF8AA39A)
              : const Color(0xFF2F855A),
        ),
        const SizedBox(height: 12),
        _HomeOverviewCard(
          title: l10n.nextCheck,
          value: soonTasks.isEmpty
              ? l10n.stable
              : l10n.scheduledValue(soonTasks.length),
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
        _SectionTitle(
          title: l10n.checkSoonPlants,
          subtitle: l10n.checkSoonPlantsHint,
        ),
        const SizedBox(height: 12),
        if (soonTasks.isEmpty)
          EmptyCard(message: l10n.noSoonPlants)
        else
          ...soonTasks.map(
            (plant) =>
                CompactPlantCard(plant: plant, onTap: () => onTapPlant(plant)),
          ),
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
    final sortedPlants = _sortPlantsByUrgency(widget.plants);
    final filteredPlants = _selectedStatus == null
        ? sortedPlants
        : sortedPlants
              .where((plant) => plant.status == _selectedStatus)
              .toList();
    final urgentPlantsCount = widget.plants
        .where((plant) => plant.status != PlantStatus.healthy)
        .length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 110),
        itemCount: filteredPlants.length + 3,
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
          if (index == 2) {
            return _MyPlantsPriorityCard(
              urgentPlantsCount: urgentPlantsCount,
              totalPlantsCount: filteredPlants.length,
              isFiltered: _selectedStatus != null,
            );
          }
          final plant = filteredPlants[index - 3];
          final matchedPreset = widget.presets.cast<PlantPreset?>().firstWhere(
            (preset) => preset?.type == plant.type,
            orElse: () => null,
          );
          return PlantListCard(
            plant: plant,
            presetImageUrl: matchedPreset?.imageUrl,
            priorityRank: _selectedStatus == null ? index - 2 : null,
            onTap: () => widget.onTapPlant(plant),
          );
        },
      ),
    );
  }
}

class _MyPlantsIntroCard extends StatelessWidget {
  const _MyPlantsIntroCard({required this.guideText, required this.onAddPlant});

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
          IconButton.filledTonal(
            onPressed: onAddPlant,
            icon: const Icon(Icons.add_rounded),
          ),
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

class _MyPlantsPriorityCard extends StatelessWidget {
  const _MyPlantsPriorityCard({
    required this.urgentPlantsCount,
    required this.totalPlantsCount,
    required this.isFiltered,
  });

  final int urgentPlantsCount;
  final int totalPlantsCount;
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = urgentPlantsCount == 0
        ? const Color(0xFF2F855A)
        : const Color(0xFFDC2626);
    final headline = urgentPlantsCount == 0
        ? l10n.noUrgentPlants
        : l10n.priorityValue(urgentPlantsCount);
    final subtitle = isFiltered
        ? l10n.statusFilterGuide
        : (urgentPlantsCount == 0
              ? l10n.todayTaskStreak(false)
              : l10n.todayTodoHint);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: urgentPlantsCount == 0
              ? const [Color(0xFFE8F6EC), Color(0xFFF6FBF8)]
              : const [Color(0xFFFFE3DE), Color(0xFFFFF7F4)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: accent.withValues(alpha: 0.15)),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.78),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Icon(
              urgentPlantsCount == 0
                  ? Icons.spa_rounded
                  : Icons.priority_high_rounded,
              color: accent,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.todayPriority,
                  style: TextStyle(color: accent, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                Text(
                  headline,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          _HomeMiniStat(label: l10n.allPlants, value: '$totalPlantsCount'),
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
          color: isSelected
              ? color.withValues(alpha: 0.16)
              : color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: isSelected
                ? color.withValues(alpha: 0.45)
                : color.withValues(alpha: 0.18),
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
  const CalendarTab({
    super.key,
    required this.plants,
    required this.bottomPadding,
    required this.onMarkPlantsWatered,
  });

  final List<PlantItem> plants;
  final double bottomPadding;
  final ValueChanged<List<PlantItem>> onMarkPlantsWatered;

  @override
  State<CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends State<CalendarTab> {
  static const int _initialWeekPage = 1200;
  late DateTime _selectedDate;
  late DateTime _weekStart;
  late final PageController _weekPageController;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _weekStart = _startOfWeek(_selectedDate);
    _weekPageController = PageController(initialPage: _initialWeekPage);
  }

  @override
  void dispose() {
    _weekPageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final weekDays = List<DateTime>.generate(
      7,
      (index) => _weekStart.add(Duration(days: index)),
    );
    final weeklyPlants = widget.plants
        .where((plant) {
          final next = plant.nextWateringAt;
          final start = _weekStart;
          final end = _weekStart.add(const Duration(days: 6));
          return !next.isBefore(DateTime(start.year, start.month, start.day)) &&
              !next.isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59));
        })
        .toList()
      ..sort((a, b) => a.nextWateringAt.compareTo(b.nextWateringAt));
    final selectedPlants = widget.plants
        .where((plant) {
          final next = plant.nextWateringAt;
          return next.year == _selectedDate.year &&
              next.month == _selectedDate.month &&
              next.day == _selectedDate.day;
        })
        .toList()
      ..sort((a, b) => a.daysUntilWatering.compareTo(b.daysUntilWatering));

    return ListView(
      padding: EdgeInsets.fromLTRB(20, 20, 20, widget.bottomPadding),
      children: [
        _GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 30,
          blurSigma: 14,
          backgroundColor: Colors.white.withValues(alpha: 0.46),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _weekPageController.previousPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.45),
                    ),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          l10n.weekRangeLabel(_weekStart, weekDays.last),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF17342A),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.weeklyPlantsCount(weeklyPlants.length),
                          style: const TextStyle(
                            color: Color(0xFF5F746A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _weekPageController.nextPage(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                      );
                    },
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.white.withValues(alpha: 0.45),
                    ),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              SizedBox(
                height: 110,
                child: PageView.builder(
                  controller: _weekPageController,
                  onPageChanged: (page) {
                    final nextWeekStart = _weekStartFromPage(page);
                    setState(() {
                      _weekStart = nextWeekStart;
                      if (_selectedDate.isBefore(_weekStart) ||
                          _selectedDate.isAfter(
                            _weekStart.add(const Duration(days: 6)),
                          )) {
                        _selectedDate = _weekStart;
                      }
                    });
                  },
                  itemBuilder: (context, page) {
                    final pageWeekStart = _weekStartFromPage(page);
                    final pageWeekDays = List<DateTime>.generate(
                      7,
                      (index) => pageWeekStart.add(Duration(days: index)),
                    );
                    return Row(
                      children: [
                        for (var i = 0; i < pageWeekDays.length; i++) ...[
                          if (i > 0) const SizedBox(width: 8),
                          Expanded(
                            child: _CalendarDayCell(
                              date: pageWeekDays[i],
                              isToday: _isSameDate(pageWeekDays[i], DateTime.now()),
                              isSelected: _isSameDate(pageWeekDays[i], _selectedDate),
                              dueCount: _dueCountForDay(pageWeekDays[i]),
                              onTap: () {
                                setState(() {
                                  _selectedDate = pageWeekDays[i];
                                  _weekStart = pageWeekStart;
                                });
                              },
                            ),
                          ),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        _GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 28,
          blurSigma: 12,
          backgroundColor: const Color(0xFFF4FFF8).withValues(alpha: 0.46),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.thisWeekScheduleTitle,
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 8),
              Text(
                weeklyPlants.isEmpty ? l10n.calendarNoSchedule : l10n.thisWeekScheduleHint,
                style: const TextStyle(color: Colors.black54, height: 1.45),
              ),
              const SizedBox(height: 14),
              if (weeklyPlants.isEmpty)
                Text(
                  l10n.noWeeklyPlants,
                  style: const TextStyle(color: Colors.black54),
                )
              else
                ...weeklyPlants.map(
                  (plant) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: _statusColor(plant.status).withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Center(
                            child: Text(
                              '${plant.nextWateringAt.day}',
                              style: TextStyle(
                                color: _statusColor(plant.status),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                plant.name,
                                style: const TextStyle(fontWeight: FontWeight.w800),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${plant.type} · ${plant.location}',
                                style: const TextStyle(color: Colors.black54),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          _statusText(plant.status),
                          style: TextStyle(
                            color: _statusColor(plant.status),
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _GlassPanel(
          padding: const EdgeInsets.all(18),
          borderRadius: 28,
          blurSigma: 12,
          backgroundColor: Colors.white.withValues(alpha: 0.5),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.selectedDateLabel(_selectedDate),
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              if (selectedPlants.isEmpty)
                Text(
                  l10n.noPlantsForSelectedDate,
                  style: const TextStyle(color: Colors.black54),
                )
              else ...[
                ...selectedPlants.map(
                  (plant) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.42),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: _statusColor(plant.status),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                          child: Text(
                              l10n.wateringPlannedLabel(plant.name),
                              style: const TextStyle(fontWeight: FontWeight.w700),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                FilledButton(
                  onPressed: () => widget.onMarkPlantsWatered(selectedPlants),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF2F855A),
                    foregroundColor: Colors.white,
                    minimumSize: const Size.fromHeight(52),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  child: Text(l10n.waterInAdvance),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  DateTime _startOfWeek(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final offset = normalized.weekday % 7;
    return normalized.subtract(Duration(days: offset));
  }

  DateTime _weekStartFromPage(int page) {
    final offsetWeeks = page - _initialWeekPage;
    return _startOfWeek(DateTime.now()).add(Duration(days: offsetWeeks * 7));
  }

  bool _isSameDate(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  int _dueCountForDay(DateTime target) {
    return widget.plants.where((plant) {
      final next = plant.nextWateringAt;
      return next.year == target.year &&
          next.month == target.month &&
          next.day == target.day;
    }).length;
  }
}

class _CalendarDayCell extends StatelessWidget {
  const _CalendarDayCell({
    required this.date,
    required this.isToday,
    required this.isSelected,
    required this.dueCount,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final bool isSelected;
  final int dueCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final hasEvent = dueCount > 0;
    final weekday = context.l10n.weekdayShort(date.weekday);
    const badgeSlotHeight = 21.0;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutCubic,
        height: 110,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF2F855A).withValues(alpha: 0.92)
              : Colors.white.withValues(alpha: 0.38),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: isSelected
                ? const Color(0xFF2F855A)
                : Colors.white.withValues(alpha: 0.65),
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? const Color(0x332F855A)
                  : const Color(0x11000000),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          children: [
            Text(
              weekday,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white70 : const Color(0xFF6A7C72),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${date.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isSelected ? Colors.white : const Color(0xFF19342A),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: badgeSlotHeight,
              child: Center(
                child: hasEvent
                    ? Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.18)
                              : const Color(0xFF53B97C),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$dueCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      )
                    : Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white54
                              : (isToday
                                    ? const Color(0xFF53B97C)
                                    : const Color(0x22000000)),
                          shape: BoxShape.circle,
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

class StatsTab extends StatefulWidget {
  const StatsTab({
    super.key,
    required this.plants,
    required this.activities,
    required this.bottomPadding,
  });

  final List<PlantItem> plants;
  final List<PlantActivityEntry> activities;
  final double bottomPadding;

  @override
  State<StatsTab> createState() => _StatsTabState();
}

class _StatsTabState extends State<StatsTab> {
  static const int _pageSize = 20;
  late final ScrollController _scrollController;
  int _visibleCount = _pageSize;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_handleScroll);
  }

  @override
  void didUpdateWidget(covariant StatsTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.activities.length != widget.activities.length) {
      _visibleCount = _pageSize;
    }
  }

  void _handleScroll() {
    if (!_scrollController.hasClients) {
      return;
    }
    final position = _scrollController.position;
    if (position.pixels < position.maxScrollExtent - 240) {
      return;
    }
    final totalCount = widget.activities.length;
    if (_visibleCount >= totalCount) {
      return;
    }
    setState(() {
      _visibleCount = (_visibleCount + _pageSize).clamp(0, totalCount);
    });
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_handleScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final recentActivities = [...widget.activities]
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final visibleActivities = recentActivities.take(_visibleCount).toList();
    final actionCounts = <PlantActivityType, int>{
      for (final type in PlantActivityType.values) type: 0,
    };
    for (final activity in recentActivities.take(30)) {
      actionCounts.update(
        activity.type,
        (value) => value + 1,
        ifAbsent: () => 1,
      );
    }

    return ListView(
      controller: _scrollController,
      padding: EdgeInsets.fromLTRB(20, 20, 20, widget.bottomPadding),
      children: [
        _GlassPanel(
          padding: const EdgeInsets.all(22),
          borderRadius: 30,
          blurSigma: 16,
          backgroundColor: const Color(0xFFE7FFF1).withValues(alpha: 0.34),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.recentActionChart,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Color(0xFF17342A),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.plants.isEmpty
                    ? l10n.recentActionChartEmpty
                    : l10n.recentActionChartHint,
                style: const TextStyle(color: Color(0xFF5D7268), height: 1.45),
              ),
              const SizedBox(height: 18),
              _ActivityChart(actionCounts: actionCounts),
            ],
          ),
        ),
        const SizedBox(height: 20),
        if (recentActivities.isEmpty)
          EmptyCard(message: l10n.timelineEmpty)
        else
          ...List.generate(visibleActivities.length, (index) {
            final activity = visibleActivities[index];
            return _StatTimelineItem(
              activity: activity,
              isFirst: index == 0,
              isLast: index == visibleActivities.length - 1,
            );
          }),
        if (recentActivities.length > visibleActivities.length)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Center(
              child: Text(
                l10n.activityCountProgress(
                  visibleActivities.length,
                  recentActivities.length,
                ),
                style: const TextStyle(
                  color: Color(0xFF6A7C72),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ActivityChart extends StatelessWidget {
  const _ActivityChart({required this.actionCounts});

  final Map<PlantActivityType, int> actionCounts;

  @override
  Widget build(BuildContext context) {
    final entries = PlantActivityType.values
        .map(
          (type) => (
            type: type,
            count: actionCounts[type] ?? 0,
          ),
        )
        .toList(growable: false);
    final maxCount = entries.fold<int>(
      1,
      (maxValue, entry) => entry.count > maxValue ? entry.count : maxValue,
    );

    return Column(
      children: [
        for (final entry in entries) ...[
          _ActionChartRow(
            type: entry.type,
            count: entry.count,
            maxCount: maxCount,
          ),
          if (entry != entries.last) const SizedBox(height: 12),
        ],
      ],
    );
  }
}

class _ActionChartRow extends StatelessWidget {
  const _ActionChartRow({
    required this.type,
    required this.count,
    required this.maxCount,
  });

  final PlantActivityType type;
  final int count;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = _activityColor(type);
    final ratio = maxCount == 0 ? 0.0 : count / maxCount;

    return Row(
      children: [
        SizedBox(
          width: 108,
          child: Row(
            children: [
              Icon(_activityIcon(type), color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _activityLabel(l10n, type),
                  style: const TextStyle(
                    color: Color(0xFF27453A),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: 12,
              color: Colors.white.withValues(alpha: 0.4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: ratio.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          color.withValues(alpha: 0.9),
                          color.withValues(alpha: 0.55),
                        ],
                      ),
                    ),
                    child: const SizedBox.expand(),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 28,
          child: Text(
            '$count',
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF17342A),
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = 26,
    this.blurSigma = 10,
    this.backgroundColor,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double borderRadius;
  final double blurSigma;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: backgroundColor ?? Colors.white.withValues(alpha: 0.36),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(color: Colors.white.withValues(alpha: 0.68)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 24,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _StatTimelineItem extends StatelessWidget {
  const _StatTimelineItem({
    required this.activity,
    required this.isFirst,
    required this.isLast,
  });

  final PlantActivityEntry activity;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = _activityColor(activity.type);
    final location = activity.location.trim().isEmpty
        ? context.l10n.locationUnset
        : activity.location.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 42,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isFirst
                          ? Colors.transparent
                          : color.withValues(alpha: 0.22),
                    ),
                  ),
                  SizedBox(
                    width: 36,
                    height: 36,
                    child: Icon(
                      _activityIcon(activity.type),
                      size: 30,
                      color: color,
                    ),
                  ),
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isLast
                          ? Colors.transparent
                          : color.withValues(alpha: 0.22),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: _GlassPanel(
                padding: const EdgeInsets.all(18),
                borderRadius: 26,
                blurSigma: 14,
                backgroundColor: Colors.white.withValues(alpha: 0.42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            activity.plantName,
                            style: const TextStyle(
                              fontSize: 19,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF17342A),
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            _activityLabel(l10n, activity.type),
                            style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${activity.plantType} · $location',
                      style: const TextStyle(
                        color: Color(0xFF546A60),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: _TimelineMeta(
                            label: l10n.actionTime,
                            value: _activityDateTimeLabel(activity.occurredAt),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _TimelineMeta(
                            label: l10n.detail,
                            value: activity.detail ?? _activityDescription(l10n, activity.type),
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
    );
  }
}

class _TimelineMeta extends StatelessWidget {
  const _TimelineMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: Color(0xFF72857B),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF17342A),
            ),
          ),
        ],
      ),
    );
  }
}

PlantActivityEntry _buildActivityEntry({
  required PlantItem plant,
  required PlantActivityType type,
  DateTime? occurredAt,
  String? detail,
}) {
  return PlantActivityEntry(
    id: '${type.name}_${plant.id}_${(occurredAt ?? DateTime.now()).microsecondsSinceEpoch}',
    plantId: plant.id,
    plantName: plant.name,
    plantType: plant.type,
    location: plant.location,
    type: type,
    occurredAt: occurredAt ?? DateTime.now(),
    detail: detail,
  );
}

void _appendActivityToList(
  List<PlantActivityEntry> activities,
  PlantActivityEntry entry,
) {
  activities.insert(0, entry);
  if (activities.length > 120) {
    activities.removeRange(120, activities.length);
  }
}

IconData _activityIcon(PlantActivityType type) {
  return switch (type) {
    PlantActivityType.registered => Icons.add_circle_rounded,
    PlantActivityType.watered => Icons.water_drop_rounded,
    PlantActivityType.repotted => Icons.inventory_2_rounded,
    PlantActivityType.moved => Icons.place_rounded,
    PlantActivityType.updated => Icons.edit_rounded,
    PlantActivityType.deleted => Icons.delete_rounded,
  };
}

Color _activityColor(PlantActivityType type) {
  return switch (type) {
    PlantActivityType.registered => const Color(0xFF2F855A),
    PlantActivityType.watered => const Color(0xFF2B6DE0),
    PlantActivityType.repotted => const Color(0xFF9C6B2F),
    PlantActivityType.moved => const Color(0xFF8E5AD7),
    PlantActivityType.updated => const Color(0xFFEF8D32),
    PlantActivityType.deleted => const Color(0xFFD9534F),
  };
}

String _activityLabel(AppLocalizations l10n, PlantActivityType type) {
  return switch (type) {
    PlantActivityType.registered => l10n.languageCode == 'ko' ? '등록' : l10n.languageCode == 'ja' ? '登録' : l10n.languageCode == 'zh' ? '登记' : 'Added',
    PlantActivityType.watered => l10n.languageCode == 'ko' ? '물주기' : l10n.languageCode == 'ja' ? '水やり' : l10n.languageCode == 'zh' ? '浇水' : 'Watered',
    PlantActivityType.repotted => l10n.languageCode == 'ko' ? '분갈이' : l10n.languageCode == 'ja' ? '植え替え' : l10n.languageCode == 'zh' ? '换盆' : 'Repotted',
    PlantActivityType.moved => l10n.languageCode == 'ko' ? '위치 변경' : l10n.languageCode == 'ja' ? '場所変更' : l10n.languageCode == 'zh' ? '位置变更' : 'Moved',
    PlantActivityType.updated => l10n.languageCode == 'ko' ? '정보 수정' : l10n.languageCode == 'ja' ? '情報修正' : l10n.languageCode == 'zh' ? '信息修改' : 'Updated',
    PlantActivityType.deleted => l10n.languageCode == 'ko' ? '삭제' : l10n.languageCode == 'ja' ? '削除' : l10n.languageCode == 'zh' ? '删除' : 'Deleted',
  };
}

String _activityDescription(AppLocalizations l10n, PlantActivityType type) {
  return switch (type) {
    PlantActivityType.registered => l10n.languageCode == 'ko' ? '식물을 새로 등록했어요.' : l10n.languageCode == 'ja' ? '植物を新しく登録しました。' : l10n.languageCode == 'zh' ? '已登记新的植物。' : 'Added a new plant.',
    PlantActivityType.watered => l10n.languageCode == 'ko' ? '물주기 완료로 기록했어요.' : l10n.languageCode == 'ja' ? '水やり完了として記録しました。' : l10n.languageCode == 'zh' ? '已记录为完成浇水。' : 'Recorded watering as completed.',
    PlantActivityType.repotted => l10n.languageCode == 'ko' ? '화분 교체 이력을 남겼어요.' : l10n.languageCode == 'ja' ? '植え替え履歴を残しました。' : l10n.languageCode == 'zh' ? '已记录换盆历史。' : 'Saved a repotting record.',
    PlantActivityType.moved => l10n.languageCode == 'ko' ? '식물 위치를 옮겼어요.' : l10n.languageCode == 'ja' ? '植物の場所を移動しました。' : l10n.languageCode == 'zh' ? '已移动植物位置。' : 'Moved the plant location.',
    PlantActivityType.updated => l10n.languageCode == 'ko' ? '식물 정보를 수정했어요.' : l10n.languageCode == 'ja' ? '植物情報を修正しました。' : l10n.languageCode == 'zh' ? '已修改植物信息。' : 'Updated the plant information.',
    PlantActivityType.deleted => l10n.languageCode == 'ko' ? '목록에서 식물을 제거했어요.' : l10n.languageCode == 'ja' ? '一覧から植物を削除しました。' : l10n.languageCode == 'zh' ? '已从列表中删除植物。' : 'Removed the plant from the list.',
  };
}

String _activityDateTimeLabel(DateTime dateTime) {
  final hh = dateTime.hour.toString().padLeft(2, '0');
  final mm = dateTime.minute.toString().padLeft(2, '0');
  return '${dateTime.month}.${dateTime.day} $hh:$mm';
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            height: 92,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(color: Colors.white.withValues(alpha: 0.65)),
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
              color: isSelected
                  ? data.color.withValues(alpha: 0.16)
                  : Colors.transparent,
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
                      color: isSelected
                          ? Colors.white
                          : const Color(0xFF5F6F65),
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

class _PlantImagePlaceholder extends StatelessWidget {
  const _PlantImagePlaceholder({
    required this.background,
    required this.iconColor,
    this.iconSize = 42,
  });

  final Decoration background;
  final Color iconColor;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: background,
      child: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(iconSize * 0.72),
          child: SizedBox(
            width: iconSize * 1.7,
            height: iconSize * 1.7,
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

class PlantEditSheetResult {
  const PlantEditSheetResult({
    this.plant,
    this.deletedPlantId,
  });

  final PlantItem? plant;
  final String? deletedPlantId;
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
    final fallbackCycle = current?.wateringCycleDays ?? 7;
    _availablePresets = widget.presets.isNotEmpty
        ? List<PlantPreset>.from(widget.presets)
        : List<PlantPreset>.from(kPlantPresets);
    _selectedPreset = current != null
        ? _availablePresets.firstWhere(
            (preset) => preset.type == current.type,
            orElse: () => _manualPreset(
              current.type,
              cycleDays: current.wateringCycleDays,
              sunlight: current.sunlight,
              tip: current.memo,
              imageUrl: current.presetImageUrl,
            ),
          )
        : _manualPreset('', cycleDays: fallbackCycle);
    if (!_availablePresets.any(
      (preset) =>
          _selectedPreset.type.trim().isNotEmpty &&
          preset.type == _selectedPreset.type,
    )) {
      _availablePresets = [_selectedPreset, ..._availablePresets];
    }
    _nameController = TextEditingController(text: current?.name ?? '');
    _locationController = TextEditingController(text: current?.location ?? '');
    _memoController = TextEditingController(text: current?.memo ?? '');
    _cycleController = TextEditingController(
      text: '${current?.wateringCycleDays ?? fallbackCycle}',
    );
    _presetSearchController = TextEditingController(text: current?.type ?? '');
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
      if (preset.type.trim().isNotEmpty &&
          (_nameController.text.trim().isEmpty ||
              _nameController.text.trim() == widget.existing?.name)) {
        _nameController.text = preset.type;
      }
      _cycleController.text = '${preset.defaultWateringCycleDays}';
      if (preset.tip.trim().isNotEmpty &&
          (_memoController.text.trim().isEmpty ||
          _memoController.text.trim() == widget.existing?.memo ||
          _memoController.text.trim() == previousTip)) {
        _memoController.text = preset.tip;
      }
    });
  }

  PlantPreset _manualPreset(
    String type, {
    int cycleDays = 7,
    String sunlight = '',
    String tip = '',
    String? imageUrl,
  }) {
    return PlantPreset(
      type: type.trim(),
      defaultWateringCycleDays: cycleDays,
      sunlight: sunlight,
      tip: tip,
      imageUrl: imageUrl,
    );
  }

  Future<void> _openPresetSearchSheet() async {
    final selected = await showModalBottomSheet<PlantPreset>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _PlantPresetSearchSheet(
        presets: _availablePresets,
        initialQuery: _presetSearchController.text,
      ),
    );
    if (selected != null) {
      _applyPreset(selected);
    }
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
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Colors.black54,
                        height: 1.35,
                      ),
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
    final actionBottomPadding = bottomInset > 0 ? 14.0 : 14.0 + bottomSafeArea;
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
                                  isEditing
                                      ? Icons.edit_rounded
                                      : Icons.add_rounded,
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
                                      isEditing
                                          ? l10n.plantInfoEdit
                                          : l10n.newPlantRegister,
                                      style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      isEditing
                                          ? l10n.plantInfoEditHint
                                          : l10n.newPlantRegisterHint,
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        height: 1.4,
                                      ),
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
                                label: l10n.cycleDaysLabel(
                                  int.tryParse(_cycleController.text.trim()) ??
                                      _selectedPreset.defaultWateringCycleDays,
                                ),
                                tint: const Color(0xFFE8F5EC),
                              ),
                              _InfoPill(
                                icon: Icons.wb_sunny_rounded,
                                label: _selectedPreset.sunlight.trim().isEmpty
                                    ? l10n.sunlightUnknown
                                    : _selectedPreset.sunlight,
                                tint: const Color(0xFFFFF2DE),
                              ),
                              _InfoPill(
                                icon: Icons.photo_library_rounded,
                                label: _photoAssetIds.isEmpty
                                    ? l10n.noPhoto
                                    : l10n.selectedPhotoCount(
                                        _photoAssetIds.length,
                                      ),
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
                          InkWell(
                            borderRadius: BorderRadius.circular(22),
                            onTap: _openPresetSearchSheet,
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(18),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FBF8),
                                borderRadius: BorderRadius.circular(22),
                                border: Border.all(
                                  color: const Color(0xFFE3ECE6),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    width: 44,
                                    height: 44,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFEAF5EE),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.search_rounded,
                                      color: Color(0xFF2F855A),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.choosePlantType,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _selectedPreset.type.trim().isEmpty
                                              ? l10n.choosePlantTypeHint
                                              : _selectedPreset.type,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _selectedPreset.type
                                                    .trim()
                                                    .isEmpty
                                                ? Colors.black45
                                                : Colors.black87,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.black45,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          if (_selectedPreset.type.trim().isEmpty)
                            _EmptyPresetSelectionCard(
                              title: l10n.noPlantTypeSelected,
                              subtitle: l10n.noPlantTypeSelectedHint,
                            )
                          else
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
                                lastDate: DateTime.now().add(
                                  const Duration(days: 365),
                                ),
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
                                border: Border.all(
                                  color: const Color(0xFFE3ECE6),
                                ),
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
                                    child: const Icon(
                                      Icons.calendar_today_rounded,
                                      color: Color(0xFFFFA94D),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.lastWateredDate,
                                          style: TextStyle(
                                            color: Color(0xFF66756C),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _dateLabel(_lastWateredAt),
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right_rounded,
                                    color: Colors.black45,
                                  ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                              icon: const Icon(
                                Icons.add_photo_alternate_outlined,
                              ),
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
                                border: Border.all(
                                  color: const Color(0xFFE3ECE6),
                                ),
                              ),
                              child: Text(
                                l10n.noRegisteredPhotos,
                                style: const TextStyle(
                                  color: Colors.black54,
                                  height: 1.4,
                                ),
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
                                      scale: Tween<double>(
                                        begin: 1,
                                        end: 1.04,
                                      ).animate(animation),
                                      child: child,
                                    ),
                                  );
                                },
                                onReorder: (oldIndex, newIndex) {
                                  setState(() {
                                    if (newIndex > oldIndex) {
                                      newIndex -= 1;
                                    }
                                    final moved = _photoAssetIds.removeAt(
                                      oldIndex,
                                    );
                                    _photoAssetIds.insert(newIndex, moved);
                                  });
                                },
                                itemBuilder: (context, index) {
                                  final assetId = _photoAssetIds[index];
                                  return Padding(
                                    key: ValueKey(assetId),
                                    padding: EdgeInsets.only(
                                      right: index == _photoAssetIds.length - 1
                                          ? 0
                                          : 12,
                                    ),
                                    child: Stack(
                                      children: [
                                        PlantPhotoThumb(
                                          assetId: assetId,
                                          width: 96,
                                          height: 96,
                                          borderRadius: 22,
                                        ),
                                        Positioned(
                                          left: 8,
                                          bottom: 8,
                                          child: Container(
                                            width: 28,
                                            height: 28,
                                            decoration: BoxDecoration(
                                              color: Colors.black.withValues(
                                                alpha: 0.38,
                                              ),
                                              borderRadius:
                                                  BorderRadius.circular(999),
                                            ),
                                            child: const Icon(
                                              Icons.drag_indicator_rounded,
                                              color: Colors.white,
                                              size: 18,
                                            ),
                                          ),
                                        ),
                                        if (index == 0)
                                          Positioned(
                                            left: 8,
                                            top: 8,
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.92,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                l10n.representativePhoto,
                                                style: const TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w800,
                                                ),
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
                                                color: Colors.black.withValues(
                                                  alpha: 0.68,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: const Icon(
                                                Icons.close,
                                                color: Colors.white,
                                                size: 17,
                                              ),
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
                            style: const TextStyle(
                              color: Colors.black54,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              padding: EdgeInsets.fromLTRB(20, 14, 20, actionBottomPadding),
              decoration: const BoxDecoration(
                color: Color(0xFFF6FBF7),
                border: Border(top: BorderSide(color: Color(0x12000000))),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                        final cycle =
                            int.tryParse(_cycleController.text.trim()) ??
                            _selectedPreset.defaultWateringCycleDays;
                        final resolvedType = _selectedPreset.type.trim().isNotEmpty
                            ? _selectedPreset.type.trim()
                            : (_nameController.text.trim().isNotEmpty
                                  ? _nameController.text.trim()
                                  : l10n.plantType);
                        final plant = PlantItem(
                          id:
                              widget.existing?.id ??
                              DateTime.now().millisecondsSinceEpoch.toString(),
                          name: _nameController.text.trim().isEmpty
                              ? resolvedType
                              : _nameController.text.trim(),
                          type: resolvedType,
                          location: _locationController.text.trim().isEmpty
                              ? l10n.noLocationEnteredFallback()
                              : _locationController.text.trim(),
                          wateringCycleDays: cycle,
                          lastWateredAt: _lastWateredAt,
                          memo: _memoController.text.trim().isEmpty
                              ? (_selectedPreset.tip.trim().isEmpty
                                    ? ''
                                    : _selectedPreset.tip)
                              : _memoController.text.trim(),
                          sunlight: _selectedPreset.sunlight.trim().isEmpty
                              ? ''
                              : _selectedPreset.sunlight,
                          presetImageUrl: (_selectedPreset.imageUrl ?? '')
                                  .trim()
                                  .isEmpty
                              ? widget.existing?.presetImageUrl
                              : _selectedPreset.imageUrl,
                          photoAssetIds: List<String>.from(_photoAssetIds),
                        );
                        Navigator.of(
                          context,
                        ).pop(PlantEditSheetResult(plant: plant));
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        minimumSize: const Size.fromHeight(58),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(22),
                        ),
                      ),
                      child: Text(
                        isEditing ? l10n.saveChanges : l10n.registerPlant,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                  if (isEditing) ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) {
                            return AlertDialog(
                              title: Text(l10n.deletePlant),
                              content: Text(l10n.deletePlantConfirm),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(false),
                                  child: Text(l10n.close),
                                ),
                                FilledButton(
                                  onPressed: () =>
                                      Navigator.of(dialogContext).pop(true),
                                  style: FilledButton.styleFrom(
                                    backgroundColor: const Color(0xFFD95C45),
                                  ),
                                  child: Text(l10n.delete),
                                ),
                              ],
                            );
                          },
                        );
                        if (confirmed != true || !context.mounted) return;
                        Navigator.of(context).pop(
                          PlantEditSheetResult(
                            deletedPlantId: widget.existing!.id,
                          ),
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFFD95C45),
                        side: const BorderSide(color: Color(0xFFFFD5CF)),
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: Text(l10n.deletePlant),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class PlantActionCard extends StatelessWidget {
  const PlantActionCard({
    super.key,
    required this.plant,
    required this.onTap,
    required this.onMarkWatered,
  });

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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (plant.photoAssetIds.isNotEmpty) ...[
                PlantPhotoThumb(
                  assetId: plant.photoAssetIds.first,
                  width: 56,
                  height: 56,
                  borderRadius: 16,
                ),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      plant.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
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
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.water_drop_outlined, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    plant.status == PlantStatus.overdue
                        ? l10n.overdueRecommendation(
                            plant.daysUntilWatering.abs(),
                          )
                        : l10n.todayWateringTurn,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onTap,
                  child: Text(l10n.detailMemo),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onMarkWatered,
                  child: Text(l10n.markWatered),
                ),
              ),
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
      child: const Icon(
        Icons.local_florist_rounded,
        color: Color(0xFF2F855A),
        size: 24,
      ),
    );
  }
}

class _PlantPresetOptionTile extends StatelessWidget {
  const _PlantPresetOptionTile({required this.preset});

  final PlantPreset preset;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sunlightLabel = preset.sunlight.trim().isEmpty
        ? l10n.sunlightUnknown
        : preset.sunlight;
    final tipLabel = preset.tip.trim().isEmpty
        ? l10n.presetTipMissing
        : preset.tip;
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
                  '${l10n.cycleDaysLabel(preset.defaultWateringCycleDays)} · $sunlightLabel',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 2),
                Text(
                  tipLabel,
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
    final sunlightLabel = preset.sunlight.trim().isEmpty
        ? l10n.sunlightUnknown
        : preset.sunlight;
    final tipLabel = preset.tip.trim().isEmpty
        ? l10n.presetTipMissing
        : preset.tip;
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
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${l10n.defaultCycleDaysLabel(preset.defaultWateringCycleDays)} · $sunlightLabel',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  tipLabel,
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

class _EmptyPresetSelectionCard extends StatelessWidget {
  const _EmptyPresetSelectionCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FBF8),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE3ECE6)),
      ),
      child: Row(
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF5EE),
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(
              Icons.local_florist_rounded,
              color: Color(0xFF2F855A),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                    height: 1.4,
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

class _PlantPresetSearchSheet extends StatefulWidget {
  const _PlantPresetSearchSheet({
    required this.presets,
    required this.initialQuery,
  });

  final List<PlantPreset> presets;
  final String initialQuery;

  @override
  State<_PlantPresetSearchSheet> createState() => _PlantPresetSearchSheetState();
}

class _PlantPresetSearchSheetState extends State<_PlantPresetSearchSheet> {
  static const int _maxVisibleResults = 30;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialQuery);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<PlantPreset> get _results {
    final query = _searchController.text.trim();
    final source = query.isEmpty
        ? widget.presets
        : widget.presets.where((preset) => preset.matchesQuery(query));
    return source.take(_maxVisibleResults).toList(growable: false);
  }

  PlantPreset _manualPreset(String query) {
    return PlantPreset(
      type: query.trim(),
      defaultWateringCycleDays: 7,
      sunlight: '',
      tip: '',
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mediaQuery = MediaQuery.of(context);
    final query = _searchController.text.trim();
    final results = _results;
    final bottomSafeArea = mediaQuery.viewPadding.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: mediaQuery.viewInsets.bottom),
      child: SizedBox(
        height: mediaQuery.size.height * 0.72,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.searchPlantPresetTitle,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    decoration: InputDecoration(
                      labelText: l10n.searchPlantType,
                      hintText: l10n.searchPlantPresetHint,
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: Color(0xFF5E6D64),
                      ),
                      suffixIcon: query.isEmpty
                          ? null
                          : IconButton(
                              onPressed: () {
                                setState(() {
                                  _searchController.clear();
                                });
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                      filled: true,
                      fillColor: const Color(0xFFF8FBF8),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                          color: Color(0xFFE3ECE6),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(22),
                        borderSide: const BorderSide(
                          color: Color(0xFF2F855A),
                          width: 1.4,
                        ),
                      ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l10n.presetSearchResultCount(results.length),
                    style: const TextStyle(
                      color: Colors.black54,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: results.isNotEmpty
                  ? ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        20 + bottomSafeArea,
                      ),
                      itemCount: results.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final preset = results[index];
                        return InkWell(
                          onTap: () => Navigator.of(context).pop(preset),
                          borderRadius: BorderRadius.circular(18),
                          child: _PlantPresetOptionTile(preset: preset),
                        );
                      },
                    )
                  : ListView(
                      padding: EdgeInsets.fromLTRB(
                        20,
                        0,
                        20,
                        20 + bottomSafeArea,
                      ),
                      children: [
                        _EmptyPresetSelectionCard(
                          title: query.isEmpty
                              ? l10n.registeredPresetMissing
                              : l10n.noPresetFoundForKeyword(query),
                          subtitle: query.isEmpty
                              ? l10n.searchPlantPresetHint
                              : l10n.noPlantTypeSelectedHint,
                        ),
                        const SizedBox(height: 12),
                        if (query.isNotEmpty)
                          FilledButton.icon(
                            onPressed: () =>
                                Navigator.of(context).pop(_manualPreset(query)),
                            style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(54),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(18),
                              ),
                            ),
                            icon: const Icon(Icons.edit_rounded),
                            label: Text(l10n.registerTypedKeyword(query)),
                          )
                        else
                          OutlinedButton.icon(
                            onPressed: null,
                            icon: const Icon(Icons.info_outline_rounded),
                            label: Text(l10n.manualRegisterPlantType),
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
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: _statusColor(
                plant.status,
              ).withValues(alpha: 0.15),
              child: Icon(
                Icons.local_florist,
                color: _statusColor(plant.status),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.afterDaysLabel(
                      plant.daysUntilWatering,
                      plant.location,
                    ),
                  ),
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
    this.priorityRank,
  });

  final PlantItem plant;
  final VoidCallback onTap;
  final String? presetImageUrl;
  final int? priorityRank;

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
      PlantStatus.overdue => const LinearGradient(
        colors: [Color(0xFFFFE2E0), Color(0xFFFFF5F4)],
      ),
      PlantStatus.today => const LinearGradient(
        colors: [Color(0xFFFFF0D7), Color(0xFFFFF8EC)],
      ),
      PlantStatus.soon => const LinearGradient(
        colors: [Color(0xFFEAF3FF), Color(0xFFF6FAFF)],
      ),
      PlantStatus.healthy => const LinearGradient(
        colors: [Color(0xFFEAF6EE), Color(0xFFF6FBF8)],
      ),
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
          boxShadow: [
            BoxShadow(
              color: statusGlow,
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
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
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusDescription(plant.status),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (priorityRank != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        '#$priorityRank',
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  StatusChip(status: plant.status),
                ],
              ),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 126,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (plant.photoAssetIds.isNotEmpty)
                          PlantPhotoThumb(
                            assetId: plant.photoAssetIds.first,
                            width: 126,
                            height: 126,
                            borderRadius: 0,
                          )
                        else if (presetImageUrl != null &&
                            presetImageUrl!.isNotEmpty)
                          Image.network(
                            presetImageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                                _PlantImagePlaceholder(
                                  background: BoxDecoration(
                                    color: color.withValues(alpha: 0.14),
                                  ),
                                  iconColor: color,
                                ),
                          )
                        else
                          _PlantImagePlaceholder(
                            background: BoxDecoration(
                              color: color.withValues(alpha: 0.14),
                            ),
                            iconColor: color,
                          ),
                        DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.22),
                              ],
                            ),
                          ),
                        ),
                        if (plant.photoAssetIds.length > 1)
                          Positioned(
                            top: 10,
                            right: 10,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withValues(alpha: 0.42),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                '+${plant.photoAssetIds.length - 1}',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
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
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                            ),
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
                                label: l10n.cycleDaysLabel(
                                  plant.wateringCycleDays,
                                ),
                                tint: const Color(0xFFFFF0D9),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            plant.memo,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.black54,
                              height: 1.45,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
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
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        _statusText(status),
        style: TextStyle(
          color: color,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
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
  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
  });

  final String title;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 160,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: Colors.black54)),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeMiniStat extends StatelessWidget {
  const _HomeMiniStat({required this.label, required this.value});

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
          Text(
            label,
            style: const TextStyle(
              color: Color(0xFF66756C),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111A16),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
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
                Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF66756C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.black54, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// ignore: unused_element
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
          const SizedBox(height: 18),
          Text(
            title,
            style: const TextStyle(
              color: Colors.black54,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            detail,
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Text(message, style: const TextStyle(color: Colors.black54)),
    );
  }
}

class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
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
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
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
        Text(
          title,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: const TextStyle(color: Colors.black54)),
      ],
    );
  }
}

class HomeDashboardTab extends StatelessWidget {
  const HomeDashboardTab({
    super.key,
    required this.plants,
    required this.presets,
    required this.bottomPadding,
    required this.pinnedPlantId,
    required this.onTapPlant,
    required this.onMarkWatered,
    required this.onMarkAllWatered,
  });

  final List<PlantItem> plants;
  final List<PlantPreset> presets;
  final double bottomPadding;
  final String? pinnedPlantId;
  final ValueChanged<PlantItem> onTapPlant;
  final ValueChanged<PlantItem> onMarkWatered;
  final ValueChanged<List<PlantItem>> onMarkAllWatered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sortedPlants = _sortPlantsByUrgency(plants);
    final presetImageByType = _buildPresetImageByType(presets);
    final urgentTasks = sortedPlants
        .where(
          (plant) =>
              plant.status == PlantStatus.overdue ||
              plant.status == PlantStatus.today,
        )
        .toList();
    final soonTasks = sortedPlants
        .where((plant) => plant.status == PlantStatus.soon)
        .toList();
    final primaryPlant = sortedPlants.cast<PlantItem?>().firstWhere(
      (plant) => plant?.id == pinnedPlantId,
      orElse: () => sortedPlants.isNotEmpty ? sortedPlants.first : null,
    );
    final healthyCount = plants
        .where((plant) => plant.status == PlantStatus.healthy)
        .length;
    final focusTasks = urgentTasks.isNotEmpty
        ? urgentTasks
        : soonTasks.take(3).toList();

    return ListView(
      padding: EdgeInsets.only(bottom: bottomPadding),
      children: [
        if (primaryPlant == null)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: EmptyCard(message: l10n.noPlantsYet),
          )
        else
          _HomeImmersiveSection(
            plant: primaryPlant,
            presetImageUrl: _plantPresetImageUrl(
              presetImageByType,
              primaryPlant,
            ),
            healthyCount: healthyCount,
            totalCount: plants.length,
            assignmentPanel: _HomeAssignmentPanel(
              tasks: focusTasks,
              hasUrgentTasks: urgentTasks.isNotEmpty,
              onTapPlant: onTapPlant,
              onMarkWatered: onMarkWatered,
              onMarkAllWatered: () => onMarkAllWatered(urgentTasks),
            ),
            bottomPanel: soonTasks.isNotEmpty
                ? _HomeSoonPanel(plants: soonTasks, onTapPlant: onTapPlant)
                : _HomeCalmPanel(healthyCount: healthyCount),
          ),
      ],
    );
  }
}

// ignore: unused_element
class _HomeFocusPlantCard extends StatelessWidget {
  const _HomeFocusPlantCard({
    required this.plant,
    required this.healthyCount,
    required this.totalCount,
  });

  final PlantItem plant;
  final int healthyCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locationLabel = plant.location.trim().isEmpty
        ? l10n.locationUnset
        : plant.location.trim();
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF163627),
        borderRadius: BorderRadius.circular(32),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 214,
            child: Stack(
              fit: StackFit.expand,
              children: [
              if (plant.photoAssetIds.isNotEmpty)
                PlantPhotoThumb(
                  assetId: plant.photoAssetIds.first,
                  width: double.infinity,
                  height: 214,
                  borderRadius: 0,
                )
              else
                const _PlantImagePlaceholder(
                  background: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFCBD9C7), Color(0xFF6F8D6D)],
                    ),
                  ),
                  iconColor: Colors.white70,
                  iconSize: 58,
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.04),
                        Colors.black.withValues(alpha: 0.32),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: Row(
                    children: [
                      _HeroChip(
                        icon: Icons.place_rounded,
                        label: locationLabel,
                      ),
                      const SizedBox(width: 8),
                      _HeroChip(
                        icon: Icons.eco_rounded,
                        label: _statusText(plant.status),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 18, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  plant.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    height: 1.05,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  plant.type,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: _HomeRoundMetric(
                        icon: Icons.park_rounded,
                        iconColor: const Color(0xFF2F855A),
                        ringColor: const Color(0xFFBFE3CE),
                        title: l10n.organizedPlantsTitle,
                        value: '$healthyCount / $totalCount',
                        subtitle: l10n.stableStateSubtitle,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: _HomeRoundMetric(
                        icon: Icons.event_available_rounded,
                        iconColor: const Color(0xFF2F855A),
                        ringColor: const Color(0xFFBFE3CE),
                        title: l10n.nextWateringTitle,
                        value: plant.daysUntilWatering <= 0
                            ? l10n.todayShortLabel
                            : l10n.withinDaysLabel(plant.daysUntilWatering),
                        subtitle: _dateLabel(plant.nextWateringAt),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE6E7CF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: const Color(0xFF46543A)),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: Color(0xFF46543A),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeImmersiveSection extends StatelessWidget {
  const _HomeImmersiveSection({
    required this.plant,
    required this.presetImageUrl,
    required this.healthyCount,
    required this.totalCount,
    required this.assignmentPanel,
    required this.bottomPanel,
  });

  final PlantItem plant;
  final String? presetImageUrl;
  final int healthyCount;
  final int totalCount;
  final Widget assignmentPanel;
  final Widget bottomPanel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final locationLabel = plant.location.trim().isEmpty
        ? l10n.locationUnset
        : plant.location.trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 260,
          child: Stack(
            fit: StackFit.expand,
              children: [
                if (plant.photoAssetIds.isNotEmpty)
                  PlantPhotoThumb(
                    assetId: plant.photoAssetIds.first,
                    width: double.infinity,
                    height: 260,
                    borderRadius: 0,
                  )
                else if ((presetImageUrl ?? '').isNotEmpty)
                  Image.network(
                    presetImageUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        const _PlantImagePlaceholder(
                          background: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [Color(0xFFD7E2D2), Color(0xFF87A184)],
                            ),
                          ),
                          iconColor: Colors.white70,
                          iconSize: 58,
                        ),
                  )
                else
                  const _PlantImagePlaceholder(
                    background: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFFD7E2D2), Color(0xFF87A184)],
                    ),
                  ),
                  iconColor: Colors.white70,
                  iconSize: 58,
                ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.04),
                      Colors.black.withValues(alpha: 0.18),
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 42,
                left: 18,
                right: 18,
                child: Align(
                  alignment: Alignment.bottomRight,
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _HeroChip(
                        icon: Icons.place_rounded,
                        label: locationLabel,
                      ),
                      _HeroChip(
                        icon: Icons.eco_rounded,
                        label: _statusText(plant.status),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -24),
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFFF7F8F3),
              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name,
                    style: const TextStyle(
                      color: Color(0xFF23472D),
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    plant.type,
                    style: const TextStyle(
                      color: Colors.black54,
                      fontSize: 13,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _HomeRoundMetric(
                          icon: Icons.park_rounded,
                          iconColor: const Color(0xFF2F855A),
                          ringColor: const Color(0xFFBFE3CE),
                        title: l10n.organizedPlantsTitle,
                        value: '$healthyCount / $totalCount',
                        subtitle: l10n.stableStateSubtitle,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _HomeRoundMetric(
                          icon: Icons.event_available_rounded,
                          iconColor: const Color(0xFF2F855A),
                          ringColor: const Color(0xFFBFE3CE),
                          title: l10n.nextWateringTitle,
                          value: plant.daysUntilWatering <= 0
                              ? l10n.todayShortLabel
                              : l10n.withinDaysLabel(plant.daysUntilWatering),
                          subtitle: _dateLabel(plant.nextWateringAt),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  assignmentPanel,
                  const SizedBox(height: 18),
                  bottomPanel,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _HomeRoundMetric extends StatelessWidget {
  const _HomeRoundMetric({
    required this.icon,
    required this.iconColor,
    required this.ringColor,
    required this.title,
    required this.value,
    required this.subtitle,
  });

  final IconData icon;
  final Color iconColor;
  final Color ringColor;
  final String title;
  final String value;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        children: [
          Container(
            width: 78,
            height: 78,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: ringColor, width: 5),
            ),
            child: Icon(icon, color: iconColor, size: 34),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF3B4A40),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF111A16),
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, height: 1.35),
          ),
        ],
      ),
    );
  }
}

class _HomeAssignmentPanel extends StatelessWidget {
  const _HomeAssignmentPanel({
    required this.tasks,
    required this.hasUrgentTasks,
    required this.onTapPlant,
    required this.onMarkWatered,
    required this.onMarkAllWatered,
  });

  final List<PlantItem> tasks;
  final bool hasUrgentTasks;
  final ValueChanged<PlantItem> onTapPlant;
  final ValueChanged<PlantItem> onMarkWatered;
  final VoidCallback onMarkAllWatered;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.todaySectionTitle,
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            hasUrgentTasks
                ? l10n.todaySectionHint(true)
                : l10n.todaySectionHint(false),
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 14),
          if (tasks.isEmpty)
            EmptyCard(message: l10n.noTasksToday)
          else
            ..._withGaps(
              tasks.map((plant) {
                return _HomeAssignmentTile(
                  plant: plant,
                  onTap: () => onTapPlant(plant),
                  onComplete: plant.status == PlantStatus.soon
                      ? () => onTapPlant(plant)
                      : () => onMarkWatered(plant),
                );
              }).toList(),
              gap: 10,
            ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: hasUrgentTasks ? onMarkAllWatered : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF234F29),
                foregroundColor: Colors.white,
                disabledBackgroundColor: const Color(0xFFD8E2DA),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                l10n.completeAllTasks,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeAssignmentTile extends StatelessWidget {
  const _HomeAssignmentTile({
    required this.plant,
    required this.onTap,
    required this.onComplete,
  });

  final PlantItem plant;
  final VoidCallback onTap;
  final VoidCallback onComplete;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = _statusColor(plant.status);
    final title = l10n.actionTileTitle(plant.status == PlantStatus.soon);
    final subtitle = l10n.actionTileSubtitle(
      plant.status,
      plant.daysUntilWatering,
    );
    final icon = switch (plant.status) {
      PlantStatus.overdue => Icons.health_and_safety_rounded,
      PlantStatus.today => Icons.water_drop_rounded,
      PlantStatus.soon => Icons.spa_outlined,
      PlantStatus.healthy => Icons.eco_rounded,
    };

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFFF8FAF7),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Color(0xFF33433A),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plant.name} · $subtitle',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.notifications_none_rounded,
              color: color.withValues(alpha: 0.7),
            ),
            const SizedBox(width: 12),
            InkWell(
              onTap: onComplete,
              borderRadius: BorderRadius.circular(999),
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color.withValues(alpha: 0.7)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeSoonPanel extends StatelessWidget {
  const _HomeSoonPanel({required this.plants, required this.onTapPlant});

  final List<PlantItem> plants;
  final ValueChanged<PlantItem> onTapPlant;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.soonTasksTitle,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            context.l10n.soonTasksHint,
            style: const TextStyle(color: Colors.black54, height: 1.4),
          ),
          const SizedBox(height: 14),
          ..._withGaps(
            plants.take(3).map((plant) {
              return CompactPlantCard(
                plant: plant,
                onTap: () => onTapPlant(plant),
              );
            }).toList(),
            gap: 0,
          ),
        ],
      ),
    );
  }
}

class _HomeCalmPanel extends StatelessWidget {
  const _HomeCalmPanel({required this.healthyCount});

  final int healthyCount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF3EB),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.routineStableTitle,
            style: const TextStyle(
              color: Color(0xFF234F29),
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.stableRoutineBody(healthyCount),
            style: const TextStyle(color: Color(0xFF4C6351), height: 1.45),
          ),
        ],
      ),
    );
  }
}

enum _MyPlantsBrowseMode { location, plant, photo }

class OrganizedMyPlantsTab extends StatefulWidget {
  const OrganizedMyPlantsTab({
    super.key,
    required this.plants,
    required this.presets,
    required this.bottomPadding,
    required this.onTapPlant,
    required this.onEditPlant,
    required this.onWaterPlant,
    required this.onRepotPlant,
    required this.pinnedPlantId,
    required this.onTogglePinnedPlant,
    required this.onAddPlant,
  });

  final List<PlantItem> plants;
  final List<PlantPreset> presets;
  final double bottomPadding;
  final ValueChanged<PlantItem> onTapPlant;
  final Future<void> Function(PlantItem) onEditPlant;
  final ValueChanged<PlantItem> onWaterPlant;
  final ValueChanged<PlantItem> onRepotPlant;
  final String? pinnedPlantId;
  final ValueChanged<PlantItem> onTogglePinnedPlant;
  final VoidCallback onAddPlant;

  @override
  State<OrganizedMyPlantsTab> createState() => _OrganizedMyPlantsTabState();
}

class _OrganizedMyPlantsTabState extends State<OrganizedMyPlantsTab> {
  _MyPlantsBrowseMode _browseMode = _MyPlantsBrowseMode.location;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final sortedPlants = _sortPlantsByUrgency(widget.plants);
    final presetImageByType = _buildPresetImageByType(widget.presets);
    final locationGroups = _groupPlantEntries(
      sortedPlants,
      (plant) => plant.location.trim().isEmpty
          ? l10n.locationUnset
          : plant.location.trim(),
    );
    final typeGroups = _groupPlantEntries(
      sortedPlants,
      (plant) => plant.type.trim().isEmpty ? l10n.plantType : plant.type.trim(),
    );
    final photoEntries = _collectPlantPhotoEntries(sortedPlants);

    final content = switch (_browseMode) {
      _MyPlantsBrowseMode.location => [
        for (final entry in locationGroups)
          _PlantGroupCard(
            title: entry.key,
            subtitle: l10n.groupedPlantsSubtitle(entry.value.length),
            plants: entry.value,
            presetImageByType: presetImageByType,
            pinnedPlantId: widget.pinnedPlantId,
            onTapPlant: widget.onTapPlant,
            onEditPlant: widget.onEditPlant,
            onWaterPlant: widget.onWaterPlant,
            onRepotPlant: widget.onRepotPlant,
            onTogglePinnedPlant: widget.onTogglePinnedPlant,
          ),
      ],
      _MyPlantsBrowseMode.plant => [
        for (final entry in typeGroups)
          _PlantGroupCard(
            title: entry.key,
            subtitle: l10n.groupedRegisteredSubtitle(entry.value.length),
            plants: entry.value,
            presetImageByType: presetImageByType,
            pinnedPlantId: widget.pinnedPlantId,
            onTapPlant: widget.onTapPlant,
            onEditPlant: widget.onEditPlant,
            onWaterPlant: widget.onWaterPlant,
            onRepotPlant: widget.onRepotPlant,
            onTogglePinnedPlant: widget.onTogglePinnedPlant,
          ),
      ],
      _MyPlantsBrowseMode.photo => [
        if (photoEntries.isEmpty)
          EmptyCard(message: l10n.noPhotosToShow)
        else
          for (final entry in photoEntries)
            _PlantPhotoFeedCard(
              entry: entry,
              isPinned: widget.pinnedPlantId == entry.plant.id,
              onTap: () => widget.onTapPlant(entry.plant),
              onEdit: () => widget.onEditPlant(entry.plant),
              onTogglePinned: () => widget.onTogglePinnedPlant(entry.plant),
            ),
      ],
    };

    return Padding(
      padding: const EdgeInsets.all(20),
      child: ListView(
        padding: EdgeInsets.only(bottom: widget.bottomPadding),
        children: [
          _MyPlantsBrowseHeader(
            selectedMode: _browseMode,
            plantCount: widget.plants.length,
            onModeSelected: (_MyPlantsBrowseMode mode) {
              setState(() {
                _browseMode = mode;
              });
            },
          ),
          const SizedBox(height: 18),
          ..._withGaps(content, gap: 16),
        ],
      ),
    );
  }
}

class _MyPlantsBrowseHeader extends StatelessWidget {
  const _MyPlantsBrowseHeader({
    required this.selectedMode,
    required this.plantCount,
    required this.onModeSelected,
  });

  final _MyPlantsBrowseMode selectedMode;
  final int plantCount;
  final ValueChanged<_MyPlantsBrowseMode> onModeSelected;

  @override
  Widget build(BuildContext context) {
    final tabs = <(_MyPlantsBrowseMode, String)>[
      (_MyPlantsBrowseMode.location, context.l10n.location),
      (_MyPlantsBrowseMode.plant, context.l10n.plantTabLabel),
      (_MyPlantsBrowseMode.photo, context.l10n.photoTabLabel),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F0E2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                context.l10n.registeredPlantsCount(plantCount),
                style: const TextStyle(
                  color: Color(0xFF6A8262),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: const Color(0xFFE7EDD7),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (mode, label) in tabs)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: _BrowseTabChip(
                    label: label,
                    isSelected: selectedMode == mode,
                    onTap: () => onModeSelected(mode),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BrowseTabChip extends StatelessWidget {
  const _BrowseTabChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2E5B2E) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : const Color(0xFF8A9A76),
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

// ignore: unused_element
class _PlantManagerCard extends StatelessWidget {
  const _PlantManagerCard({
    required this.plant,
    required this.isPinned,
    required this.onTap,
    required this.onEdit,
    required this.onTogglePinned,
  });

  final PlantItem plant;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final color = _statusColor(plant.status);
    final badge = l10n.statusBadgeLabel(plant.status);
    final locationLabel = plant.location.trim().isEmpty
        ? l10n.locationUnset
        : plant.location.trim();

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.18)),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox(
                width: 92,
                height: 92,
                child: plant.photoAssetIds.isNotEmpty
                    ? PlantPhotoThumb(
                        assetId: plant.photoAssetIds.first,
                        width: 92,
                        height: 92,
                        borderRadius: 0,
                      )
                    : _PlantImagePlaceholder(
                        background: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                        ),
                        iconColor: color,
                        iconSize: 24,
                      ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    plant.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$badge${l10n.statusBadgeDetail(plant.status, plant.daysUntilWatering)}',
                    style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.lastWateredAgoLabel(
                      DateTime.now().difference(plant.lastWateredAt).inDays,
                    ),
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${plant.type} · $locationLabel',
                    style: const TextStyle(color: Colors.black45),
                  ),
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  onPressed: onTogglePinned,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isPinned
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isPinned
                        ? const Color(0xFFD95C45)
                        : const Color(0xFF8DA08E),
                  ),
                ),
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantGroupCard extends StatelessWidget {
  const _PlantGroupCard({
    required this.title,
    required this.subtitle,
    required this.plants,
    required this.presetImageByType,
    required this.pinnedPlantId,
    required this.onTapPlant,
    required this.onEditPlant,
    required this.onWaterPlant,
    required this.onRepotPlant,
    required this.onTogglePinnedPlant,
  });

  final String title;
  final String subtitle;
  final List<PlantItem> plants;
  final Map<String, String> presetImageByType;
  final String? pinnedPlantId;
  final ValueChanged<PlantItem> onTapPlant;
  final Future<void> Function(PlantItem) onEditPlant;
  final ValueChanged<PlantItem> onWaterPlant;
  final ValueChanged<PlantItem> onRepotPlant;
  final ValueChanged<PlantItem> onTogglePinnedPlant;

  @override
  Widget build(BuildContext context) {
    final urgentCount = plants
        .where((plant) => plant.status != PlantStatus.healthy)
        .length;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GroupPhotoStrip(
            plants: plants,
            presetImageByType: presetImageByType,
            onEditPlant: onEditPlant,
            onWaterPlant: onWaterPlant,
            onRepotPlant: onRepotPlant,
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
              if (urgentCount > 0)
                Tooltip(
                  message: context.l10n.urgentTooltip,
                  triggerMode: TooltipTriggerMode.tap,
                  constraints: const BoxConstraints(maxWidth: 240),
                  textStyle: const TextStyle(
                    color: Colors.white,
                    height: 1.35,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFE7E2),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      context.l10n.urgentCountLabel(urgentCount),
                      style: const TextStyle(
                        color: Color(0xFFD95C45),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ..._withGaps(
            plants.take(5).map((plant) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: _statusColor(plant.status).withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => onTogglePinnedPlant(plant),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(
                        pinnedPlantId == plant.id
                            ? Icons.favorite_rounded
                            : Icons.favorite_border_rounded,
                        size: 20,
                        color: pinnedPlantId == plant.id
                            ? const Color(0xFFD95C45)
                            : const Color(0xFF8DA08E),
                      ),
                      tooltip: context.l10n.home,
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => onTapPlant(plant),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            plant.name,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => onEditPlant(plant),
                      visualDensity: VisualDensity.compact,
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      tooltip: context.l10n.edit,
                    ),
                  ],
                ),
              );
            }).toList(),
            gap: 8,
          ),
        ],
      ),
    );
  }
}

class _GroupPhotoStrip extends StatelessWidget {
  const _GroupPhotoStrip({
    required this.plants,
    required this.presetImageByType,
    required this.onEditPlant,
    required this.onWaterPlant,
    required this.onRepotPlant,
  });

  final List<PlantItem> plants;
  final Map<String, String> presetImageByType;
  final Future<void> Function(PlantItem) onEditPlant;
  final ValueChanged<PlantItem> onWaterPlant;
  final ValueChanged<PlantItem> onRepotPlant;

  @override
  Widget build(BuildContext context) {
    final previewItems = plants
        .take(4)
        .map(
          (plant) => _GroupPreviewItem(
            plant: plant,
            assetId: plant.photoAssetIds.isNotEmpty
                ? plant.photoAssetIds.first
                : null,
          ),
        )
        .toList(growable: false);
    final hiddenCount = plants.length > 4 ? plants.length - 4 : 0;
    final itemCount = previewItems.length;
    if (itemCount == 0) {
      return const SizedBox.shrink();
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.maxWidth.isFinite || constraints.maxWidth <= 0) {
          return const SizedBox(
            height: 152,
            child: ColoredBox(color: Colors.transparent),
          );
        }

        const gap = 8.0;
        final rawHeight = switch (itemCount) {
          1 => constraints.maxWidth,
          2 || 3 || 4 => (constraints.maxWidth - gap) / 2,
          _ => (constraints.maxWidth - (gap * 2)) / 3,
        };
        final double mosaicHeight = rawHeight.clamp(96.0, 240.0);

        if (!mosaicHeight.isFinite || mosaicHeight <= 0) {
          return const SizedBox(
            height: 152,
            child: ColoredBox(color: Colors.transparent),
          );
        }

        return SizedBox(
          height: mosaicHeight,
          child: _buildMosaic(
            context,
            items: previewItems,
            presetImageByType: presetImageByType,
            hiddenCount: hiddenCount,
            gap: gap,
            height: mosaicHeight,
          ),
        );
      },
    );
  }

  Widget _buildMosaic(
    BuildContext context, {
    required List<_GroupPreviewItem> items,
    required Map<String, String> presetImageByType,
    required int hiddenCount,
    required double gap,
    required double height,
  }) {
    Widget tile(
      _GroupPreviewItem item, {
      required bool isLastVisible,
      BorderRadius radius = const BorderRadius.all(Radius.circular(20)),
    }) {
      return _GroupPreviewTile(
        item: item,
        presetImageUrl: _plantPresetImageUrl(
          presetImageByType,
          item.plant,
        ),
        borderRadius: radius,
        hiddenCount: isLastVisible ? hiddenCount : 0,
        onTap: () {
          final initialIndex = items.indexOf(item);
          if (initialIndex < 0) return;
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => _MyPlantPhotoViewerPage(
                items: items,
                presetImageByType: presetImageByType,
                initialIndex: initialIndex,
                onEditPlant: onEditPlant,
                onWaterPlant: onWaterPlant,
                onRepotPlant: onRepotPlant,
              ),
            ),
          );
        },
      );
    }

    switch (items.length) {
      case 1:
        return tile(items[0], isLastVisible: true);
      case 2:
        return Row(
          children: [
            Expanded(child: tile(items[0], isLastVisible: false)),
            SizedBox(width: gap),
            Expanded(child: tile(items[1], isLastVisible: true)),
          ],
        );
      case 3:
        return Row(
          children: [
            Expanded(
              flex: 2,
              child: tile(items[0], isLastVisible: false),
            ),
            SizedBox(width: gap),
            Expanded(
              flex: 1,
              child: Column(
                children: [
                  Expanded(child: tile(items[1], isLastVisible: false)),
                  SizedBox(height: gap),
                  Expanded(child: tile(items[2], isLastVisible: true)),
                ],
              ),
            ),
          ],
        );
      case 4:
        return Row(
          children: [
            Expanded(child: tile(items[0], isLastVisible: false)),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tile(items[1], isLastVisible: false)),
                  SizedBox(height: gap),
                  Expanded(child: tile(items[2], isLastVisible: false)),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(child: tile(items[3], isLastVisible: true)),
          ],
        );
      default:
        return Row(
          children: [
            Expanded(child: tile(items[0], isLastVisible: false)),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tile(items[1], isLastVisible: false)),
                  SizedBox(height: gap),
                  Expanded(child: tile(items[2], isLastVisible: false)),
                ],
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: Column(
                children: [
                  Expanded(child: tile(items[3], isLastVisible: false)),
                  SizedBox(height: gap),
                  Expanded(child: tile(items[4], isLastVisible: true)),
                ],
              ),
            ),
          ],
        );
    }
  }
}

class _GroupPreviewItem {
  const _GroupPreviewItem({
    required this.plant,
    this.assetId,
  });

  final PlantItem plant;
  final String? assetId;
}

class _GroupPreviewTile extends StatelessWidget {
  const _GroupPreviewTile({
    required this.item,
    required this.presetImageUrl,
    required this.borderRadius,
    required this.hiddenCount,
    required this.onTap,
  });

  final _GroupPreviewItem item;
  final String? presetImageUrl;
  final BorderRadius borderRadius;
  final int hiddenCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final color = _statusColor(item.plant.status);
    const overlayFontSize = 24.0;
    final child = LayoutBuilder(
      builder: (context, constraints) {
        final tileWidth = constraints.maxWidth.isFinite && constraints.maxWidth > 0
            ? constraints.maxWidth
            : 120.0;
        final tileHeight =
            constraints.maxHeight.isFinite && constraints.maxHeight > 0
            ? constraints.maxHeight
            : tileWidth;

        return ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if ((item.assetId ?? '').isNotEmpty)
                PlantPhotoThumb(
                  assetId: item.assetId!,
                  width: tileWidth,
                  height: tileHeight,
                  borderRadius: 0,
                )
              else if ((presetImageUrl ?? '').isNotEmpty)
                Image.network(
                  presetImageUrl!,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      _PlantImagePlaceholder(
                        background: BoxDecoration(
                          color: color.withValues(alpha: 0.18),
                        ),
                        iconColor: color,
                        iconSize: 28,
                      ),
                )
              else
                _PlantImagePlaceholder(
                  background: BoxDecoration(
                    color: color.withValues(alpha: 0.18),
                  ),
                  iconColor: color,
                  iconSize: 28,
                ),
              if (hiddenCount > 0)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.42),
                  ),
                  child: Center(
                    child: Text(
                      hiddenCount > 99 ? '99+' : '+$hiddenCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: overlayFontSize,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );

    if (onTap == null) {
      return child;
    }
    return InkWell(
      onTap: onTap,
      borderRadius: borderRadius,
      child: child,
    );
  }
}

class _MyPlantPhotoViewerPage extends StatefulWidget {
  const _MyPlantPhotoViewerPage({
    required this.items,
    required this.presetImageByType,
    required this.initialIndex,
    required this.onEditPlant,
    required this.onWaterPlant,
    required this.onRepotPlant,
  });

  final List<_GroupPreviewItem> items;
  final Map<String, String> presetImageByType;
  final int initialIndex;
  final Future<void> Function(PlantItem) onEditPlant;
  final ValueChanged<PlantItem> onWaterPlant;
  final ValueChanged<PlantItem> onRepotPlant;

  @override
  State<_MyPlantPhotoViewerPage> createState() => _MyPlantPhotoViewerPageState();
}

class _MyPlantPhotoViewerPageState extends State<_MyPlantPhotoViewerPage> {
  late final PageController _controller;
  late final List<_GroupPreviewItem> _items;
  late final Map<String, int> _selectedPhotoIndexByPlantId;
  late int _currentIndex;
  bool _isChromeVisible = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _controller = PageController(initialPage: widget.initialIndex);
    _items = widget.items
        .map(
          (item) => _GroupPreviewItem(
            plant: item.plant.copy(),
            assetId: item.assetId,
          ),
        )
        .toList(growable: false);
    _selectedPhotoIndexByPlantId = {
      for (final item in _items)
        item.plant.id: _initialPhotoIndexFor(item),
    };
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _initialPhotoIndexFor(_GroupPreviewItem item) {
    if (item.assetId == null || item.assetId!.isEmpty) {
      return 0;
    }
    final index = item.plant.photoAssetIds.indexOf(item.assetId!);
    return index < 0 ? 0 : index;
  }

  List<String> _galleryAssetIds(PlantItem plant) {
    return List<String>.from(plant.photoAssetIds);
  }

  int _selectedPhotoIndex(PlantItem plant) {
    final assetIds = _galleryAssetIds(plant);
    if (assetIds.isEmpty) {
      return 0;
    }
    final rawIndex = _selectedPhotoIndexByPlantId[plant.id] ?? 0;
    if (rawIndex < 0) {
      return 0;
    }
    if (rawIndex >= assetIds.length) {
      return assetIds.length - 1;
    }
    return rawIndex;
  }

  void _selectPhoto(PlantItem plant, int index) {
    setState(() {
      _selectedPhotoIndexByPlantId[plant.id] = index;
    });
  }

  void _handleWatered() {
    final plant = _items[_currentIndex].plant;
    widget.onWaterPlant(plant);
    setState(() {
      plant.lastWateredAt = DateTime.now();
    });
  }

  void _handleRepotted() {
    widget.onRepotPlant(_items[_currentIndex].plant);
  }

  Future<void> _handleEdit() async {
    final plant = _items[_currentIndex].plant;
    Navigator.of(context).pop();
    await widget.onEditPlant(plant);
  }

  void _toggleChrome() {
    setState(() {
      _isChromeVisible = !_isChromeVisible;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final item = _items[_currentIndex];
    final plant = item.plant;
    final assetIds = _galleryAssetIds(plant);
    final selectedPhotoIndex = _selectedPhotoIndex(plant);
    final currentAssetId = assetIds.isEmpty ? null : assetIds[selectedPhotoIndex];
    final location = plant.location.trim().isEmpty
        ? l10n.locationUnset
        : plant.location.trim();

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PageView.builder(
            controller: _controller,
            itemCount: _items.length,
            onPageChanged: (index) {
              setState(() {
                _currentIndex = index;
                _isChromeVisible = true;
              });
            },
            itemBuilder: (context, index) {
              final previewItem = _items[index];
              final presetImageUrl = _plantPresetImageUrl(
                widget.presetImageByType,
                previewItem.plant,
              );
              final previewAssetIds = _galleryAssetIds(previewItem.plant);
              final previewSelectedIndex = _selectedPhotoIndex(previewItem.plant);
              final previewAssetId = previewAssetIds.isEmpty
                  ? null
                  : previewAssetIds[previewSelectedIndex];
              final mediaKey = ValueKey(
                '${previewItem.plant.id}:${previewAssetId ?? presetImageUrl ?? 'fallback'}',
              );
              return Center(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleChrome,
                  child: InteractiveViewer(
                    child: KeyedSubtree(
                      key: mediaKey,
                      child: SizedBox(
                        width: MediaQuery.of(context).size.width,
                        height: MediaQuery.of(context).size.height * 0.72,
                        child: (previewAssetId ?? '').isNotEmpty
                            ? _ViewerAssetImage(
                                key: mediaKey,
                                assetId: previewAssetId!,
                                width: MediaQuery.of(context).size.width,
                                height: MediaQuery.of(context).size.height * 0.72,
                              )
                            : ((presetImageUrl ?? '').isNotEmpty
                                  ? Image.network(
                                      presetImageUrl!,
                                      key: mediaKey,
                                      fit: BoxFit.cover,
                                      errorBuilder: (context, error, stackTrace) =>
                                          _PlantImagePlaceholder(
                                            background: BoxDecoration(
                                              color: _statusColor(
                                                previewItem.plant.status,
                                              ).withValues(alpha: 0.18),
                                            ),
                                            iconColor: _statusColor(
                                              previewItem.plant.status,
                                            ),
                                            iconSize: 42,
                                          ),
                                    )
                                  : _PlantImagePlaceholder(
                                      background: BoxDecoration(
                                        color: _statusColor(
                                          previewItem.plant.status,
                                        ).withValues(alpha: 0.18),
                                      ),
                                      iconColor: _statusColor(
                                        previewItem.plant.status,
                                      ),
                                      iconSize: 42,
                                    )),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              ignoring: !_isChromeVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _isChromeVisible ? 1 : 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    12,
                    8 + MediaQuery.of(context).viewPadding.top,
                    12,
                    12,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.62),
                        Colors.black.withValues(alpha: 0),
                      ],
                    ),
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Colors.white,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          l10n.photoIndexLabel(_currentIndex + 1, _items.length),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 16,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: IgnorePointer(
              ignoring: !_isChromeVisible,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: _isChromeVisible ? 1 : 0,
                child: Container(
                  padding: EdgeInsets.fromLTRB(
                    20,
                    28,
                    20,
                    20 + MediaQuery.of(context).viewPadding.bottom,
                  ),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.76),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (assetIds.length > 1) ...[
                        SizedBox(
                          height: 74,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: assetIds.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 10),
                            itemBuilder: (context, index) {
                              final isSelected = index == selectedPhotoIndex;
                              return GestureDetector(
                                onTap: () => _selectPhoto(plant, index),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 160),
                                  width: 74,
                                  height: 74,
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: isSelected
                                          ? Colors.white
                                          : Colors.white.withValues(alpha: 0.24),
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(15),
                                    child: PlantPhotoThumb(
                                      key: ValueKey(
                                        '${plant.id}:${assetIds[index]}:$index',
                                      ),
                                      assetId: assetIds[index],
                                      width: 70,
                                      height: 70,
                                      borderRadius: 0,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: _handleWatered,
                              icon: const Icon(Icons.water_drop_outlined),
                              label: Text(l10n.markWatered),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                backgroundColor: const Color(0xFF5CA96B),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: _handleRepotted,
                              icon: const Icon(Icons.inventory_2_outlined),
                              label: Text(l10n.repotDone),
                              style: OutlinedButton.styleFrom(
                                minimumSize: const Size.fromHeight(48),
                                foregroundColor: Colors.white,
                                side: BorderSide(
                                  color: Colors.white.withValues(alpha: 0.78),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(18),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              plant.name,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            onPressed: _handleEdit,
                            visualDensity: VisualDensity.compact,
                            tooltip: l10n.edit,
                            icon: const Icon(
                              Icons.edit_rounded,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${plant.type} · $location',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                      if (currentAssetId != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          l10n.photoPositionLabel(
                            selectedPhotoIndex + 1,
                            assetIds.length,
                          ),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 10),
                      StatusChip(status: plant.status),
                      const SizedBox(height: 10),
                      Text(
                        _dateLabel(plant.nextWateringAt),
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ViewerAssetImage extends StatefulWidget {
  const _ViewerAssetImage({
    super.key,
    required this.assetId,
    required this.width,
    required this.height,
  });

  final String assetId;
  final double width;
  final double height;

  @override
  State<_ViewerAssetImage> createState() => _ViewerAssetImageState();
}

class _ViewerAssetImageState extends State<_ViewerAssetImage> {
  static final Map<String, Future<AssetEntity?>> _entityFutures =
      <String, Future<AssetEntity?>>{};
  static final Map<String, Future<Uint8List?>> _thumbFutures =
      <String, Future<Uint8List?>>{};

  Uint8List? _currentBytes;
  bool _isLoading = true;
  String? _activeAssetId;

  @override
  void initState() {
    super.initState();
    _loadAsset();
  }

  @override
  void didUpdateWidget(covariant _ViewerAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetId != widget.assetId ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      _loadAsset();
    }
  }

  Future<void> _loadAsset() async {
    final assetId = widget.assetId;
    _activeAssetId = assetId;
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    final cacheWidth = widget.width.isFinite
        ? widget.width.round().clamp(1, 2048)
        : 1080;
    final cacheHeight = widget.height.isFinite
        ? widget.height.round().clamp(1, 2048)
        : 1440;
    final entityFuture = _entityFutures.putIfAbsent(
      assetId,
      () => AssetEntity.fromId(assetId),
    );
    final entity = await entityFuture;
    if (!mounted || _activeAssetId != assetId) {
      return;
    }
    if (entity == null) {
      setState(() {
        _currentBytes = null;
        _isLoading = false;
      });
      return;
    }

    final thumbKey = '$assetId:$cacheWidth:$cacheHeight';
    final thumbFuture = _thumbFutures.putIfAbsent(
      thumbKey,
      () => entity.thumbnailDataWithSize(
        ThumbnailSize(cacheWidth, cacheHeight),
      ),
    );
    final data = await thumbFuture;
    if (!mounted || _activeAssetId != assetId) {
      return;
    }
    setState(() {
      _currentBytes = data;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        if (_currentBytes != null)
          Image.memory(
            _currentBytes!,
            width: widget.width,
            height: widget.height,
            fit: BoxFit.cover,
            gaplessPlayback: true,
            filterQuality: FilterQuality.medium,
          )
        else
          const ColoredBox(color: Colors.black),
        if (_isLoading)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.18),
            ),
            child: const Center(
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: Colors.white,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _PlantPhotoFeedCard extends StatelessWidget {
  const _PlantPhotoFeedCard({
    required this.entry,
    required this.isPinned,
    required this.onTap,
    required this.onEdit,
    required this.onTogglePinned,
  });

  final _PlantPhotoEntry entry;
  final bool isPinned;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onTogglePinned;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final location = entry.plant.location.trim().isEmpty
        ? l10n.locationUnset
        : entry.plant.location.trim();
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            PlantPhotoThumb(
              assetId: entry.assetId,
              width: 112,
              height: 112,
              borderRadius: 18,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.plant.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${entry.plant.type} · $location',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 10),
                  StatusChip(status: entry.plant.status),
                  const SizedBox(height: 10),
                  Text(
                    _dateLabel(entry.plant.nextWateringAt),
                    style: const TextStyle(
                      color: Color(0xFF56705B),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: onTogglePinned,
                  visualDensity: VisualDensity.compact,
                  icon: Icon(
                    isPinned
                        ? Icons.favorite_rounded
                        : Icons.favorite_border_rounded,
                    color: isPinned
                        ? const Color(0xFFD95C45)
                        : const Color(0xFF8DA08E),
                  ),
                  tooltip: l10n.home,
                ),
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_rounded),
                  tooltip: l10n.edit,
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PlantPhotoEntry {
  const _PlantPhotoEntry({required this.plant, required this.assetId});

  final PlantItem plant;
  final String assetId;
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
  final l10n = AppLocalizations.forLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
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
  final l10n = AppLocalizations.forLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  );
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
  return AppLocalizations.forLocale(
    WidgetsBinding.instance.platformDispatcher.locale,
  ).dateLabel(date);
}

String _normalizePlantTypeKey(String value) {
  return value.trim().toLowerCase();
}

Map<String, String> _buildPresetImageByType(List<PlantPreset> presets) {
  final entries = <PlantPreset>[
    ...kPlantPresets,
    ...presets,
  ];
  final imageByType = <String, String>{};
  for (final preset in entries) {
    final imageUrl = (preset.imageUrl ?? '').trim();
    if (imageUrl.isEmpty) {
      continue;
    }
    final candidateTypes = <String>{
      preset.type,
      ...preset.aliases,
    };
    for (final candidate in candidateTypes) {
      final rawType = candidate.trim();
      if (rawType.isEmpty) {
        continue;
      }
      imageByType[rawType] = imageUrl;
      final normalizedType = _normalizePlantTypeKey(rawType);
      if (normalizedType.isNotEmpty) {
        imageByType[normalizedType] = imageUrl;
      }
    }
  }
  return imageByType;
}

String? _presetImageUrl(
  Map<String, String> presetImageByType,
  String plantType,
) {
  final rawType = plantType.trim();
  if (rawType.isEmpty) {
    return null;
  }
  return presetImageByType[rawType] ??
      presetImageByType[_normalizePlantTypeKey(rawType)];
}

String? _plantPresetImageUrl(
  Map<String, String> presetImageByType,
  PlantItem plant,
) {
  final savedImageUrl = (plant.presetImageUrl ?? '').trim();
  if (savedImageUrl.isNotEmpty) {
    return savedImageUrl;
  }
  return _presetImageUrl(presetImageByType, plant.type);
}

bool _applyPresetImagesToPlants(
  List<PlantItem> plants,
  List<PlantPreset> presets,
) {
  final presetImageByType = _buildPresetImageByType(presets);
  var updated = false;
  for (final plant in plants) {
    final resolvedImageUrl = _presetImageUrl(presetImageByType, plant.type);
    if ((plant.presetImageUrl ?? '').trim().isEmpty &&
        (resolvedImageUrl ?? '').isNotEmpty) {
      plant.presetImageUrl = resolvedImageUrl;
      updated = true;
    }
  }
  return updated;
}

List<PlantItem> _sortPlantsByUrgency(List<PlantItem> plants) {
  final sorted = List<PlantItem>.from(plants);
  sorted.sort((a, b) {
    final priorityCompare = _plantPriorityScore(
      a,
    ).compareTo(_plantPriorityScore(b));
    if (priorityCompare != 0) return priorityCompare;

    final dayCompare = a.daysUntilWatering.compareTo(b.daysUntilWatering);
    if (dayCompare != 0) return dayCompare;

    final cycleCompare = a.wateringCycleDays.compareTo(b.wateringCycleDays);
    if (cycleCompare != 0) return cycleCompare;

    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return sorted;
}

List<MapEntry<String, List<PlantItem>>> _groupPlantEntries(
  List<PlantItem> plants,
  String Function(PlantItem plant) keyBuilder,
) {
  final grouped = <String, List<PlantItem>>{};
  for (final plant in plants) {
    final key = keyBuilder(plant);
    grouped.putIfAbsent(key, () => <PlantItem>[]).add(plant);
  }
  final entries = grouped.entries.toList();
  entries.sort((a, b) {
    final priorityCompare = _plantPriorityScore(
      a.value.first,
    ).compareTo(_plantPriorityScore(b.value.first));
    if (priorityCompare != 0) return priorityCompare;
    return a.key.toLowerCase().compareTo(b.key.toLowerCase());
  });
  return entries;
}

List<_PlantPhotoEntry> _collectPlantPhotoEntries(List<PlantItem> plants) {
  final entries = <_PlantPhotoEntry>[];
  for (final plant in plants) {
    for (final assetId in plant.photoAssetIds) {
      entries.add(_PlantPhotoEntry(plant: plant, assetId: assetId));
    }
  }
  return entries;
}

List<Widget> _withGaps(List<Widget> widgets, {double gap = 12}) {
  if (widgets.isEmpty) return widgets;
  final spaced = <Widget>[];
  for (var i = 0; i < widgets.length; i++) {
    if (i > 0) {
      spaced.add(SizedBox(height: gap));
    }
    spaced.add(widgets[i]);
  }
  return spaced;
}

int _plantPriorityScore(PlantItem plant) {
  return switch (plant.status) {
    PlantStatus.overdue => 0,
    PlantStatus.today => 1,
    PlantStatus.soon => 2,
    PlantStatus.healthy => 3,
  };
}
