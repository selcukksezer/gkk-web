import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({Dio? dio}) : _dio = dio ?? Dio(_baseOptions());

  final Dio _dio;

  static BaseOptions _baseOptions() {
    return BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      sendTimeout: const Duration(seconds: 15),
      headers: const {
        'Content-Type': 'application/json',
      },
    );
  }

  Future<Response<dynamic>> get(String path, {Map<String, dynamic>? query}) {
    return _dio.get<dynamic>(path, queryParameters: query);
  }

  Future<Response<dynamic>> post(String path, {Object? body}) {
    return _dio.post<dynamic>(path, data: body);
  }

  Future<Response<dynamic>> patch(String path, {Object? body}) {
    return _dio.patch<dynamic>(path, data: body);
  }

  Future<Response<dynamic>> delete(String path, {Object? body}) {
    return _dio.delete<dynamic>(path, data: body);
  }
}
