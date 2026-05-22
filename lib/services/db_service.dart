import 'package:path_provider/path_provider.dart';
import 'package:isar/isar.dart';
import '../models/api_request_history.dart';

class DbService {
  late final Isar _isar;
  bool _isInitialized = false;

  Isar get isar => _isar;

  /// 데이터베이스를 초기화합니다.
  Future<void> init() async {
    if (_isInitialized) return;

    final dir = await getApplicationSupportDirectory();
    _isar = await Isar.open(
      [ApiRequestHistorySchema],
      directory: dir.path,
      name: 'api_testing_db',
    );
    _isInitialized = true;
  }

  /// 모든 히스토리를 최신순(timestamp 내림차순)으로 조회합니다.
  Future<List<ApiRequestHistory>> getAllHistory() async {
    return await _isar.apiRequestHistorys
        .where()
        .sortByTimestampDesc()
        .findAll();
  }

  /// 즐겨찾기(isFavorite == true) 목록만 조회합니다.
  Future<List<ApiRequestHistory>> getFavorites() async {
    return await _isar.apiRequestHistorys
        .where()
        .filter()
        .isFavoriteEqualTo(true)
        .sortByTimestampDesc()
        .findAll();
  }

  /// 일반 히스토리(isFavorite == false) 목록만 조회합니다.
  Future<List<ApiRequestHistory>> getNonFavorites() async {
    return await _isar.apiRequestHistorys
        .where()
        .filter()
        .isFavoriteEqualTo(false)
        .sortByTimestampDesc()
        .findAll();
  }

  /// 새로운 히스토리를 기록합니다.
  /// 즐겨찾기가 아닌(isFavorite == false) 일반 항목이 100개를 초과할 경우,
  /// 가장 오래된 항목부터 순차적으로 자동 삭제됩니다.
  Future<void> saveHistory(ApiRequestHistory history) async {
    await _isar.writeTxn(() async {
      // 1. 새 히스토리 추가
      await _isar.apiRequestHistorys.put(history);

      // 2. 즐겨찾기가 아닌 항목들(isFavorite == false)을 오래된 순(오름차순)으로 조회
      final nonFavorites = await _isar.apiRequestHistorys
          .where()
          .filter()
          .isFavoriteEqualTo(false)
          .sortByTimestamp()
          .findAll();

      // 3. 100개를 초과하는 분량만큼 가장 오래된 것 삭제
      if (nonFavorites.length > 100) {
        final excess = nonFavorites.length - 100;
        final idsToDelete = nonFavorites.take(excess).map((e) => e.id).toList();
        await _isar.apiRequestHistorys.deleteAll(idsToDelete);
      }
    });
  }

  /// 즐겨찾기 상태를 토글(반전)합니다.
  Future<void> toggleFavorite(int id) async {
    await _isar.writeTxn(() async {
      final history = await _isar.apiRequestHistorys.get(id);
      if (history != null) {
        history.isFavorite = !history.isFavorite;
        await _isar.apiRequestHistorys.put(history);
      }
    });
  }

  /// 특정 히스토리를 수동 삭제합니다.
  Future<void> deleteHistory(int id) async {
    await _isar.writeTxn(() async {
      await _isar.apiRequestHistorys.delete(id);
    });
  }

  /// 즐겨찾기가 아닌 모든 일반 히스토리를 삭제합니다. (즐겨찾기는 보존)
  Future<void> clearNonFavorites() async {
    await _isar.writeTxn(() async {
      final nonFavorites = await _isar.apiRequestHistorys
          .where()
          .filter()
          .isFavoriteEqualTo(false)
          .findAll();
      final ids = nonFavorites.map((e) => e.id).toList();
      await _isar.apiRequestHistorys.deleteAll(ids);
    });
  }

  /// 데이터베이스의 모든 데이터를 초기화합니다.
  Future<void> clearAll() async {
    await _isar.writeTxn(() async {
      await _isar.apiRequestHistorys.clear();
    });
  }
}
