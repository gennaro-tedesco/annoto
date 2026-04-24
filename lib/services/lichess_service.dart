import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_appauth/flutter_appauth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LichessStudy {
  const LichessStudy({
    required this.id,
    required this.name,
    this.visibility,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? visibility;
  final DateTime? updatedAt;
}

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

  Future<List<LichessStudy>> getStudies() async {
    final username = await this.username();
    final token = await _storage.read(key: _tokenKey);

    if (username == null || username.isEmpty) {
      throw Exception('Lichess username missing.');
    }

    if (token == null || token.isEmpty) {
      throw Exception('Lichess authentication required.');
    }

    final response = await _dio.get<String>(
      'https://lichess.org/api/study/by/$username',
      options: Options(
        responseType: ResponseType.plain,
        headers: {
          'Accept': 'application/x-ndjson',
          'Authorization': 'Bearer $token',
        },
      ),
    );

    final body = response.data ?? '';

    return body
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .map((line) => jsonDecode(line) as Map<String, dynamic>)
        .where((json) => json['id'] is String)
        .map((json) {
          final updatedAt = json['updatedAt'];

          return LichessStudy(
            id: json['id'] as String,
            name: (json['name'] as String?) ?? json['id'] as String,
            visibility: json['visibility'] as String?,
            updatedAt: updatedAt is int
                ? DateTime.fromMillisecondsSinceEpoch(updatedAt)
                : null,
          );
        })
        .toList();
  }

  Future<String> exportStudyPgn(String studyId) async {
    final token = await _storage.read(key: _tokenKey);

    if (token == null || token.isEmpty) {
      throw Exception('Lichess authentication required.');
    }

    final response = await _dio.get<String>(
      'https://lichess.org/study/$studyId.pgn',
      options: Options(
        responseType: ResponseType.plain,
        headers: {'Authorization': 'Bearer $token'},
      ),
    );

    final pgn = response.data?.trim() ?? '';

    if (pgn.isEmpty) {
      throw Exception('Empty Lichess study.');
    }

    return pgn;
  }
}

final lichessService = LichessService();
