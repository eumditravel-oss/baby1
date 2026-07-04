import 'package:flutter/material.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'screens/main_navigation.dart';

import 'services/subscription_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SubscriptionService().init();
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.babystory.channel.audio',
      androidNotificationChannelName: 'Audio playback',
      androidNotificationOngoing: true,
    );
  } catch (e) {
    debugPrint('JustAudioBackground init failed: $e');
  }
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dream Factory',
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFE2B714),
        scaffoldBackgroundColor: const Color(0xFF1A1A2E),
        fontFamily: 'Pretendard',
      ),
      home: const MainNavigation(),
    );
  }
}
