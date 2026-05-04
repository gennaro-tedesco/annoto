import 'package:annoto/models/opening_explorer.dart';
import 'package:dio/dio.dart';

class OpeningExplorerService {
  static const _baseUrl = 'https://explorer.lichess.ovh/masters';
  static const _minInterval = Duration(seconds: 1);
  static const _timeout = Duration(seconds: 10);

  final Dio _dio = Dio(
    BaseOptions(connectTimeout: _timeout, receiveTimeout: _timeout),
  );

  DateTime? _lastRequestTime;
  CancelToken? _cancelToken;

  Future<void> _rateLimit() async {
    final now = DateTime.now();
    if (_lastRequestTime != null) {
      final elapsed = now.difference(_lastRequestTime!);
      if (elapsed < _minInterval) {
        await Future.delayed(_minInterval - elapsed);
      }
    }
    _lastRequestTime = DateTime.now();
  }

  Future<ExplorerResult?> queryByPlay(
    String uciMoves, {
    required String accessToken,
  }) async {
    _cancelToken?.cancel();
    final token = CancelToken();
    _cancelToken = token;
    return _query({'play': uciMoves}, token, accessToken: accessToken);
  }

  Future<ExplorerResult?> _query(
    Map<String, dynamic> params,
    CancelToken cancelToken, {
    required String accessToken,
    bool isRetry = false,
  }) async {
    await _rateLimit();
    if (cancelToken.isCancelled) return null;
    try {
      final response = await _dio.get<dynamic>(
        _baseUrl,
        queryParameters: params,
        options: Options(headers: {'Authorization': 'Bearer $accessToken'}),
        cancelToken: cancelToken,
      );
      final data = response.data as Map<String, dynamic>?;
      if (data == null) return null;
      return ExplorerResult.fromJson(data);
    } on DioException catch (e) {
      if (CancelToken.isCancel(e)) return null;
      if (e.response?.statusCode == 429) return null;
      if (e.response?.statusCode == 404) return null;
      if (!isRetry &&
          (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError)) {
        return _query(
          params,
          cancelToken,
          accessToken: accessToken,
          isRetry: true,
        );
      }
      return null;
    }
  }

  void cancel() {
    _cancelToken?.cancel();
    _cancelToken = null;
  }
}

final openingExplorerService = OpeningExplorerService();
