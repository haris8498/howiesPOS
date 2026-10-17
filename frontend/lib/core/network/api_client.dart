import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../config/api_config.dart';
import '../security/token_storage.dart';

/// Standard response wrapper returned by the NestJS backend
class ApiResponseWrapper<T> {
  final bool success;
  final String? message;
  final T? data;
  final int? count;
  final dynamic error;

  const ApiResponseWrapper({
    required this.success,
    this.message,
    this.data,
    this.count,
    this.error,
  });

  factory ApiResponseWrapper.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic json)? fromJsonT,
  ) {
    return ApiResponseWrapper<T>(
      success: json['success'] == true,
      message: json['message'] as String?,
      data: json['data'] != null && fromJsonT != null
          ? fromJsonT(json['data'])
          : json['data'] as T?,
      count: json['count'] as int?,
      error: json['error'],
    );
  }
}

/// Base exception for API network layer
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException(this.message, {this.statusCode, this.details});

  @override
  String toString() => message;
}

class NetworkException extends ApiException {
  const NetworkException(super.message);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException(super.message, {super.statusCode = 401});
}

class ForbiddenException extends ApiException {
  const ForbiddenException(super.message, {super.statusCode = 403});
}

class NotFoundException extends ApiException {
  const NotFoundException(super.message, {super.statusCode = 404});
}

class ConflictException extends ApiException {
  const ConflictException(super.message, {super.statusCode = 409});
}

class ValidationException extends ApiException {
  final List<String> validationErrors;
  const ValidationException(
    super.message, {
    super.statusCode = 400,
    this.validationErrors = const [],
  });
}

/// Centralized HTTP client for communicating with the NestJS backend (Cross-Platform)
class ApiClient {
  final String baseUrl;
  final http.Client _httpClient;
  void Function()? onUnauthorized;

  ApiClient({
    String? baseUrl,
    http.Client? httpClient,
    this.onUnauthorized,
  })  : baseUrl = baseUrl ?? ApiConfig.baseUrl,
        _httpClient = httpClient ?? http.Client();

  /// Helper to get authentication headers
  Future<Map<String, String>> _getHeaders({Map<String, String>? extraHeaders}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };

    final token = await TokenStorage.getToken();
    // Only send real JWT tokens — skip local offline placeholder tokens
    if (token != null && token.isNotEmpty && !token.startsWith('local_offline_token_')) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (extraHeaders != null) {
      headers.addAll(extraHeaders);
    }

    return headers;
  }

  /// Format URL with query parameters
  Uri _buildUri(String path, [Map<String, dynamic>? queryParameters]) {
    String cleanPath = path;
    if (cleanPath.startsWith('/')) {
      cleanPath = cleanPath.substring(1);
    }

    String fullUrl = '$baseUrl/$cleanPath';
    final uri = Uri.parse(fullUrl);

    if (queryParameters != null && queryParameters.isNotEmpty) {
      final queryMap = <String, String>{};
      queryParameters.forEach((key, value) {
        if (value != null) {
          queryMap[key] = value.toString();
        }
      });
      return uri.replace(queryParameters: queryMap);
    }

    return uri;
  }

  void _logRequest(String method, Uri uri) {
    if (kDebugMode) {
      debugPrint('🌐 [HTTP $method] -> $uri');
    }
  }

  void _logResponse(String method, Uri uri, int statusCode, [String? errorSnippet]) {
    if (kDebugMode) {
      if (statusCode >= 200 && statusCode < 300) {
        debugPrint('✅ [HTTP $method $statusCode] <- $uri');
      } else {
        debugPrint('❌ [HTTP $method $statusCode] <- $uri ${errorSnippet != null ? "($errorSnippet)" : ""}');
      }
    }
  }

  /// Process HTTP Response and map to JSON
  Future<dynamic> _processResponse(http.Response response, String method, Uri uri) async {
    final statusCode = response.statusCode;
    final responseBody = response.body;

    dynamic jsonBody;
    if (responseBody.isNotEmpty) {
      try {
        jsonBody = jsonDecode(responseBody);
      } catch (_) {
        jsonBody = {'message': responseBody};
      }
    } else {
      jsonBody = <String, dynamic>{};
    }

    if (statusCode >= 200 && statusCode < 300) {
      _logResponse(method, uri, statusCode);
      return jsonBody;
    }

    // Extract error message
    String errorMessage = 'Request failed with status $statusCode';
    List<String> validationErrors = [];

    if (jsonBody is Map<String, dynamic>) {
      if (jsonBody['message'] is String) {
        errorMessage = jsonBody['message'] as String;
      } else if (jsonBody['message'] is List) {
        validationErrors = (jsonBody['message'] as List).map((e) => e.toString()).toList();
        errorMessage = validationErrors.join(', ');
      } else if (jsonBody['error'] is String) {
        errorMessage = jsonBody['error'] as String;
      }
    }

    _logResponse(method, uri, statusCode, errorMessage);

    if (statusCode == 401) {
      await TokenStorage.clearSession();
      onUnauthorized?.call();
      throw UnauthorizedException(errorMessage.isNotEmpty ? errorMessage : 'Session expired. Please log in again.');
    } else if (statusCode == 403) {
      throw ForbiddenException(errorMessage.isNotEmpty ? errorMessage : 'You do not have permission to perform this action.');
    } else if (statusCode == 404) {
      throw NotFoundException(errorMessage.isNotEmpty ? errorMessage : 'Requested resource not found.');
    } else if (statusCode == 409) {
      throw ConflictException(errorMessage.isNotEmpty ? errorMessage : 'Resource conflict detected.');
    } else if (statusCode == 400 || statusCode == 422) {
      throw ValidationException(
        errorMessage.isNotEmpty ? errorMessage : 'Invalid request parameters.',
        statusCode: statusCode,
        validationErrors: validationErrors,
      );
    } else if (statusCode >= 500) {
      throw ApiException(
        'Server error ($statusCode). Please try again later.',
        statusCode: statusCode,
        details: jsonBody,
      );
    }

    throw ApiException(errorMessage, statusCode: statusCode, details: jsonBody);
  }

  /// Execute GET request
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    _logRequest('GET', uri);
    try {
      final reqHeaders = await _getHeaders(extraHeaders: headers);
      final response = await _httpClient.get(uri, headers: reqHeaders).timeout(ApiConfig.requestTimeout);
      return await _processResponse(response, 'GET', uri);
    } on TimeoutException {
      if (kDebugMode) debugPrint('⚠️ [HTTP GET Timeout] -> $uri');
      throw const NetworkException('Network request timed out. Please try again.');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [HTTP GET Error] -> $uri: $e');
      throw ApiException('Network error: $e');
    }
  }

  /// Execute POST request
  Future<dynamic> post(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    _logRequest('POST', uri);
    try {
      final reqHeaders = await _getHeaders(extraHeaders: headers);
      final jsonString = body != null ? (body is String ? body : jsonEncode(body)) : null;
      final response = await _httpClient
          .post(uri, headers: reqHeaders, body: jsonString)
          .timeout(ApiConfig.requestTimeout);
      return await _processResponse(response, 'POST', uri);
    } on TimeoutException {
      if (kDebugMode) debugPrint('⚠️ [HTTP POST Timeout] -> $uri');
      throw const NetworkException('Network request timed out. Please try again.');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [HTTP POST Error] -> $uri: $e');
      throw ApiException('Network error: $e');
    }
  }

  /// Execute PATCH request
  Future<dynamic> patch(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    _logRequest('PATCH', uri);
    try {
      final reqHeaders = await _getHeaders(extraHeaders: headers);
      final jsonString = body != null ? (body is String ? body : jsonEncode(body)) : null;
      final response = await _httpClient
          .patch(uri, headers: reqHeaders, body: jsonString)
          .timeout(ApiConfig.requestTimeout);
      return await _processResponse(response, 'PATCH', uri);
    } on TimeoutException {
      if (kDebugMode) debugPrint('⚠️ [HTTP PATCH Timeout] -> $uri');
      throw const NetworkException('Network request timed out. Please try again.');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [HTTP PATCH Error] -> $uri: $e');
      throw ApiException('Network error: $e');
    }
  }

  /// Execute PUT request
  Future<dynamic> put(
    String path, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    _logRequest('PUT', uri);
    try {
      final reqHeaders = await _getHeaders(extraHeaders: headers);
      final jsonString = body != null ? (body is String ? body : jsonEncode(body)) : null;
      final response = await _httpClient
          .put(uri, headers: reqHeaders, body: jsonString)
          .timeout(ApiConfig.requestTimeout);
      return await _processResponse(response, 'PUT', uri);
    } on TimeoutException {
      if (kDebugMode) debugPrint('⚠️ [HTTP PUT Timeout] -> $uri');
      throw const NetworkException('Network request timed out. Please try again.');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [HTTP PUT Error] -> $uri: $e');
      throw ApiException('Network error: $e');
    }
  }

  /// Execute DELETE request
  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(path, queryParameters);
    _logRequest('DELETE', uri);
    try {
      final reqHeaders = await _getHeaders(extraHeaders: headers);
      final response = await _httpClient.delete(uri, headers: reqHeaders).timeout(ApiConfig.requestTimeout);
      return await _processResponse(response, 'DELETE', uri);
    } on TimeoutException {
      if (kDebugMode) debugPrint('⚠️ [HTTP DELETE Timeout] -> $uri');
      throw const NetworkException('Network request timed out. Please try again.');
    } on ApiException {
      rethrow;
    } catch (e) {
      if (kDebugMode) debugPrint('⚠️ [HTTP DELETE Error] -> $uri: $e');
      throw ApiException('Network error: $e');
    }
  }
}
