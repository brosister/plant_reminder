import 'package:flutter/material.dart';

class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = [
    Locale('ko'),
    Locale('en'),
    Locale('zh'),
    Locale('ja'),
  ];

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  static AppLocalizations of(BuildContext context) {
    final localizations = Localizations.of<AppLocalizations>(context, AppLocalizations);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static AppLocalizations forLocale(Locale locale) => AppLocalizations(_resolveLocale(locale));

  static Locale _resolveLocale(Locale locale) {
    switch (locale.languageCode) {
      case 'ko':
        return const Locale('ko');
      case 'ja':
        return const Locale('ja');
      case 'zh':
        return const Locale('zh');
      case 'en':
        return const Locale('en');
      default:
        return const Locale('en');
    }
  }

  String get _code => _resolveLocale(locale).languageCode;

  String _text(String key) => _localizedValues[_code]?[key] ?? _localizedValues['en']![key] ?? key;

  static const Map<String, Map<String, String>> _localizedValues = {
    'ko': {
      'appTitle': '식물 물주기 알리미',
      'home': '홈',
      'myPlants': '나의 식물',
      'calendar': '달력',
      'stats': '통계',
      'settings': '설정',
      'edit': '수정',
      'close': '닫기',
      'account': '계정',
      'notification': '알림',
      'etc': '기타',
      'notSignedIn': '비로그인 상태로도 바로 사용할 수 있습니다.',
      'accountNotLinked': '계정 미연동',
      'accountHint': '나중에 Firebase 푸시 공지, 백업/동기화 연결을 위해 소셜 계정 연동을 사용할 수 있습니다.',
      'signingIn': '로그인 중...',
      'googleLogin': '구글 로그인',
      'appleLogin': '애플 로그인',
      'googleLinked': '구글 계정 연동됨',
      'appleLinked': '애플 계정 연동됨',
      'logout': '로그아웃',
      'useWateringNotification': '물주기 알림 사용',
      'useWateringNotificationHint': '등록한 식물의 다음 물주기 시점에 로컬 알림을 보냅니다.',
      'defaultNotificationTime': '기본 알림 시간',
      'tapToChangeReminderTime': '눌러서 알림 시간을 변경할 수 있어요.',
      'firebasePush': 'Firebase 공지 푸시',
      'firebasePushHint': 'Firebase 세팅 후 연결 예정',
      'remindAdmin': '리마인드 어드민',
      'remindAdminHint': 'babynote 스타일 어드민 연동 예정',
      'privacyPolicy': '개인정보처리방침',
      'comingSoon': '추후 연결 예정',
      'selectPlantPhotos': '식물 사진 선택',
      'manageAccessiblePhotos': '접근 사진 관리',
      'openSettings': '설정 열기',
      'tryAgain': '다시 시도',
      'done': '완료',
      'manageSelectedPhotos': '선택한 사진 관리',
      'reviewAccessScope': '접근 범위 다시 확인',
      'photoPermissionDenied': '사진 접근 권한이 거부되어 사진을 불러올 수 없습니다. 설정에서 사진 권한을 허용해주세요.',
      'photoPermissionRestricted': '이 기기에서는 사진 접근이 제한되어 있습니다. 기기 설정을 확인해주세요.',
      'photoPermissionLimited': '일부 사진만 접근 가능한 상태입니다. 필요한 사진이 보이지 않으면 접근 범위를 넓혀주세요.',
      'photoPermissionRequired': '사진 접근 권한이 필요합니다.',
      'noPhotosToShow': '표시할 사진이 없습니다.',
      'failedToLoadAlbum': '앨범을 불러오지 못했습니다.',
      'limitedAccessBanner': '현재 일부 사진만 접근 가능합니다. 필요한 사진이 없다면 오른쪽 상단에서 접근 범위를 조정하세요.',
      'multiPhotoHint': '여러 장을 선택할 수 있습니다. 식물 대표 사진과 기록 사진으로 활용됩니다.',
      'representativePhoto': '대표 사진',
      'noPlantPhoto': '등록된 식물 사진이 없습니다.',
      'basicInfo': '기본 정보',
      'plantType': '식물 종류',
      'location': '위치',
      'sunlight': '햇빛 추천',
      'wateringCycle': '물주기 주기',
      'lastWateredDate': '마지막 물준 날짜',
      'nextWatering': '다음 물주기',
      'memo': '메모',
      'noMemo': '메모가 없습니다.',
      'markWatered': '물 줬어요',
      'days': '일',
      'detailMemo': '상세 / 메모',
      'todayRoutine': '오늘의 가드닝 루틴',
      'todayCareRelaxed': '오늘은 쉬어가는\n가벼운 식물 케어',
      'todayTasks': '오늘 관리',
      'soonNeed': '곧 필요',
      'healthyState': '안정 상태',
      'todayPriority': '오늘 우선순위',
      'noUrgentPlants': '급한 식물 없음',
      'recommendWateringNow': '바로 물주기 추천',
      'relaxed': '여유로움',
      'nextCheck': '다음 체크',
      'nothingScheduled': '예정 없음',
      'comingSoonLabel': '곧 다가옴',
      'stable': '안정적',
      'todayTodo': '오늘 해야 할 일',
      'todayTodoHint': '급한 순서대로 바로 처리할 수 있게 정리했어요.',
      'noPlantForToday': '오늘 바로 처리할 식물은 없습니다.',
      'checkSoonPlants': '곧 확인할 식물',
      'checkSoonPlantsHint': '하루 이틀 안에 체크하면 좋은 식물들이에요.',
      'noSoonPlants': '곧 물줄 식물이 아직 없습니다.',
      'myPlantsGuide': '등록한 식물을 눌러 사진, 메모, 물주기 주기를 바로 수정할 수 있어요.',
      'calendarNoSchedule': '이 달에 예정된 물주기 일정이 없습니다.',
      'calendarBadgeHint': '물주기 일정이 있는 날에는 초록 점과 개수로 표시돼요.',
      'statsTitle': '한눈에 보는 식물 상태',
      'noPlantsYet': '등록된 식물이 아직 없어요.',
      'statsCycleFlow': '물주기 주기 흐름',
      'statsCycleFlowHint': '식물마다 주기가 얼마나 다른지 한 번에 볼 수 있어요.',
      'oldestOverdueHint': '오래 방치된 식물이 있어요. 오늘은 급한 식물부터 물주기 체크를 시작해보세요.',
      'stableFlowHint': '전체적으로 관리 흐름이 안정적이에요. 오늘 물주기 예정 식물만 가볍게 확인하면 됩니다.',
      'plantInfoEdit': '식물 정보 다듬기',
      'newPlantRegister': '새 식물 등록하기',
      'plantInfoEditHint': '사진, 메모, 물주기 루틴을 한 번에 정리해보세요.',
      'newPlantRegisterHint': '식물 이름과 루틴을 가볍게 입력하고 바로 관리 시작할 수 있어요.',
      'noPhoto': '사진 없음',
      'basicInfoHint': '식물 종류와 이름, 위치를 먼저 정리해둘게요.',
      'searchPlantType': '식물 종류 검색',
      'searchPlantTypeHint': '식물 이름을 입력하면 바로 선택할 수 있어요',
      'myPlantName': '나의 식물 이름',
      'myPlantNameExample': '예: 거실 몬스테라',
      'locationExample': '예: 거실 창가',
      'careRoutine': '관리 루틴',
      'careRoutineHint': '물주기 간격과 마지막 물준 날짜를 깔끔하게 기록해둘 수 있어요.',
      'enterNumbersOnly': '숫자만 입력',
      'memoHintTitle': '기억해두고 싶은 상태나 관리 포인트를 남겨보세요.',
      'memoExample': '예: 새 잎이 올라오는 중, 과습 주의',
      'plantPhoto': '식물 사진',
      'plantPhotoHint': '대표 사진을 맨 앞으로 두고 순서도 직접 바꿀 수 있어요.',
      'selectPhoto': '사진 선택',
      'noRegisteredPhotos': '등록된 사진이 없습니다. 여러 장을 선택해서 대표 사진 순서까지 정리할 수 있어요.',
      'photoReorderHint': '사진을 길게 눌러 드래그하면 순서를 바꿀 수 있어요. 첫 번째 사진이 대표로 보여집니다.',
      'locationUnset': '위치 미입력',
      'saveChanges': '수정 내용 저장',
      'registerPlant': '식물 등록하기',
      'overdueRecommend': '일 지났어요. 지금 물주기를 권장합니다.',
      'todayWateringTurn': '오늘 물줄 차례입니다. 체크 후 다음 일정이 자동 계산됩니다.',
      'afterDays': '일 후',
      'nextDatePrefix': '다음',
      'healthy': '안정',
      'soon': '곧 필요',
      'todayWatering': '오늘 물주기',
      'overdue': '오래 방치',
      'healthyDesc': '루틴이 안정적이에요',
      'soonDesc': '곧 물주기 타이밍',
      'todayDesc': '오늘 챙기면 좋아요',
      'overdueDesc': '가장 먼저 확인해주세요',
      'wateringDoneToast': '물주기 완료',
      'loginSuccess': '로그인 성공',
      'loginFailed': '로그인에 실패했습니다.',
      'syncChoiceTitle': '기존 데이터가 둘 다 있어요',
      'syncChoiceBody': '이 기기에도 식물 데이터가 있고, 서버에도 저장된 데이터가 있습니다. 어떤 기준으로 맞출지 선택해주세요.',
      'syncUseServer': '서버 데이터 불러오기',
      'syncUseLocal': '현재 기기로 서버 덮어쓰기',
      'syncMerge': '둘 다 합치기',
      'syncServerSummary': '서버 저장 데이터',
      'syncDeviceSummary': '현재 기기 데이터',
      'syncChoiceServerHint': '이 기기 데이터를 서버 데이터로 교체합니다.',
      'syncChoiceLocalHint': '현재 기기 데이터를 서버에 올려 덮어씁니다.',
      'syncChoiceMergeHint': '겹치지 않는 식물은 합치고, 같은 ID는 현재 기기 데이터를 우선합니다.',
      'syncImported': '서버 데이터를 불러왔습니다.',
      'syncUploaded': '현재 기기 데이터를 서버에 저장했습니다.',
      'syncMerged': '기기와 서버 데이터를 합쳤습니다.',
      'syncFailed': '동기화 중 오류가 발생했습니다.',
      'cloudLinked': '계정 연동 및 서버 저장 사용 중',
      'logoutDone': '로그아웃 되었습니다.',
      'privacyDialogTitle': '개인정보처리방침',
      'privacyDialogBody': '식물 물주기 알리미는 식물 기록과 알림 기능 제공을 위해 최소한의 정보를 사용합니다.\n\n저장되는 주요 정보:\n- 등록한 식물 이름, 위치, 메모, 물주기 주기\n- 사용자가 직접 선택한 식물 사진\n- 알림 설정 정보\n\n광고는 Google AdMob 정책을 따르며, 자세한 내용은 Google 개인정보처리방침을 따릅니다.\n\n앱 사용 데이터와 정책 내용은 서비스 운영 과정에서 변경될 수 있으며, 중요한 변경이 있을 경우 앱 내 공지 또는 업데이트를 통해 안내됩니다.',
      'homeSubtitle': '오늘 할 일을 먼저 챙겨봐요.',
      'myPlantsSubtitle': '내 식물을 등록하고 메모와 물주기 주기를 관리하세요.',
      'calendarSubtitle': '다음 물주기 일정을 날짜 순으로 확인합니다.',
      'statsSubtitle': '식물 관리 흐름을 숫자로 빠르게 확인하세요.',
      'allPlants': '전체',
      'statusFilterGuide': '상태별로 골라보며 경고 강도를 확인할 수 있어요.',
    },
    'en': {
      'appTitle': 'Plant Reminder',
      'home': 'Home',
      'myPlants': 'My Plants',
      'calendar': 'Calendar',
      'stats': 'Stats',
      'settings': 'Settings',
      'edit': 'Edit',
      'close': 'Close',
      'account': 'Account',
      'notification': 'Notifications',
      'etc': 'More',
      'notSignedIn': 'You can use the app right away without signing in.',
      'accountNotLinked': 'No Account Linked',
      'accountHint': 'Social sign-in can be used later for Firebase notices and backup/sync.',
      'signingIn': 'Signing in...',
      'googleLogin': 'Sign in with Google',
      'appleLogin': 'Sign in with Apple',
      'googleLinked': 'Google account linked',
      'appleLinked': 'Apple account linked',
      'logout': 'Sign out',
      'useWateringNotification': 'Enable watering reminders',
      'useWateringNotificationHint': 'Send a local reminder when a registered plant reaches its next watering time.',
      'defaultNotificationTime': 'Default reminder time',
      'tapToChangeReminderTime': 'Tap to change the reminder time.',
      'firebasePush': 'Firebase notice push',
      'firebasePushHint': 'Will be connected after Firebase setup',
      'remindAdmin': 'Reminder Admin',
      'remindAdminHint': 'Admin integration planned later',
      'privacyPolicy': 'Privacy Policy',
      'comingSoon': 'Coming soon',
      'selectPlantPhotos': 'Choose Plant Photos',
      'manageAccessiblePhotos': 'Manage accessible photos',
      'openSettings': 'Open settings',
      'tryAgain': 'Try again',
      'done': 'Done',
      'manageSelectedPhotos': 'Manage selected photos',
      'reviewAccessScope': 'Review access scope',
      'photoPermissionDenied': 'Photo access was denied. Please allow photo access in settings.',
      'photoPermissionRestricted': 'Photo access is restricted on this device. Please check device settings.',
      'photoPermissionLimited': 'Only some photos are accessible. Expand access if the photo you need is missing.',
      'photoPermissionRequired': 'Photo access permission is required.',
      'noPhotosToShow': 'No photos to display.',
      'failedToLoadAlbum': 'Failed to load the album.',
      'limitedAccessBanner': 'Only some photos are currently accessible. If the photo you need is missing, adjust access from the top right.',
      'multiPhotoHint': 'You can select multiple photos. They will be used as featured and record photos for the plant.',
      'representativePhoto': 'Cover',
      'noPlantPhoto': 'No plant photos have been added.',
      'basicInfo': 'Basic Info',
      'plantType': 'Plant type',
      'location': 'Location',
      'sunlight': 'Sunlight',
      'wateringCycle': 'Watering cycle',
      'lastWateredDate': 'Last watered',
      'nextWatering': 'Next watering',
      'memo': 'Memo',
      'noMemo': 'No memo yet.',
      'markWatered': 'Watered',
      'days': 'days',
      'detailMemo': 'Details / Memo',
      'todayRoutine': 'Today\'s gardening routine',
      'todayCareRelaxed': 'A lighter day\nfor plant care',
      'todayTasks': 'Due today',
      'soonNeed': 'Coming soon',
      'healthyState': 'Healthy',
      'todayPriority': 'Today\'s priority',
      'noUrgentPlants': 'No urgent plants',
      'recommendWateringNow': 'Recommended now',
      'relaxed': 'Relaxed',
      'nextCheck': 'Next check',
      'nothingScheduled': 'Nothing scheduled',
      'comingSoonLabel': 'Coming up',
      'stable': 'Stable',
      'todayTodo': 'What to do today',
      'todayTodoHint': 'Organized so you can handle urgent plants first.',
      'noPlantForToday': 'There are no plants to handle right away today.',
      'checkSoonPlants': 'Plants to check soon',
      'checkSoonPlantsHint': 'These plants will be good to check within a day or two.',
      'noSoonPlants': 'There are no plants to water soon.',
      'myPlantsGuide': 'Tap a registered plant to edit its photo, memo, and watering cycle.',
      'calendarNoSchedule': 'No watering schedules this month.',
      'calendarBadgeHint': 'Days with watering schedules are marked with green dots and counts.',
      'statsTitle': 'Plant status at a glance',
      'noPlantsYet': 'No plants have been registered yet.',
      'statsCycleFlow': 'Watering cycle flow',
      'statsCycleFlowHint': 'See at a glance how different each plant\'s cycle is.',
      'oldestOverdueHint': 'Some plants are overdue. Start with the most urgent plants today.',
      'stableFlowHint': 'Your care flow looks stable overall. Just check the plants scheduled for today.',
      'plantInfoEdit': 'Refine Plant Info',
      'newPlantRegister': 'Add a New Plant',
      'plantInfoEditHint': 'Organize photos, notes, and the watering routine all at once.',
      'newPlantRegisterHint': 'Enter a plant name and routine lightly, then start managing it right away.',
      'noPhoto': 'No photo',
      'basicInfoHint': 'Let\'s start with the type, name, and location.',
      'searchPlantType': 'Search plant type',
      'searchPlantTypeHint': 'Type a plant name to select it instantly',
      'myPlantName': 'My plant name',
      'myPlantNameExample': 'e.g. Living room Monstera',
      'locationExample': 'e.g. Living room window',
      'careRoutine': 'Care routine',
      'careRoutineHint': 'Record the watering interval and the last watered date neatly.',
      'enterNumbersOnly': 'Numbers only',
      'memoHintTitle': 'Leave any condition notes or care points you want to remember.',
      'memoExample': 'e.g. New leaf coming in, avoid overwatering',
      'plantPhoto': 'Plant photos',
      'plantPhotoHint': 'Put the cover photo first and reorder them yourself.',
      'selectPhoto': 'Choose photos',
      'noRegisteredPhotos': 'No photos have been added yet. Select several photos and organize the cover order too.',
      'photoReorderHint': 'Long press and drag to change the order. The first photo is shown as the cover.',
      'locationUnset': 'No location entered',
      'saveChanges': 'Save changes',
      'registerPlant': 'Add plant',
      'overdueRecommend': 'days overdue. Watering is recommended now.',
      'todayWateringTurn': 'It is scheduled for watering today. Check it and the next schedule will update automatically.',
      'afterDays': 'days left',
      'nextDatePrefix': 'Next',
      'healthy': 'Healthy',
      'soon': 'Soon',
      'todayWatering': 'Today',
      'overdue': 'Overdue',
      'healthyDesc': 'Your routine looks stable',
      'soonDesc': 'Watering time is coming up',
      'todayDesc': 'Good to handle today',
      'overdueDesc': 'Please check this first',
      'wateringDoneToast': 'watering completed',
      'loginSuccess': 'login successful',
      'loginFailed': 'Login failed.',
      'syncChoiceTitle': 'Data exists in both places',
      'syncChoiceBody': 'This device already has plant data, and the server also has saved data. Choose how you want to resolve it.',
      'syncUseServer': 'Load server data',
      'syncUseLocal': 'Overwrite server with this device',
      'syncMerge': 'Merge both',
      'syncServerSummary': 'Server data',
      'syncDeviceSummary': 'This device',
      'syncChoiceServerHint': 'Replace this device with the server data.',
      'syncChoiceLocalHint': 'Upload this device data and overwrite the server.',
      'syncChoiceMergeHint': 'Combine non-duplicate plants and prefer this device when IDs overlap.',
      'syncImported': 'Loaded server data.',
      'syncUploaded': 'Uploaded this device data to the server.',
      'syncMerged': 'Merged device and server data.',
      'syncFailed': 'An error occurred during sync.',
      'cloudLinked': 'Account linked and cloud save enabled',
      'logoutDone': 'Signed out.',
      'privacyDialogTitle': 'Privacy Policy',
      'privacyDialogBody': 'Plant Reminder uses only the minimum information needed to provide plant records and reminder features.\n\nMain data used:\n- Registered plant names, locations, notes, and watering cycles\n- Plant photos selected by the user\n- Reminder settings\n\nAds follow Google AdMob policies, and related details follow Google\'s Privacy Policy.\n\nService data and policy details may change during operation. Important changes will be announced through in-app notices or updates.',
      'homeSubtitle': 'Check what needs attention first today.',
      'myPlantsSubtitle': 'Register your plants and manage notes and watering cycles.',
      'calendarSubtitle': 'Check upcoming watering schedules by date.',
      'statsSubtitle': 'See your plant care flow in numbers.',
      'allPlants': 'All',
      'statusFilterGuide': 'Filter by status to compare each warning level.',
    },
    'ja': {
      'appTitle': '植物みずやりリマインダー',
      'home': 'ホーム',
      'myPlants': 'マイ植物',
      'calendar': 'カレンダー',
      'stats': '統計',
      'settings': '設定',
      'edit': '編集',
      'close': '閉じる',
      'account': 'アカウント',
      'notification': '通知',
      'etc': 'その他',
      'notSignedIn': 'ログインしなくてもすぐに使えます。',
      'accountNotLinked': 'アカウント未連携',
      'accountHint': '後で Firebase 通知やバックアップ・同期のためにソーシャル連携を利用できます。',
      'signingIn': 'ログイン中...',
      'googleLogin': 'Googleでログイン',
      'appleLogin': 'Appleでログイン',
      'googleLinked': 'Googleアカウント連携済み',
      'appleLinked': 'Appleアカウント連携済み',
      'logout': 'ログアウト',
      'useWateringNotification': '水やり通知を使用',
      'useWateringNotificationHint': '登録した植物の次の水やり時間にローカル通知を送ります。',
      'defaultNotificationTime': '基本通知時間',
      'tapToChangeReminderTime': 'タップして通知時間を変更できます。',
      'firebasePush': 'Firebase お知らせプッシュ',
      'firebasePushHint': 'Firebase設定後に連携予定',
      'remindAdmin': 'リマインド管理',
      'remindAdminHint': '後で管理画面連携予定',
      'privacyPolicy': 'プライバシーポリシー',
      'comingSoon': '今後対応予定',
      'selectPlantPhotos': '植物写真を選択',
      'manageAccessiblePhotos': 'アクセス写真を管理',
      'openSettings': '設定を開く',
      'tryAgain': '再試行',
      'done': '完了',
      'manageSelectedPhotos': '選択した写真を管理',
      'reviewAccessScope': 'アクセス範囲を再確認',
      'photoPermissionDenied': '写真アクセスが拒否されました。設定で写真権限を許可してください。',
      'photoPermissionRestricted': 'この端末では写真アクセスが制限されています。端末設定を確認してください。',
      'photoPermissionLimited': '一部の写真のみにアクセスできます。必要な写真が見えない場合はアクセス範囲を広げてください。',
      'photoPermissionRequired': '写真アクセス権限が必要です。',
      'noPhotosToShow': '表示する写真がありません。',
      'failedToLoadAlbum': 'アルバムを読み込めませんでした。',
      'limitedAccessBanner': '現在は一部の写真のみアクセス可能です。必要な写真がない場合は右上からアクセス範囲を調整してください。',
      'multiPhotoHint': '複数枚選択できます。植物の代表写真や記録写真として使われます。',
      'representativePhoto': '代表写真',
      'noPlantPhoto': '登録された植物写真がありません。',
      'basicInfo': '基本情報',
      'plantType': '植物の種類',
      'location': '場所',
      'sunlight': '日当たり',
      'wateringCycle': '水やり周期',
      'lastWateredDate': '最後に水をあげた日',
      'nextWatering': '次の水やり',
      'memo': 'メモ',
      'noMemo': 'メモはありません。',
      'markWatered': '水やり完了',
      'days': '日',
      'detailMemo': '詳細 / メモ',
      'homeSubtitle': '今日やることを先に確認しましょう。',
      'myPlantsSubtitle': '植物を登録してメモと水やり周期を管理しましょう。',
      'calendarSubtitle': '次の水やり予定を日付順に確認できます。',
      'statsSubtitle': '植物管理の流れを数字ですばやく確認できます。',
      'allPlants': 'すべて',
      'statusFilterGuide': '状態ごとに見比べながら警告の強さを確認できます。',
      'syncChoiceTitle': '両方にデータがあります',
      'syncChoiceBody': 'この端末にも植物データがあり、サーバーにも保存済みデータがあります。どの基準で合わせるか選んでください。',
      'syncUseServer': 'サーバーデータを読み込む',
      'syncUseLocal': 'この端末でサーバーを上書き',
      'syncMerge': '両方を統合',
      'syncServerSummary': 'サーバー保存データ',
      'syncDeviceSummary': 'この端末のデータ',
      'syncChoiceServerHint': 'この端末の内容をサーバーデータで置き換えます。',
      'syncChoiceLocalHint': 'この端末の内容をサーバーにアップロードして上書きします。',
      'syncChoiceMergeHint': '重複しない植物は統合し、同じIDはこの端末データを優先します。',
      'syncImported': 'サーバーデータを読み込みました。',
      'syncUploaded': 'この端末データをサーバーに保存しました。',
      'syncMerged': '端末とサーバーのデータを統合しました。',
      'syncFailed': '同期中にエラーが発生しました。',
      'cloudLinked': 'アカウント連携とクラウド保存を使用中',
      'privacyDialogTitle': 'プライバシーポリシー',
      'privacyDialogBody': '植物みずやりリマインダーは、植物記録と通知機能を提供するために必要最小限の情報のみを使用します。\n\n主に保存される情報:\n- 登録した植物名、場所、メモ、水やり周期\n- ユーザーが選択した植物写真\n- 通知設定情報\n\n広告は Google AdMob のポリシーに従い、詳細は Google のプライバシーポリシーに準拠します。\n\nサービス運営中にデータ利用やポリシー内容が変更される場合があり、重要な変更はアプリ内通知やアップデートで案内されます。',
    },
    'zh': {
      'appTitle': '植物浇水提醒',
      'home': '首页',
      'myPlants': '我的植物',
      'calendar': '日历',
      'stats': '统计',
      'settings': '设置',
      'edit': '编辑',
      'close': '关闭',
      'account': '账号',
      'notification': '通知',
      'etc': '其他',
      'notSignedIn': '即使不登录也可以立即使用。',
      'accountNotLinked': '未绑定账号',
      'accountHint': '以后可通过社交登录连接 Firebase 通知以及备份/同步。',
      'signingIn': '登录中...',
      'googleLogin': 'Google 登录',
      'appleLogin': 'Apple 登录',
      'googleLinked': '已绑定 Google 账号',
      'appleLinked': '已绑定 Apple 账号',
      'logout': '退出登录',
      'useWateringNotification': '启用浇水提醒',
      'useWateringNotificationHint': '当已登记植物到达下次浇水时间时发送本地通知。',
      'defaultNotificationTime': '默认提醒时间',
      'tapToChangeReminderTime': '点击即可修改提醒时间。',
      'firebasePush': 'Firebase 公告推送',
      'firebasePushHint': '完成 Firebase 设置后连接',
      'remindAdmin': '提醒管理后台',
      'remindAdminHint': '后续将接入后台',
      'privacyPolicy': '隐私政策',
      'comingSoon': '后续提供',
      'selectPlantPhotos': '选择植物照片',
      'manageAccessiblePhotos': '管理可访问照片',
      'openSettings': '打开设置',
      'tryAgain': '重试',
      'done': '完成',
      'manageSelectedPhotos': '管理已选照片',
      'reviewAccessScope': '重新检查访问范围',
      'photoPermissionDenied': '照片访问权限被拒绝。请在设置中允许照片权限。',
      'photoPermissionRestricted': '此设备上的照片访问受限。请检查设备设置。',
      'photoPermissionLimited': '当前只能访问部分照片。如果看不到需要的照片，请扩大访问范围。',
      'photoPermissionRequired': '需要照片访问权限。',
      'noPhotosToShow': '没有可显示的照片。',
      'failedToLoadAlbum': '无法加载相册。',
      'limitedAccessBanner': '当前仅能访问部分照片。如果没有需要的照片，请在右上角调整访问范围。',
      'multiPhotoHint': '可以选择多张照片，将用作植物封面图和记录图。',
      'representativePhoto': '封面照片',
      'noPlantPhoto': '没有已登记的植物照片。',
      'basicInfo': '基本信息',
      'plantType': '植物种类',
      'location': '位置',
      'sunlight': '光照建议',
      'wateringCycle': '浇水周期',
      'lastWateredDate': '上次浇水日期',
      'nextWatering': '下次浇水',
      'memo': '备注',
      'noMemo': '暂无备注。',
      'markWatered': '已浇水',
      'days': '天',
      'detailMemo': '详情 / 备注',
      'homeSubtitle': '先查看今天需要处理的事项。',
      'myPlantsSubtitle': '登记植物并管理备注与浇水周期。',
      'calendarSubtitle': '按日期查看即将到来的浇水安排。',
      'statsSubtitle': '用数字快速查看植物护理情况。',
      'allPlants': '全部',
      'statusFilterGuide': '可以按状态筛选，快速比较提醒强度。',
      'syncChoiceTitle': '两边都有数据',
      'syncChoiceBody': '当前设备已有植物数据，服务器中也有已保存的数据。请选择如何处理。',
      'syncUseServer': '加载服务器数据',
      'syncUseLocal': '用当前设备覆盖服务器',
      'syncMerge': '合并两边数据',
      'syncServerSummary': '服务器数据',
      'syncDeviceSummary': '当前设备数据',
      'syncChoiceServerHint': '使用服务器数据替换当前设备内容。',
      'syncChoiceLocalHint': '将当前设备数据上传并覆盖服务器。',
      'syncChoiceMergeHint': '合并不重复的植物，相同ID时优先当前设备。',
      'syncImported': '已加载服务器数据。',
      'syncUploaded': '已将当前设备数据上传到服务器。',
      'syncMerged': '已合并设备与服务器数据。',
      'syncFailed': '同步时发生错误。',
      'cloudLinked': '已启用账号关联与云端保存',
      'privacyDialogTitle': '隐私政策',
      'privacyDialogBody': '植物浇水提醒仅使用提供植物记录和提醒功能所需的最少信息。\n\n主要保存的信息：\n- 已登记植物的名称、位置、备注和浇水周期\n- 用户自行选择的植物照片\n- 提醒设置\n\n广告遵循 Google AdMob 政策，相关内容适用 Google 隐私政策。\n\n在服务运营过程中，数据使用方式和政策内容可能会变更。若有重要变更，将通过应用内公告或更新进行说明。',
    },
  };

  String get appTitle => _text('appTitle');
  String get home => _text('home');
  String get myPlants => _text('myPlants');
  String get calendar => _text('calendar');
  String get stats => _text('stats');
  String get settings => _text('settings');
  String get edit => _text('edit');
  String get close => _text('close');
  String get account => _text('account');
  String get notification => _text('notification');
  String get etc => _text('etc');
  String get notSignedIn => _text('notSignedIn');
  String get accountNotLinked => _text('accountNotLinked');
  String get accountHint => _text('accountHint');
  String get signingIn => _text('signingIn');
  String get googleLogin => _text('googleLogin');
  String get appleLogin => _text('appleLogin');
  String get googleLinked => _text('googleLinked');
  String get appleLinked => _text('appleLinked');
  String get logout => _text('logout');
  String get useWateringNotification => _text('useWateringNotification');
  String get useWateringNotificationHint => _text('useWateringNotificationHint');
  String get defaultNotificationTime => _text('defaultNotificationTime');
  String get tapToChangeReminderTime => _text('tapToChangeReminderTime');
  String get firebasePush => _text('firebasePush');
  String get firebasePushHint => _text('firebasePushHint');
  String get remindAdmin => _text('remindAdmin');
  String get remindAdminHint => _text('remindAdminHint');
  String get privacyPolicy => _text('privacyPolicy');
  String get comingSoon => _text('comingSoon');
  String get selectPlantPhotos => _text('selectPlantPhotos');
  String get manageAccessiblePhotos => _text('manageAccessiblePhotos');
  String get openSettings => _text('openSettings');
  String get tryAgain => _text('tryAgain');
  String get done => _text('done');
  String get manageSelectedPhotos => _text('manageSelectedPhotos');
  String get reviewAccessScope => _text('reviewAccessScope');
  String get photoPermissionDenied => _text('photoPermissionDenied');
  String get photoPermissionRestricted => _text('photoPermissionRestricted');
  String get photoPermissionLimited => _text('photoPermissionLimited');
  String get photoPermissionRequired => _text('photoPermissionRequired');
  String get noPhotosToShow => _text('noPhotosToShow');
  String get failedToLoadAlbum => _text('failedToLoadAlbum');
  String get limitedAccessBanner => _text('limitedAccessBanner');
  String get multiPhotoHint => _text('multiPhotoHint');
  String get representativePhoto => _text('representativePhoto');
  String get noPlantPhoto => _text('noPlantPhoto');
  String get basicInfo => _text('basicInfo');
  String get plantType => _text('plantType');
  String get location => _text('location');
  String get sunlight => _text('sunlight');
  String get wateringCycle => _text('wateringCycle');
  String get lastWateredDate => _text('lastWateredDate');
  String get nextWatering => _text('nextWatering');
  String get memo => _text('memo');
  String get noMemo => _text('noMemo');
  String get markWatered => _text('markWatered');
  String get days => _text('days');
  String get detailMemo => _text('detailMemo');
  String get homeSubtitle => _text('homeSubtitle');
  String get myPlantsSubtitle => _text('myPlantsSubtitle');
  String get calendarSubtitle => _text('calendarSubtitle');
  String get statsSubtitle => _text('statsSubtitle');
  String get allPlants => _text('allPlants');
  String get statusFilterGuide => _text('statusFilterGuide');
  String get todayRoutine => _text('todayRoutine');
  String get todayCareRelaxed => _text('todayCareRelaxed');
  String get todayTasks => _text('todayTasks');
  String get soonNeed => _text('soonNeed');
  String get healthyState => _text('healthyState');
  String get todayPriority => _text('todayPriority');
  String get noUrgentPlants => _text('noUrgentPlants');
  String get recommendWateringNow => _text('recommendWateringNow');
  String get relaxed => _text('relaxed');
  String get nextCheck => _text('nextCheck');
  String get nothingScheduled => _text('nothingScheduled');
  String get comingSoonLabel => _text('comingSoonLabel');
  String get stable => _text('stable');
  String get todayTodo => _text('todayTodo');
  String get todayTodoHint => _text('todayTodoHint');
  String get noPlantForToday => _text('noPlantForToday');
  String get checkSoonPlants => _text('checkSoonPlants');
  String get checkSoonPlantsHint => _text('checkSoonPlantsHint');
  String get noSoonPlants => _text('noSoonPlants');
  String get myPlantsGuide => _text('myPlantsGuide');
  String get calendarNoSchedule => _text('calendarNoSchedule');
  String get calendarBadgeHint => _text('calendarBadgeHint');
  String get statsTitle => _text('statsTitle');
  String get noPlantsYet => _text('noPlantsYet');
  String get statsCycleFlow => _text('statsCycleFlow');
  String get statsCycleFlowHint => _text('statsCycleFlowHint');
  String get oldestOverdueHint => _text('oldestOverdueHint');
  String get stableFlowHint => _text('stableFlowHint');
  String get plantInfoEdit => _text('plantInfoEdit');
  String get newPlantRegister => _text('newPlantRegister');
  String get plantInfoEditHint => _text('plantInfoEditHint');
  String get newPlantRegisterHint => _text('newPlantRegisterHint');
  String get noPhoto => _text('noPhoto');
  String get basicInfoHint => _text('basicInfoHint');
  String get searchPlantType => _text('searchPlantType');
  String get searchPlantTypeHint => _text('searchPlantTypeHint');
  String get myPlantName => _text('myPlantName');
  String get myPlantNameExample => _text('myPlantNameExample');
  String get locationExample => _text('locationExample');
  String get careRoutine => _text('careRoutine');
  String get careRoutineHint => _text('careRoutineHint');
  String get enterNumbersOnly => _text('enterNumbersOnly');
  String get memoHintTitle => _text('memoHintTitle');
  String get memoExample => _text('memoExample');
  String get plantPhoto => _text('plantPhoto');
  String get plantPhotoHint => _text('plantPhotoHint');
  String get selectPhoto => _text('selectPhoto');
  String get noRegisteredPhotos => _text('noRegisteredPhotos');
  String get photoReorderHint => _text('photoReorderHint');
  String get locationUnset => _text('locationUnset');
  String get saveChanges => _text('saveChanges');
  String get registerPlant => _text('registerPlant');
  String get todayWateringTurn => _text('todayWateringTurn');
  String get nextDatePrefix => _text('nextDatePrefix');
  String get healthy => _text('healthy');
  String get soon => _text('soon');
  String get todayWatering => _text('todayWatering');
  String get overdue => _text('overdue');
  String get healthyDesc => _text('healthyDesc');
  String get soonDesc => _text('soonDesc');
  String get todayDesc => _text('todayDesc');
  String get overdueDesc => _text('overdueDesc');
  String get wateringDoneToast => _text('wateringDoneToast');
  String get loginSuccess => _text('loginSuccess');
  String get loginFailed => _text('loginFailed');
  String get logoutDone => _text('logoutDone');
  String get syncChoiceTitle => _text('syncChoiceTitle');
  String get syncChoiceBody => _text('syncChoiceBody');
  String get syncUseServer => _text('syncUseServer');
  String get syncUseLocal => _text('syncUseLocal');
  String get syncMerge => _text('syncMerge');
  String get syncServerSummary => _text('syncServerSummary');
  String get syncDeviceSummary => _text('syncDeviceSummary');
  String get syncChoiceServerHint => _text('syncChoiceServerHint');
  String get syncChoiceLocalHint => _text('syncChoiceLocalHint');
  String get syncChoiceMergeHint => _text('syncChoiceMergeHint');
  String get syncImported => _text('syncImported');
  String get syncUploaded => _text('syncUploaded');
  String get syncMerged => _text('syncMerged');
  String get syncFailed => _text('syncFailed');
  String get cloudLinked => _text('cloudLinked');
  String get privacyDialogTitle => _text('privacyDialogTitle');
  String get privacyDialogBody => _text('privacyDialogBody');

  String plantCount(int count) => _code == 'ko' ? '식물 $count개' : _code == 'ja' ? '植物 $count件' : _code == 'zh' ? '植物 $count 个' : '$count plants';
  String todayPlantsHeadline(int count) => _code == 'ko' ? '오늘 바로 확인할\n식물이 $count개 있어요' : _code == 'ja' ? '今日すぐ確認したい\n植物が$count件あります' : _code == 'zh' ? '今天需要立刻查看的\n植物有 $count 个' : 'There are\n$count plants to check today';
  String highlightValueCount(int count) => _code == 'ko' ? '$count개' : _code == 'ja' ? '$count件' : _code == 'zh' ? '$count 个' : '$count';
  String priorityValue(int count) => _code == 'ko' ? '$count개 우선' : _code == 'ja' ? '$count件優先' : _code == 'zh' ? '$count 个优先' : '$count priority';
  String scheduledValue(int count) => _code == 'ko' ? '$count개 예정' : _code == 'ja' ? '$count件予定' : _code == 'zh' ? '$count 个待办' : '$count scheduled';
  String todayTaskStreak(bool hasTodayTasks) => hasTodayTasks
      ? (_code == 'ko' ? '지금 챙기면 식물 컨디션을 더 예쁘게 유지할 수 있어요.' : _code == 'ja' ? '今チェックすれば植物のコンディションをもっときれいに保てます。' : _code == 'zh' ? '现在处理的话，更容易让植物保持好状态。' : 'If you handle them now, it will be easier to keep your plants in great condition.')
      : (_code == 'ko' ? '오늘은 한결 여유로운 날이에요.' : _code == 'ja' ? '今日は少し余裕のある日です。' : _code == 'zh' ? '今天是相对轻松的一天。' : 'Today looks a little more relaxed.');
  String pageLabelManageMonth(DateTime date) => _code == 'ko' ? '${monthLabel(date)} 관리 예정' : _code == 'ja' ? '${monthLabel(date)}の管理予定' : _code == 'zh' ? '${monthLabel(date)} 管理计划' : '${monthLabel(date)} schedule';
  String monthCalendarTitle(DateTime date) => _code == 'ko' ? '${monthLabel(date)} 캘린더' : _code == 'ja' ? '${monthLabel(date)} カレンダー' : _code == 'zh' ? '${monthLabel(date)} 日历' : '${monthLabel(date)} calendar';
  String registeredPlantsCount(int count) => _code == 'ko' ? '$count개' : _code == 'ja' ? '$count件' : _code == 'zh' ? '$count 个' : '$count';
  String averageCycle(int days) => days == 0 ? '-' : (_code == 'ko' ? '$days일' : _code == 'ja' ? '$days日' : _code == 'zh' ? '$days 天' : '$days d');
  String overallStatsHint(String strongestName) => _code == 'ko' ? '$strongestName부터 루틴을 챙기면 오늘 관리가 훨씬 쉬워져요.' : _code == 'ja' ? '$strongestName から先にチェックすると今日の管理が楽になります。' : _code == 'zh' ? '先从 $strongestName 开始，会让今天的管理更轻松。' : 'Start with $strongestName and today\'s routine will feel much easier.';
  String totalPlantsMetric(int count) => _code == 'ko' ? '$count개' : _code == 'ja' ? '$count件' : _code == 'zh' ? '$count 个' : '$count';
  String healthyKeep(int count) => _code == 'ko' ? '$count개' : _code == 'ja' ? '$count件' : _code == 'zh' ? '$count 个' : '$count';
  String dueTodayCount(int count) => _code == 'ko' ? '$count개' : _code == 'ja' ? '$count件' : _code == 'zh' ? '$count 个' : '$count';
  String overdueCount(int count) => _code == 'ko' ? '$count개' : _code == 'ja' ? '$count件' : _code == 'zh' ? '$count 个' : '$count';
  String cycleDays(int days) => _code == 'ko' ? '$days일' : _code == 'ja' ? '$days日' : _code == 'zh' ? '$days 天' : '$days d';
  String cycleDaysLabel(int days) => _code == 'ko' ? '$days일 주기' : _code == 'ja' ? '$days日周期' : _code == 'zh' ? '$days 天周期' : 'Every $days d';
  String defaultCycleDaysLabel(int days) => _code == 'ko' ? '$days일 기본 주기' : _code == 'ja' ? '$days日基本周期' : _code == 'zh' ? '$days 天默认周期' : '$days d default';
  String selectedPhotoCount(int count) => _code == 'ko' ? '$count장 선택' : _code == 'ja' ? '$count枚選択' : _code == 'zh' ? '已选 $count 张' : '$count selected';
  String wateredToast(String plantName) => _code == 'ko' ? '$plantName 물주기 완료' : _code == 'ja' ? '$plantName の水やり完了' : _code == 'zh' ? '$plantName 浇水完成' : '$plantName watering completed';
  String loginSuccessToast(String provider) => _code == 'ko' ? '$provider $loginSuccess' : _code == 'ja' ? '$provider $loginSuccess' : _code == 'zh' ? '$provider$loginSuccess' : '$provider $loginSuccess';
  String noLocationEnteredFallback() => locationUnset;
  String nextDateLabel(DateTime date) => _code == 'ko' ? '다음 ${dateLabel(date)}' : _code == 'ja' ? '次回 ${dateLabel(date)}' : _code == 'zh' ? '下次 ${dateLabel(date)}' : 'Next ${dateLabel(date)}';
  String overdueRecommendation(int absDays) => _code == 'ko' ? '$absDays일 지났어요. 지금 물주기를 권장합니다.' : _code == 'ja' ? '$absDays日過ぎています。今の水やりをおすすめします。' : _code == 'zh' ? '已经过了 $absDays 天，建议现在浇水。' : '$absDays days overdue. Watering is recommended now.';
  String afterDaysLabel(int days, String location) => _code == 'ko' ? '$days일 후 · $location' : _code == 'ja' ? '$days日後 · $location' : _code == 'zh' ? '$days 天后 · $location' : 'In $days d · $location';
  String photoIndexLabel(int current, int total) => _code == 'ko' ? '사진 $current/$total' : _code == 'ja' ? '写真 $current/$total' : _code == 'zh' ? '照片 $current/$total' : 'Photo $current/$total';
  String reminderTitle(String plantName) => _code == 'ko' ? '$plantName 물줄 시간' : _code == 'ja' ? '$plantName の水やり時間' : _code == 'zh' ? '$plantName 的浇水时间' : 'Time to water $plantName';
  String reminderBody(String plantType) => _code == 'ko' ? '$plantType 물주기 확인이 필요해요.' : _code == 'ja' ? '$plantType の水やり確認が必要です。' : _code == 'zh' ? '$plantType 需要检查是否该浇水了。' : '$plantType needs a watering check.';
  String reminderChannelDescription() => _code == 'ko' ? '식물 물주기 알림 채널' : _code == 'ja' ? '植物水やり通知チャンネル' : _code == 'zh' ? '植物浇水提醒频道' : 'Plant watering reminder channel';
  String monthLabel(DateTime date) => _code == 'ko' ? '${date.year}년 ${date.month}월' : _code == 'ja' ? '${date.year}年${date.month}月' : _code == 'zh' ? '${date.year}年${date.month}月' : '${_englishMonths[date.month - 1]} ${date.year}';
  String dateLabel(DateTime date) => _code == 'ko' || _code == 'ja' || _code == 'zh'
      ? '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}'
      : '${_englishMonths[date.month - 1]} ${date.day}, ${date.year}';
  String weekdayShort(int weekday) {
    const ko = ['월', '화', '수', '목', '금', '토', '일'];
    const en = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    const ja = ['月', '火', '水', '木', '金', '土', '日'];
    const zh = ['一', '二', '三', '四', '五', '六', '日'];
    final labels = _code == 'ko' ? ko : _code == 'ja' ? ja : _code == 'zh' ? zh : en;
    return labels[weekday - 1];
  }

  static const _englishMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) => ['ko', 'en', 'zh', 'ja'].contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) async => AppLocalizations.forLocale(locale);

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) => false;
}

extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);
}
