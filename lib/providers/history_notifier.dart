import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/api_request_history.dart';
import '../services/db_service.dart';

// 1. DB 서비스 싱글톤 프로바이더
final dbServiceProvider = Provider<DbService>((ref) => DbService());

// 2. DB 초기화 상태 프로바이더
final dbInitProvider = FutureProvider<void>((ref) async {
  final dbService = ref.read(dbServiceProvider);
  await dbService.init();
});

// 3. 히스토리 목록 상태 노티파이어 프로바이더
final historyProvider = StateNotifierProvider<HistoryNotifier, List<ApiRequestHistory>>((ref) {
  final dbService = ref.read(dbServiceProvider);
  return HistoryNotifier(dbService);
});

class HistoryNotifier extends StateNotifier<List<ApiRequestHistory>> {
  final DbService _dbService;

  HistoryNotifier(this._dbService) : super([]) {
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    await _dbService.init(); // 안전하게 한 번 더 초기화 확인
    final list = await _dbService.getAllHistory();
    state = list;
  }

  Future<void> addHistory(ApiRequestHistory history) async {
    await _dbService.saveHistory(history);
    await _loadHistory();
  }

  Future<void> toggleFavorite(int id) async {
    await _dbService.toggleFavorite(id);
    await _loadHistory();
  }

  Future<void> deleteHistory(int id) async {
    await _dbService.deleteHistory(id);
    await _loadHistory();
  }

  Future<void> clearNonFavorites() async {
    await _dbService.clearNonFavorites();
    await _loadHistory();
  }

  Future<void> clearAll() async {
    await _dbService.clearAll();
    await _loadHistory();
  }
}

// 4. GUI 입력 폼 및 cURL 연동 상태 모델
class RequestFormState {
  final String method;
  final String url;
  final Map<String, String> headers;
  final Map<String, String> queryParams;
  final String body;
  final String curl;
  final String description;

  RequestFormState({
    required this.method,
    required this.url,
    required this.headers,
    required this.queryParams,
    required this.body,
    required this.curl,
    required this.description,
  });

  RequestFormState.empty()
      : method = 'GET',
        url = 'https://api.github.com/users/octocat',
        headers = {'Content-Type': 'application/json'},
        queryParams = {},
        body = '',
        curl = "curl -X GET -H 'Content-Type: application/json' 'https://api.github.com/users/octocat'",
        description = '';

  RequestFormState copyWith({
    String? method,
    String? url,
    Map<String, String>? headers,
    Map<String, String>? queryParams,
    String? body,
    String? curl,
    String? description,
  }) {
    return RequestFormState(
      method: method ?? this.method,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      queryParams: queryParams ?? this.queryParams,
      body: body ?? this.body,
      curl: curl ?? this.curl,
      description: description ?? this.description,
    );
  }
}

// 5. GUI 입력 폼 상태 및 cURL 실시간 변환 노티파이어 프로바이더
final requestFormProvider = StateNotifierProvider<RequestFormNotifier, RequestFormState>((ref) {
  return RequestFormNotifier();
});

class RequestFormNotifier extends StateNotifier<RequestFormState> {
  RequestFormNotifier() : super(RequestFormState.empty());

  /// 입력 폼 데이터를 기반으로 cURL 문자열을 재생성하여 상태를 업데이트합니다.
  void _syncToCurl(RequestFormState newState) {
    final tempHistory = ApiRequestHistory(
      method: newState.method,
      url: newState.url,
      headers: newState.headers,
      queryParams: newState.queryParams,
      body: newState.body.isNotEmpty ? newState.body : null,
      timestamp: DateTime.now(),
      isFavorite: false,
      description: newState.description,
    );
    state = newState.copyWith(curl: tempHistory.toCurl());
  }

  void updateMethod(String method) {
    _syncToCurl(state.copyWith(method: method));
  }

  void updateUrl(String url) {
    _syncToCurl(state.copyWith(url: url));
  }

  void updateHeaders(Map<String, String> headers) {
    _syncToCurl(state.copyWith(headers: headers));
  }

  void updateQueryParams(Map<String, String> queryParams) {
    _syncToCurl(state.copyWith(queryParams: queryParams));
  }

  void updateBody(String body) {
    _syncToCurl(state.copyWith(body: body));
  }

  void updateDescription(String description) {
    _syncToCurl(state.copyWith(description: description));
  }

  /// 사용자가 특정 히스토리 아이템을 클릭했을 때 입력 폼에 덮어씁니다.
  void loadFromHistory(ApiRequestHistory item) {
    final stateWithNoCurl = RequestFormState(
      method: item.method,
      url: item.url,
      headers: item.headers,
      queryParams: item.queryParams,
      body: item.body ?? '',
      curl: '',
      description: item.description ?? '',
    );
    _syncToCurl(stateWithNoCurl);
  }

  /// cURL 텍스트 변경 또는 붙여넣기 시 이를 파싱하여 GUI 폼에 즉시 역반영합니다.
  void updateFromCurl(String curlString) {
    if (curlString.trim().isEmpty) return;
    try {
      final parsed = ApiRequestHistory.fromCurl(curlString);
      state = RequestFormState(
        method: parsed.method,
        url: parsed.url,
        headers: parsed.headers,
        queryParams: parsed.queryParams,
        body: parsed.body ?? '',
        curl: curlString,
        description: state.description, // cURL 파싱 시 기존 description 유지
      );
    } catch (_) {
      // 파싱 도중 에러가 날 경우 텍스트 값만 우선 유지하여 입력을 돕습니다.
      state = state.copyWith(curl: curlString);
    }
  }
}
