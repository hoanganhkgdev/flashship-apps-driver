import 'dart:io';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';
import '../constants/app_constants.dart';

class ApiClient {
  final Dio _dio;

  ApiClient(String? token) : _dio = Dio() {
    _dio.options = BaseOptions(
      baseUrl: AppConstants.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
      headers: {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      },
    );

    _dio.httpClientAdapter = _buildAdapter();
  }

  IOHttpClientAdapter _buildAdapter() {
    final adapter = IOHttpClientAdapter();
    adapter.createHttpClient = () {
      final client = HttpClient();
      client.idleTimeout = const Duration(seconds: 8);
      if (kDebugMode) {
        client.badCertificateCallback = (cert, host, port) => true;
      }
      return client;
    };
    return adapter;
  }

  /// Đóng connection cũ rồi gắn adapter mới — gọi khi app resume từ
  /// background lâu, tránh request bị treo do tái dùng socket mà OS đã
  /// đóng băng trong lúc app ở nền. Cực kỳ quan trọng cho driver vì cần
  /// nhận đơn realtime ngay khi mở app lại.
  void resetConnection() {
    final old = _dio.httpClientAdapter;
    _dio.httpClientAdapter = _buildAdapter();
    old.close(force: true);
  }

  Future<Response> get(String path, {Map<String, dynamic>? params}) =>
      _dio.get(path, queryParameters: params);

  Future<Response> post(String path, {dynamic data}) =>
      _dio.post(path, data: data);

  Future<Response> put(String path, {dynamic data}) =>
      _dio.put(path, data: data);

  Future<Response> postMultipart(String path, FormData formData) =>
      _dio.post(
        path,
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

  Future<Response> getExternal(String url) {
    final dio = Dio();
    dio.options.connectTimeout = const Duration(seconds: 8);
    dio.options.receiveTimeout = const Duration(seconds: 8);
    return dio.get(url, options: Options(headers: {'Accept': 'application/json'}));
  }
}

