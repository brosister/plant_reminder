# plant_reminder

Plant reminder app designed for beginner plant owners who want a simple watering routine.

## App identity
- Korean app name: 식물 물주기 알리미
- English app name: Plant Water Reminder
- Brand/support concept: 식집사 루틴
- Android package: `com.brosister.plantreminder`
- iOS bundle identifier: `com.brosister.plantreminder`

## Product direction
- beginner-friendly plant care reminder app
- focuses on helping users avoid missing watering schedules
- designed around "today's tasks" rather than complex plant encyclopedia flows

## Planned user features
- my plants registration
- plant type presets
- plant-level memo
- watering reminder schedule
- calendar view
- chart/statistics page
- local notifications
- Firebase push announcements

## Planned admin / backend features
- reminder admin similar to babynote admin structure
- plant preset management
- push announcement sending
- ad settings management
- Firebase messaging integration

## Initial setup notes
- Android release signing template is already applied in `android/app/build.gradle.kts`
- `android/key.properties` / `android/upload-keystore.jks` are ignored
- starter Flutter project with Android + iOS is created
- placeholder home screen is replaced with plant reminder themed screen

## Run
```bash
flutter pub get
flutter run
```

---

## Google Play ASO (KO)
- 앱이름: 식물 물주기 알리미
- 간단설명: 초보 식집사를 위한 물주기 관리 앱, 오늘 물줘야 할 식물을 빠르게 확인
- 자세한설명: 식물 물주기 알리미는 초보 식집사가 식물을 더 쉽게 관리할 수 있도록 도와주는 물주기 리마인더 앱입니다. 오늘 물을 줘야 하는 식물, 곧 관리가 필요한 식물, 오래 방치된 식물을 한눈에 확인할 수 있도록 구성할 예정입니다. 나의 식물 등록, 식물별 메모, 달력, 통계, 푸시 공지 기능까지 포함해 단순 알림을 넘어서 식물 관리 루틴을 만들 수 있는 구조를 목표로 합니다.
- 카테고리: 라이프스타일

## Google Play ASO (EN)
- App Name: Plant Water Reminder
- Short Description: A simple watering reminder app for beginner plant owners.
- Full Description: Plant Water Reminder is a beginner-friendly plant care app focused on simple watering routines. It is designed to help users quickly understand which plants need attention today, which ones are coming up soon, and which ones may have been neglected too long. The app is planned with my plants registration, plant-level memos, calendar, simple statistics, and push announcements so users can build a repeatable plant care habit without dealing with an overly complex interface.
- Category: Lifestyle

## Apple App Store ASO (KO)
- 앱이름: 식물 물주기 알리미
- 부제: 초보 식집사 물주기 루틴
- 프로모션 텍스트: 오늘 물줘야 할 식물을 빠르게 확인하고 식물별 메모, 달력, 통계로 식집사 루틴을 만들어보세요.
- 설명: 식물 물주기 알리미는 초보 식집사가 식물을 더 쉽게 돌볼 수 있도록 돕는 실용적인 관리 앱입니다. 나의 식물을 등록하고, 물주기 일정과 메모를 관리하며, 달력과 통계로 식물 관리 흐름을 확인할 수 있도록 구성할 예정입니다. 복잡한 식물 백과보다 오늘 해야 할 관리와 놓치기 쉬운 루틴에 집중하는 방향으로 설계합니다.
- 키워드: 식물알리미,물주기,식집사,반려식물,화분관리,식물관리,식물앱,물주기알림,초보식집사,달력
- 카테고리: 라이프스타일

## Apple App Store ASO (EN)
- App Name: Plant Water Reminder
- Subtitle: Plant care routine for beginners
- Promotional Text: Track your plants, watering schedule, memos, calendar, and simple stats in one lightweight routine app.
- Description: Plant Water Reminder is being set up as a simple plant care routine app for beginner plant owners. It focuses on practical daily reminders, my plants registration, plant-level notes, calendar tracking, simple statistics, and push announcements rather than trying to be a heavy expert encyclopedia. The goal is to help users build a repeatable habit that keeps their plants from being forgotten.
- Keywords: plant reminder,watering reminder,plant care,houseplant,watering schedule,plant tracker,plant notes,calendar,beginner plants,routine
- Category: Lifestyle
