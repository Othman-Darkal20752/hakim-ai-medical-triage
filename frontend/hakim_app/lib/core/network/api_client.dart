import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  const ApiException(
      this.message, {
        this.statusCode,
      });

  @override
  String toString() {
    return 'ApiException(statusCode: $statusCode, message: $message)';
  }
}

class ApiClient {
  final http.Client _client;

  ApiClient({
    http.Client? client,
  }) : _client = client ?? http.Client();

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConstants.baseUrl}$normalizedPath');
  }

  Future<Map<String, dynamic>> get(
      String path, {
        String? token,
      }) async {
    final response = await _client
        .get(
      _buildUri(path),
      headers: _buildHeaders(token),
    )
        .timeout(ApiConstants.timeout);

    return _handleResponse(response);
  }

  Future<Map<String, dynamic>> post(
      String path, {
        required Map<String, dynamic> body,
        String? token,
      }) async {
    final response = await _client
        .post(
      _buildUri(path),
      headers: _buildHeaders(token),
      body: jsonEncode(body),
    )
        .timeout(ApiConstants.timeout);

    return _handleResponse(response);
  }

  Map<String, String> _buildHeaders(String? token) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = response.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ApiException(
        body['detail']?.toString() ?? 'حدث خطأ أثناء الاتصال بالخادم',
        statusCode: response.statusCode,
      );
    }

    return body;
  }
}