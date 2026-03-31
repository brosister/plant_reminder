import 'dart:io';

import 'package:flutter/material.dart';

import 'app_settings_service.dart';
import 'auth_service.dart';
import 'main.dart' show SettingsTile;

class SettingsDialog extends StatelessWidget {
  const SettingsDialog({
    super.key,
    required this.authUser,
    required this.isSigningIn,
    required this.settings,
    required this.onSignInPressed,
    required this.onSignOutPressed,
    required this.onSettingsChanged,
  });

  final AppAuthUser? authUser;
  final bool isSigningIn;
  final AppSettings settings;
  final Future<void> Function() onSignInPressed;
  final Future<void> Function() onSignOutPressed;
  final Future<void> Function(AppSettings settings) onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: DefaultTabController(
        length: 3,
        child: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            children: [
              const SizedBox(height: 16),
              const Text('설정', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              const TabBar(
                tabs: [
                  Tab(text: '계정'),
                  Tab(text: '알림'),
                  Tab(text: '기타'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AccountSettingsTab(
                      authUser: authUser,
                      isSigningIn: isSigningIn,
                      onSignInPressed: onSignInPressed,
                      onSignOutPressed: onSignOutPressed,
                    ),
                    _NotificationSettingsTab(
                      settings: settings,
                      onSettingsChanged: onSettingsChanged,
                    ),
                    const _EtcSettingsTab(),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('닫기'),
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

class _AccountSettingsTab extends StatelessWidget {
  const _AccountSettingsTab({
    required this.authUser,
    required this.isSigningIn,
    required this.onSignInPressed,
    required this.onSignOutPressed,
  });

  final AppAuthUser? authUser;
  final bool isSigningIn;
  final Future<void> Function() onSignInPressed;
  final Future<void> Function() onSignOutPressed;

  @override
  Widget build(BuildContext context) {
    final isAndroid = !Platform.isIOS;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text('비로그인 상태로도 바로 사용할 수 있습니다.', style: TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
          child: authUser == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('계정 미연동', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Text(
                      '나중에 Firebase 푸시 공지, 백업/동기화 연결을 위해 소셜 계정 연동을 사용할 수 있습니다.',
                      style: TextStyle(color: Colors.black54, height: 1.4),
                    ),
                    const SizedBox(height: 18),
                    if (isAndroid)
                      FilledButton.icon(
                        onPressed: isSigningIn ? null : () => onSignInPressed(),
                        icon: const Icon(Icons.login),
                        label: Text(isSigningIn ? '로그인 중...' : '구글 로그인'),
                      )
                    else
                      FilledButton.icon(
                        onPressed: isSigningIn ? null : () => onSignInPressed(),
                        icon: const Icon(Icons.apple),
                        label: Text(isSigningIn ? '로그인 중...' : '애플 로그인'),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authUser!.displayName, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 6),
                    Text(authUser!.email, style: const TextStyle(color: Colors.black54)),
                    const SizedBox(height: 6),
                    Text(
                      authUser!.provider == 'google' ? '구글 계정 연동됨' : '애플 계정 연동됨',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: () => onSignOutPressed(),
                      icon: const Icon(Icons.logout),
                      label: const Text('로그아웃'),
                    ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _NotificationSettingsTab extends StatelessWidget {
  const _NotificationSettingsTab({
    required this.settings,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final Future<void> Function(AppSettings settings) onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final timeLabel = '${settings.notificationHour.toString().padLeft(2, '0')}:${settings.notificationMinute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          value: settings.notificationsEnabled,
          onChanged: (value) => onSettingsChanged(settings.copyWith(notificationsEnabled: value)),
          title: const Text('물주기 알림 사용'),
          subtitle: const Text('등록한 식물의 다음 물주기 시점에 로컬 알림을 보냅니다.'),
          contentPadding: EdgeInsets.zero,
        ),
        const SizedBox(height: 12),
        ListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('기본 알림 시간'),
          subtitle: Text(timeLabel),
          trailing: const Icon(Icons.schedule_outlined),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(hour: settings.notificationHour, minute: settings.notificationMinute),
            );
            if (picked != null) {
              await onSettingsChanged(
                settings.copyWith(notificationHour: picked.hour, notificationMinute: picked.minute),
              );
            }
          },
        ),
        const SizedBox(height: 16),
        const SettingsTile(
          icon: Icons.campaign_outlined,
          title: 'Firebase 공지 푸시',
          subtitle: 'Firebase 세팅 후 연결 예정',
        ),
      ],
    );
  }
}

class _EtcSettingsTab extends StatelessWidget {
  const _EtcSettingsTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: const [
        SettingsTile(
          icon: Icons.admin_panel_settings_outlined,
          title: '리마인드 어드민',
          subtitle: 'babynote 스타일 어드민 연동 예정',
        ),
        SettingsTile(
          icon: Icons.privacy_tip_outlined,
          title: '개인정보처리방침',
          subtitle: '추후 연결 예정',
        ),
      ],
    );
  }
}
