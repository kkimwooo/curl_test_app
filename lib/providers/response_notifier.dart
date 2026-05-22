import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import '../models/api_request_history.dart';
import 'history_notifier.dart';

class ResponseFormState {
  final int? statusCode;
  final String? statusMessage;
  final int elapsedTimeMs;
  final int responseSize;
  final Map<String, List<String>> headers;
  final String body;
  final bool isLoading;
  final String? errorMessage;

  ResponseFormState({
    this.statusCode,
    this.statusMessage,
    this.elapsedTimeMs = 0,
    this.responseSize = 0,
    this.headers = const {},
    this.body = '',
    this.isLoading = false,
    this.errorMessage,
  });

  ResponseFormState.initial()
      : statusCode = null,
        statusMessage = null,
        elapsedTimeMs = 0,
        responseSize = 0,
        headers = const {},
        body = '',
        isLoading = false,
        errorMessage = null;

  ResponseFormState copyWith({
    int? statusCode,
    String? statusMessage,
    int? elapsedTimeMs,
    int? responseSize,
    Map<String, List<String>>? headers,
    String? body,
    bool? isLoading,
    String? errorMessage,
  }) {
    return ResponseFormState(
      statusCode: statusCode ?? this.statusCode,
      statusMessage: statusMessage ?? this.statusMessage,
      elapsedTimeMs: elapsedTimeMs ?? this.elapsedTimeMs,
      responseSize: responseSize ?? this.responseSize,
      headers: headers ?? this.headers,
      body: body ?? this.body,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

final responseProvider = StateNotifierProvider<ResponseNotifier, ResponseFormState>((ref) {
  return ResponseNotifier(ref);
});

class ResponseNotifier extends StateNotifier<ResponseFormState> {
  final Ref _ref;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 10),
    validateStatus: (status) => true, // 4xx, 5xx 에러도 응답으로 수신하여 Status Code 표시하기 위함
  ));

  ResponseNotifier(this._ref) : super(ResponseFormState.initial());

  Future<void> sendRequest() async {
    final requestForm = _ref.read(requestFormProvider);
    
    state = ResponseFormState(isLoading: true);
    
    final startTime = DateTime.now();
    
    try {
      // 1. HTTP Method 및 URL 설정
      final method = requestForm.method.toUpperCase();
      final url = requestForm.url;

      // 2. Query Parameters 머지
      // URL 내부에 들어있는 쿼리 스트링도 있을 수 있으므로 Dio에 쿼리 파라미터 맵 전달
      final queryParams = {...requestForm.queryParams};

      // 3. Body 처리
      dynamic requestData;
      if (method != 'GET' && method != 'HEAD' && requestForm.body.isNotEmpty) {
        // JSON 형태인 경우 파싱 시도하고, 실패 시 raw string 전송
        try {
          requestData = jsonDecode(requestForm.body);
        } catch (_) {
          requestData = requestForm.body;
        }
      }

      // 4. Headers 가공
      final Map<String, dynamic> requestHeaders = Map<String, dynamic>.from(requestForm.headers);

      final response = await _dio.request(
        url,
        data: requestData,
        queryParameters: queryParams.isNotEmpty ? queryParams : null,
        options: Options(
          method: method,
          headers: requestHeaders,
          responseType: ResponseType.plain, // Raw text로 받아 pretty-print 함
        ),
      );

      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      // 응답 크기 계산 (바이트 단위)
      final rawResponseBody = response.data?.toString() ?? '';
      final size = utf8.encode(rawResponseBody).length;

      // JSON Pretty Print 시도
      String formattedBody = rawResponseBody;
      try {
        final decoded = jsonDecode(rawResponseBody);
        formattedBody = const JsonEncoder.withIndent('  ').convert(decoded);
      } catch (_) {
        // JSON 파싱 안 되면 그냥 플레인 텍스트 사용
      }

      final Map<String, List<String>> responseHeaders = {};
      response.headers.forEach((name, values) {
        responseHeaders[name] = values;
      });

      state = ResponseFormState(
        statusCode: response.statusCode,
        statusMessage: response.statusMessage ?? _getStatusMessage(response.statusCode),
        elapsedTimeMs: elapsed,
        responseSize: size,
        headers: responseHeaders,
        body: formattedBody,
        isLoading: false,
      );

      // 5. 요청 기록을 히스토리 DB에 자동 저장
      final historyItem = ApiRequestHistory(
        method: requestForm.method,
        url: requestForm.url,
        headers: requestForm.headers,
        queryParams: requestForm.queryParams,
        body: requestForm.body.isNotEmpty ? requestForm.body : null,
        timestamp: DateTime.now(),
        isFavorite: false,
        description: requestForm.description.isNotEmpty ? requestForm.description : null,
      );
      
      await _ref.read(historyProvider.notifier).addHistory(historyItem);

    } on DioException catch (e) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      
      String errorMsg = e.message ?? 'Unknown HTTP Error';
      if (e.type == DioExceptionType.connectionTimeout) {
        errorMsg = 'Connection Timeout (10s)';
      } else if (e.type == DioExceptionType.receiveTimeout) {
        errorMsg = 'Receive Timeout (10s)';
      }

      state = ResponseFormState(
        statusCode: e.response?.statusCode,
        statusMessage: e.response?.statusMessage ?? 'ERROR',
        elapsedTimeMs: elapsed,
        body: e.response?.data?.toString() ?? '',
        isLoading: false,
        errorMessage: errorMsg,
      );
    } catch (e) {
      final elapsed = DateTime.now().difference(startTime).inMilliseconds;
      state = ResponseFormState(
        isLoading: false,
        elapsedTimeMs: elapsed,
        errorMessage: '네트워크 요청 실패: $e',
      );
    }
  }

  String _getStatusMessage(int? statusCode) {
    if (statusCode == null) return 'UNKNOWN';
    switch (statusCode) {
      case 200: return 'OK';
      case 201: return 'Created';
      case 204: return 'No Content';
      case 400: return 'Bad Request';
      case 401: return 'Unauthorized';
      case 403: return 'Forbidden';
      case 404: return 'Not Found';
      case 500: return 'Internal Server Error';
      default: return 'HTTP Status $statusCode';
    }
  }
}
