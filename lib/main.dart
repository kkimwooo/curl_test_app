import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:window_manager/window_manager.dart';
import 'providers/history_notifier.dart';
import 'views/home_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 윈도우 매니저 초기화 (macOS 최적화)
  await windowManager.ensureInitialized();
  
  const WindowOptions windowOptions = WindowOptions(
    size: Size(1200, 800),
    minimumSize: Size(1000, 700),
    center: true,
    backgroundColor: Colors.transparent,
    skipTaskbar: false,
    title: "Leviathan API Tester",
    titleBarStyle: TitleBarStyle.normal,
  );
  
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });

  runApp(
    const ProviderScope(
      child: MyApp(),
    ),
  );
}

class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // DB 비동기 초기화 상태 감시
    final dbInitAsync = ref.watch(dbInitProvider);

    return MaterialApp(
      title: 'Leviathan API Tester',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.dark, // API 테스팅 툴에 어울리는 Sleek Dark Mode 기본 적용
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFF6200EE),
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFBB86FC),
          secondary: Color(0xFF03DAC6),
          surface: Color(0xFF1E1E1E),
          background: Color(0xFF121212),
          error: Color(0xFFCF6679),
        ),
        cardColor: const Color(0xFF1E1E1E),
        dividerColor: Colors.grey[800],
        textTheme: const TextTheme(
          bodyMedium: TextStyle(fontFamily: 'SF Pro Display', color: Colors.white),
          titleMedium: TextStyle(fontFamily: 'SF Pro Display', fontWeight: FontWeight.bold),
        ),
        tabBarTheme: TabBarThemeData(
          labelColor: const Color(0xFFBB86FC),
          unselectedLabelColor: Colors.grey[500],
          indicatorColor: const Color(0xFFBB86FC),
        ),
      ),
      home: dbInitAsync.when(
        data: (_) => const HomePage(),
        loading: () => const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, stack) => Scaffold(
          body: Center(
            child: Text('DB 초기화 에러: $err'),
          ),
        ),
      ),
    );
  }
}
