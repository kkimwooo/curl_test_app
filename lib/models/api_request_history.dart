import 'dart:convert';
import 'package:isar/isar.dart';

part 'api_request_history.g.dart';

@collection
class ApiRequestHistory {
  Id id = Isar.autoIncrement;

  late String method;
  late String url;
  
  // Isar 3.x는 Map<String, String> 구조를 지원하지 않으므로 JSON 스트링으로 관리
  late String headersJson;
  late String queryParamsJson;
  
  String? body;
  
  @Index()
  late DateTime timestamp;
  
  @Index()
  late bool isFavorite;

  String? description;

  // JSON 변환을 위한 getter / setter
  @ignore
  Map<String, String> get headers {
    try {
      return Map<String, String>.from(jsonDecode(headersJson));
    } catch (_) {
      return {};
    }
  }

  set headers(Map<String, String> value) {
    headersJson = jsonEncode(value);
  }

  @ignore
  Map<String, String> get queryParams {
    try {
      return Map<String, String>.from(jsonDecode(queryParamsJson));
    } catch (_) {
      return {};
    }
  }

  set queryParams(Map<String, String> value) {
    queryParamsJson = jsonEncode(value);
  }

  ApiRequestHistory({
    this.id = Isar.autoIncrement,
    required this.method,
    required this.url,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    this.body,
    required this.timestamp,
    required this.isFavorite,
    this.description,
  }) {
    this.headers = headers ?? {};
    this.queryParams = queryParams ?? {};
  }

  /// 현재 객체 데이터를 쉘 실행이 가능한 cURL 문자열로 생성합니다.
  String toCurl() {
    final buffer = StringBuffer();
    buffer.write('curl');

    // 1. Method
    buffer.write(' -X ${method.toUpperCase()}');

    // 2. Headers
    final currentHeaders = headers;
    currentHeaders.forEach((key, value) {
      final escapedKey = key.replaceAll("'", "'\\''");
      final escapedValue = value.replaceAll("'", "'\\''");
      buffer.write(" -H '$escapedKey: $escapedValue'");
    });

    // 3. Body (GET/HEAD 가 아니고 body가 비어있지 않을 때)
    final upperMethod = method.toUpperCase();
    if (body != null && body!.isNotEmpty && upperMethod != 'GET' && upperMethod != 'HEAD') {
      final escapedBody = body!.replaceAll("'", "'\\''");
      buffer.write(" -d '$escapedBody'");
    }

    // 4. URL with Query Params
    var finalUrl = url;
    if (queryParams.isNotEmpty) {
      try {
        var uri = Uri.parse(url);
        // 기존 URL에 쿼리 파라미터가 이미 붙어있을 수 있으므로 병합
        final mergedParams = {...uri.queryParameters, ...queryParams};
        uri = uri.replace(queryParameters: mergedParams);
        finalUrl = uri.toString();
      } catch (_) {
        final queryString = queryParams.entries
            .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
            .join('&');
        if (finalUrl.contains('?')) {
          finalUrl = '$finalUrl&$queryString';
        } else {
          finalUrl = '$finalUrl?$queryString';
        }
      }
    }
    
    final escapedUrl = finalUrl.replaceAll("'", "'\\''");
    buffer.write(" '$escapedUrl'");

    return buffer.toString();
  }

  /// cURL 문자열을 파싱하여 ApiRequestHistory 인스턴스를 생성합니다.
  factory ApiRequestHistory.fromCurl(String curlString) {
    final args = _splitShellArguments(curlString);
    
    String method = 'GET';
    String? rawUrl;
    final Map<String, String> parsedHeaders = {};
    String? body;
    
    int i = 0;
    while (i < args.length) {
      final arg = args[i];
      
      if (arg.toLowerCase() == 'curl') {
        i++;
        continue;
      }
      
      if (arg == '-X' || arg == '--request') {
        if (i + 1 < args.length) {
          method = args[i + 1].toUpperCase();
          i += 2;
        } else {
          i++;
        }
      } else if (arg == '-H' || arg == '--header') {
        if (i + 1 < args.length) {
          final headerStr = args[i + 1];
          final colonIndex = headerStr.indexOf(':');
          if (colonIndex != -1) {
            final key = headerStr.substring(0, colonIndex).trim();
            final value = headerStr.substring(colonIndex + 1).trim();
            parsedHeaders[key] = value;
          }
          i += 2;
        } else {
          i++;
        }
      } else if (arg == '-d' || arg == '--data' || arg == '--data-raw' || arg == '--data-binary') {
        if (i + 1 < args.length) {
          body = args[i + 1];
          if (method == 'GET') {
            method = 'POST'; // 바디가 지정되었는데 GET이면 기본 POST로 변환
          }
          i += 2;
        } else {
          i++;
        }
      } else if (arg.startsWith('-')) {
        // 지원하지 않는 플래그 무시
        i++;
      } else {
        if (rawUrl == null) {
          rawUrl = arg;
        }
        i++;
      }
    }
    
    rawUrl ??= '';
    String finalUrl = rawUrl;
    final Map<String, String> parsedQueryParams = {};
    
    if (rawUrl.isNotEmpty) {
      try {
        var tempUrl = rawUrl;
        if (!tempUrl.startsWith('http://') && !tempUrl.startsWith('https://')) {
          tempUrl = 'http://$tempUrl';
        }
        final uri = Uri.parse(tempUrl);
        
        parsedQueryParams.addAll(uri.queryParameters);
        
        final schemePrefix = rawUrl.startsWith('http://') || rawUrl.startsWith('https://') 
            ? '${uri.scheme}://${uri.authority}'
            : uri.authority;
            
        finalUrl = '$schemePrefix${uri.path}';
      } catch (_) {
        finalUrl = rawUrl;
      }
    }

    return ApiRequestHistory(
      method: method,
      url: finalUrl,
      headers: parsedHeaders,
      queryParams: parsedQueryParams,
      body: body,
      timestamp: DateTime.now(),
      isFavorite: false,
    );
  }

  /// 쉘 문법에 맞춰 이스케이프 및 따옴표를 고려해 문자열을 분할합니다.
  static List<String> _splitShellArguments(String command) {
    // 줄 끝의 백슬래시 + 개행 제거
    command = command.replaceAll(RegExp(r'\\\s*\n'), ' ');
    
    final List<String> args = [];
    final StringBuffer currentToken = StringBuffer();
    bool inSingleQuote = false;
    bool inDoubleQuote = false;
    bool isEscaped = false;

    for (int i = 0; i < command.length; i++) {
      final String char = command[i];

      if (isEscaped) {
        currentToken.write(char);
        isEscaped = false;
        continue;
      }

      if (char == '\\') {
        if (inSingleQuote) {
          currentToken.write(char);
        } else {
          isEscaped = true;
        }
        continue;
      }

      if (char == '\'') {
        if (inDoubleQuote) {
          currentToken.write(char);
        } else {
          inSingleQuote = !inSingleQuote;
        }
        continue;
      }

      if (char == '"') {
        if (inSingleQuote) {
          currentToken.write(char);
        } else {
          inDoubleQuote = !inDoubleQuote;
        }
        continue;
      }

      if (char == ' ' || char == '\t' || char == '\n' || char == '\r') {
        if (inSingleQuote || inDoubleQuote) {
          currentToken.write(char);
        } else {
          if (currentToken.isNotEmpty) {
            args.add(currentToken.toString());
            currentToken.clear();
          }
        }
      } else {
        currentToken.write(char);
      }
    }

    if (currentToken.isNotEmpty) {
      args.add(currentToken.toString());
    }

    return args;
  }
}
