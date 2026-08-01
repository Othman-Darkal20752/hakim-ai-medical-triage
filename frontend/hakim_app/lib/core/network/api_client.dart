import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_constants.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, List<String>> fieldErrors;

  const ApiException(
    this.message, {
    this.statusCode,
    this.fieldErrors = const {},
  });

  List<String> errorsFor(String fieldName) {
    return fieldErrors[fieldName] ?? const [];
  }

  @override
  String toString() {
    return 'ApiException('
        'statusCode: $statusCode, '
        'message: $message, '
        'fieldErrors: $fieldErrors'
        ')';
  }
}

class ApiClient {
  final http.Client _client;

  ApiClient({http.Client? client}) : _client = client ?? http.Client();

  Uri _buildUri(String path) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    return Uri.parse('${ApiConstants.baseUrl}$normalizedPath');
  }

  Future<Map<String, dynamic>> get(String path, {String? token}) async {
    final response = await _client
        .get(_buildUri(path), headers: _buildHeaders(token))
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

  Future<Map<String, dynamic>> delete(String path, {String? token}) async {
    final response = await _client
        .delete(_buildUri(path), headers: _buildHeaders(token))
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
      final fieldErrors = _extractFieldErrors(body);

      throw ApiException(
        _extractErrorMessage(body: body, fieldErrors: fieldErrors),
        statusCode: response.statusCode,
        fieldErrors: fieldErrors,
      );
    }

    return body;
  }

  Map<String, List<String>> _extractFieldErrors(Map<String, dynamic> body) {
    final errors = <String, List<String>>{};

    for (final entry in body.entries) {
      if (entry.key == 'detail' || entry.key == 'error') {
        continue;
      }

      final messages = _normalizeErrorMessages(entry.value);

      if (messages.isNotEmpty) {
        errors[entry.key] = List.unmodifiable(messages);
      }
    }

    return Map.unmodifiable(errors);
  }

  String _extractErrorMessage({
    required Map<String, dynamic> body,
    required Map<String, List<String>> fieldErrors,
  }) {
    final detailMessages = _normalizeErrorMessages(body['detail']);

    if (detailMessages.isNotEmpty) {
      return detailMessages.first;
    }

    final errorMessages = _normalizeErrorMessages(body['error']);

    if (errorMessages.isNotEmpty) {
      return errorMessages.first;
    }

    final nonFieldErrors = fieldErrors['non_field_errors'];

    if (nonFieldErrors != null && nonFieldErrors.isNotEmpty) {
      return nonFieldErrors.first;
    }

    for (final messages in fieldErrors.values) {
      if (messages.isNotEmpty) {
        return messages.first;
      }
    }

    return 'حدث خطأ أثناء الاتصال بالخادم';
  }

  List<String> _normalizeErrorMessages(dynamic value) {
    if (value == null) {
      return const [];
    }

    if (value is String) {
      final normalized = value.trim();
      return normalized.isEmpty ? const [] : [normalized];
    }

    if (value is Iterable) {
      return value
          .expand(_normalizeErrorMessages)
          .where((message) => message.isNotEmpty)
          .toList(growable: false);
    }

    if (value is Map) {
      return value.values
          .expand(_normalizeErrorMessages)
          .where((message) => message.isNotEmpty)
          .toList(growable: false);
    }

    final normalized = value.toString().trim();

    return normalized.isEmpty ? const [] : [normalized];
  }
}
