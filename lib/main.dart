import 'package:flutter/material.dart';

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
      home: const PlantHomePage(),
    );
  }
}

class PlantHomePage extends StatelessWidget {
  const PlantHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('식물 물주기 알리미'),
        centerTitle: false,
        backgroundColor: const Color(0xFFF6FBF7),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.primary,
              borderRadius: BorderRadius.circular(24),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '식집사 루틴',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '오늘 관리할 식물을 빠르게 확인하세요',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  '초보 식집사를 위한 물주기 리마인더 앱의 초기 세팅이 완료되었습니다.',
                  style: TextStyle(color: Colors.white70, height: 1.4),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          _SectionCard(
            title: '초기 포함 예정 화면',
            children: const [
              '• 홈 / 오늘 해야 할 일',
              '• 나의 식물 목록',
              '• 식물 상세 / 메모',
              '• 달력',
              '• 통계 차트',
              '• 설정',
            ],
          ),
          const SizedBox(height: 16),
          _SectionCard(
            title: '운영 기능',
            children: const [
              '• 광고 어드민',
              '• 리마인드 어드민',
              '• 식물 프리셋 관리',
              '• Firebase 푸시 공지',
            ],
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () {},
            icon: const Icon(Icons.local_florist_rounded),
            label: const Text('식물 추가 화면은 다음 단계에서 구현'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<String> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: Color(0x11000000),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ...children.map(
            (line) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(line, style: const TextStyle(height: 1.4)),
            ),
          ),
        ],
      ),
    );
  }
}
