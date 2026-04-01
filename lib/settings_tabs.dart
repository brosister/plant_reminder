import 'dart:io';

import 'package:flutter/material.dart';

import 'app_localizations.dart';
import 'app_settings_service.dart';
import 'auth_service.dart';

class SettingsDialog extends StatefulWidget {
  const SettingsDialog({
    super.key,
    required this.authUser,
    required this.isSigningIn,
    required this.settings,
    required this.onSendTestNotification,
    required this.onSignInPressed,
    required this.onSignOutPressed,
    required this.onSettingsChanged,
  });

  final AppAuthUser? authUser;
  final bool isSigningIn;
  final AppSettings settings;
  final Future<void> Function() onSendTestNotification;
  final Future<void> Function() onSignInPressed;
  final Future<void> Function() onSignOutPressed;
  final Future<void> Function(AppSettings settings) onSettingsChanged;

  @override
  State<SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<SettingsDialog> {
  late AppSettings _draftSettings;

  @override
  void initState() {
    super.initState();
    _draftSettings = widget.settings;
  }

  @override
  void didUpdateWidget(covariant SettingsDialog oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings != widget.settings) {
      _draftSettings = widget.settings;
    }
  }

  Future<void> _handleSettingsChanged(AppSettings settings) async {
    setState(() {
      _draftSettings = settings;
    });
    await widget.onSettingsChanged(settings);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: DefaultTabController(
        length: 2,
        child: SizedBox(
          width: 560,
          height: 520,
          child: Column(
            children: [
              const SizedBox(height: 20),
              Text(
                l10n.settings,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 14),
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFF3F6F4),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: TabBar(
                  dividerColor: Colors.transparent,
                  indicatorSize: TabBarIndicatorSize.tab,
                  indicator: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.all(Radius.circular(14)),
                  ),
                  tabs: [
                    Tab(text: l10n.account),
                    Tab(text: l10n.notification),
                  ],
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _AccountSettingsTab(
                      authUser: widget.authUser,
                      isSigningIn: widget.isSigningIn,
                      onSignInPressed: widget.onSignInPressed,
                      onSignOutPressed: widget.onSignOutPressed,
                    ),
                    _NotificationSettingsTab(
                      settings: _draftSettings,
                      onSendTestNotification: widget.onSendTestNotification,
                      onSettingsChanged: _handleSettingsChanged,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.close),
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

  void _showPrivacyPolicyDialog(BuildContext context) {
    final l10n = context.l10n;
    showDialog<void>(
      context: context,
      builder: (context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 28,
          ),
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.privacyDialogTitle,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Flexible(
                  child: SingleChildScrollView(
                    child: Text(
                      l10n.privacyDialogBody,
                      style: const TextStyle(
                        height: 1.6,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l10n.close),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final isAndroid = !Platform.isIOS;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBF8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE3ECE6)),
          ),
          child: authUser == null
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.accountNotLinked,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 18),
                    if (isAndroid)
                      _BrandLoginButton(
                        onPressed: isSigningIn ? null : () => onSignInPressed(),
                        label: isSigningIn ? l10n.signingIn : l10n.googleLogin,
                        icon: const _GoogleMark(),
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF111827),
                        borderColor: const Color(0xFFE0E5EA),
                      )
                    else
                      _BrandLoginButton(
                        onPressed: isSigningIn ? null : () => onSignInPressed(),
                        label: isSigningIn ? l10n.signingIn : l10n.appleLogin,
                        icon: const Icon(Icons.apple, size: 22),
                        backgroundColor: const Color(0xFF111111),
                        foregroundColor: Colors.white,
                        borderColor: const Color(0xFF111111),
                      ),
                  ],
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFFEAF5EE),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(
                            authUser!.provider == 'google'
                                ? Icons.alternate_email_rounded
                                : Icons.apple_rounded,
                            color: const Color(0xFF2F855A),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                authUser!.displayName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                authUser!.provider == 'google'
                                    ? l10n.googleLinked
                                    : l10n.appleLinked,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF2F855A),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                l10n.cloudLinked,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.black54,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      authUser!.email,
                      style: const TextStyle(color: Colors.black54),
                    ),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () => onSignOutPressed(),
                        icon: const Icon(Icons.logout),
                        label: Text(l10n.logout),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(18),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(22),
          onTap: () => _showPrivacyPolicyDialog(context),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFE3ECE6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF4F7F5),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Icon(
                    Icons.privacy_tip_outlined,
                    color: Color(0xFF5E6D64),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.privacyPolicy,
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
    );
  }
}

class _NotificationSettingsTab extends StatelessWidget {
  const _NotificationSettingsTab({
    required this.settings,
    required this.onSendTestNotification,
    required this.onSettingsChanged,
  });

  final AppSettings settings;
  final Future<void> Function() onSendTestNotification;
  final Future<void> Function(AppSettings settings) onSettingsChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final timeLabel =
        '${settings.notificationHour.toString().padLeft(2, '0')}:${settings.notificationMinute.toString().padLeft(2, '0')}';

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FBF8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: const Color(0xFFE3ECE6)),
          ),
          child: SwitchListTile(
            value: settings.notificationsEnabled,
            onChanged: (value) => onSettingsChanged(
              settings.copyWith(notificationsEnabled: value),
            ),
            title: Text(l10n.useWateringNotification),
            subtitle: Text(l10n.useWateringNotificationHint),
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: () async {
            final picked = await showTimePicker(
              context: context,
              initialTime: TimeOfDay(
                hour: settings.notificationHour,
                minute: settings.notificationMinute,
              ),
            );
            if (picked != null) {
              await onSettingsChanged(
                settings.copyWith(
                  notificationHour: picked.hour,
                  notificationMinute: picked.minute,
                ),
              );
            }
          },
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFE3ECE6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF1FF),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.schedule_rounded,
                    color: Color(0xFF335EC7),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.defaultNotificationTime,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.tapToChangeReminderTime,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Icon(
                      Icons.chevron_right_rounded,
                      color: Colors.black45,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: onSendTestNotification,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBF2),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color(0xFFF1E0A6)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF1C7),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.notifications_active_outlined,
                    color: Color(0xFF9A6B00),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.sendTestNotification,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.sendTestNotificationHint,
                        style: const TextStyle(
                          color: Colors.black54,
                          fontSize: 13,
                          height: 1.4,
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
      ],
    );
  }
}

class _BrandLoginButton extends StatelessWidget {
  const _BrandLoginButton({
    required this.onPressed,
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.borderColor,
  });

  final VoidCallback? onPressed;
  final String label;
  final Widget icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final Color borderColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: foregroundColor,
          side: BorderSide(color: borderColor),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
        ),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 28),
          ],
        ),
      ),
    );
  }
}

class _GoogleMark extends StatelessWidget {
  const _GoogleMark();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.asset(
        'assets/icons/google_g_logo.webp',
        width: 24,
        height: 24,
        fit: BoxFit.cover,
      ),
    );
  }
}
