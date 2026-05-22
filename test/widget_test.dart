import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:levi_curl_test_app/main.dart';

void main() {
  testWidgets('App loading state verification test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(
      const ProviderScope(
        child: MyApp(),
      ),
    );

    // DB 초기화 전에는 로딩 인디케이터가 표시됨을 확인
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
