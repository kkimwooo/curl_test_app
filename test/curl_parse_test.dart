import 'package:flutter_test/flutter_test.dart';
import 'package:levi_curl_test_app/models/api_request_history.dart';

void main() {
  group('cURL Parser & Generator Tests', () {
    test('Simple GET request parsing', () {
      const curl = "curl -X GET 'https://api.github.com/users/octocat'";
      final request = ApiRequestHistory.fromCurl(curl);

      expect(request.method, equals('GET'));
      expect(request.url, equals('https://api.github.com/users/octocat'));
      expect(request.headers, isEmpty);
      expect(request.queryParams, isEmpty);
      expect(request.body, isNull);
    });

    test('POST request with headers and body parsing', () {
      const curl = "curl -X POST -H 'Content-Type: application/json' -H 'Authorization: Bearer mytoken' -d '{\"name\":\"Leviathan\"}' 'https://api.example.com/v1/users'";
      final request = ApiRequestHistory.fromCurl(curl);

      expect(request.method, equals('POST'));
      expect(request.url, equals('https://api.example.com/v1/users'));
      expect(request.headers['Content-Type'], equals('application/json'));
      expect(request.headers['Authorization'], equals('Bearer mytoken'));
      expect(request.body, equals('{"name":"Leviathan"}'));
    });

    test('URL Parameter separation during parsing', () {
      const curl = "curl 'https://api.example.com/search?q=flutter&lang=ko&page=1'";
      final request = ApiRequestHistory.fromCurl(curl);

      expect(request.url, equals('https://api.example.com/search'));
      expect(request.queryParams['q'], equals('flutter'));
      expect(request.queryParams['lang'], equals('ko'));
      expect(request.queryParams['page'], equals('1'));
    });

    test('Multiline cURL parsing with backslashes', () {
      const curl = """
curl -X PUT \\
  -H 'Content-Type: application/json' \\
  -d '{"status":"active"}' \\
  'https://api.example.com/update'
""";
      final request = ApiRequestHistory.fromCurl(curl);

      expect(request.method, equals('PUT'));
      expect(request.url, equals('https://api.example.com/update'));
      expect(request.headers['Content-Type'], equals('application/json'));
      expect(request.body, equals('{"status":"active"}'));
    });

    test('Model to cURL generation (toCurl)', () {
      final request = ApiRequestHistory(
        method: 'POST',
        url: 'https://api.example.com/create',
        headers: {'Content-Type': 'application/json', 'X-Custom': 'Value'},
        queryParams: {'ref': 'web', 'debug': 'true'},
        body: '{"test":true}',
        timestamp: DateTime.now(),
        isFavorite: false,
      );

      final curlString = request.toCurl();

      // 검증 항목들
      expect(curlString, contains('-X POST'));
      expect(curlString, contains("-H 'Content-Type: application/json'"));
      expect(curlString, contains("-H 'X-Custom: Value'"));
      expect(curlString, contains("-d '{\"test\":true}'"));
      expect(curlString, contains('ref=web'));
      expect(curlString, contains('debug=true'));
    });
   group('cURL Bidirectional Integration Tests', () {
      test('Parsed cURL output is identical after regeneration', () {
        const originalCurl = "curl -X POST -H 'Content-Type: application/json' -d '{\"id\":123}' 'https://api.example.com/users?source=mobile'";
        final parsed = ApiRequestHistory.fromCurl(originalCurl);
        final regenerated = parsed.toCurl();

        // 재생성된 cURL을 다시 파싱해서 결과가 최초 파싱본과 동일한지 확인
        final parsed2 = ApiRequestHistory.fromCurl(regenerated);
        expect(parsed2.method, equals(parsed.method));
        expect(parsed2.url, equals(parsed.url));
        expect(parsed2.headers, equals(parsed.headers));
        expect(parsed2.queryParams, equals(parsed.queryParams));
        expect(parsed2.body, equals(parsed.body));
      });
    });
    test('Model with description field serialization', () {
      final request = ApiRequestHistory(
        method: 'GET',
        url: 'https://api.example.com',
        timestamp: DateTime.now(),
        isFavorite: false,
        description: '이것은 테스트 설명입니다.',
      );

      expect(request.description, equals('이것은 테스트 설명입니다.'));
    });
  });
}
