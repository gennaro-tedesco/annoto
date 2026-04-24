import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LichessService {
  static const _clientId = 'annoto';
  static const _redirectUrl = 'com.example.annoto:/oauthredirect';
  static const _authorizationEndpoint = 'https://lichess.org/oauth';
  static const _tokenEndpoint = 'https://lichess.org/api/token';
  static const _scope = 'study:read';
  static const _tokenKey = 'lichess_access_token';
  static const _usernameKey = 'lichess_username';

  final FlutterAppAuth _appAuth = const FlutterAppAuth();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final Dio _dio = Dio();

  Future<String?> username() {
    return _storage.read(key: _usernameKey);
  }

  Future<void> authenticate(String username) async {
    final result = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        _clientId,
        _redirectUrl,
        serviceConfiguration: const AuthorizationServiceConfiguration(
          authorizationEndpoint: _authorizationEndpoint,
          tokenEndpoint: _tokenEndpoint,
        ),
        scopes: const [_scope],
      ),
    );

    final token = result.accessToken;

    if (token == null || token.isEmpty) {
      throw Exception('Lichess authentication failed.');
    }

    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _usernameKey, value: username);
  }

  Future<String> exportStudiesPgn(String username) async {
    final token = await _storage.read(key: _tokenKey);

    if (token == null || token.isEmpty) {
      throw Exception('Lichess authentication required.');
    }

    final response = await _dio.get<String>(
      'https://lichess.org/api/study/by/$username/export.pgn',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    final pgn = response.data?.trim() ?? '';

    if (pgn.isEmpty) {
      throw Exception('No Lichess studies found.');
    }

    return pgn;
  }
}

final lichessService = LichessService();
