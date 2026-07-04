import 'package:flutter/material.dart';
import 'home_screen.dart'; // 마법의 책 기능
import 'library_screen.dart'; // 동화 서재
import 'radio_screen.dart'; // 이야기 라디오
import 'parent_voice_screen.dart'; // 우리집 목소리
import 'settings_screen.dart'; // 설정

class MainNavigation extends StatefulWidget {
  const MainNavigation({Key? key}) : super(key: key);

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = [
    const LibraryScreen(), // 탭 1: 동화 서재
    const RadioScreen(), // 탭 2: 이야기 라디오
    const ParentVoiceScreen(), // 탭 3: 우리집 목소리
    const HomeScreen(), // 탭 4: 마법의 책
    const SettingsScreen(), // 탭 5: 설정
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      body: IndexedStack(
        index: _currentIndex,
        children: _pages,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
        ),
        child: BottomNavigationBar(
          backgroundColor: const Color(0xFF1A1A2E),
          selectedItemColor: const Color(0xFFE2B714),
          unselectedItemColor: Colors.white54,
          currentIndex: _currentIndex,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.library_books),
              label: '동화 서재',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.radio),
              label: '이야기 라디오',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.record_voice_over),
              label: '우리집 목소리',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome),
              label: '마법의 책',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.settings),
              label: '설정',
            ),
          ],
        ),
      ),
    );
  }
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({Key? key, required this.title}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A2E),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'serif')),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
      ),
      body: Center(
        child: Text(
          '$title 준비 중입니다.',
          style: const TextStyle(color: Colors.white54, fontSize: 16),
        ),
      ),
    );
  }
}
