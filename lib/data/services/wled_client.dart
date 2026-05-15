import 'package:dio/dio.dart';

import '../../core/constants/network.dart';
import '../models/scene.dart';
import '../models/wled_info.dart';

/// HTTP client for a single WLED device. One instance per wall — baseUrl is fixed.
/// Errors bubble up as [DioException]; callers wrap in AsyncValue.
class WledClient {
  WledClient({required String baseUrl, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: NetworkTiming.httpConnectTimeout,
              receiveTimeout: NetworkTiming.httpReceiveTimeout,
              responseType: ResponseType.json,
            )) {
    _dio.interceptors.add(_RetryInterceptor());
  }

  final Dio _dio;

  /// Apply a scene at full configured parameters. Overrides let UI sliders
  /// tweak brightness/speed/intensity without forking the catalog.
  Future<void> applyScene(
    Scene scene, {
    int? briOverride,
    int? sxOverride,
    int? ixOverride,
  }) {
    final seg = <String, dynamic>{
      'id': 0,
      'fx': scene.fx,
      'pal': scene.pal,
    };
    final sx = sxOverride ?? scene.defaultSx;
    final ix = ixOverride ?? scene.defaultIx;
    if (sx != null) seg['sx'] = sx;
    if (ix != null) seg['ix'] = ix;
    if (scene.rgb != null) seg['col'] = [scene.rgb];

    return _post('/json/state', {
      'on': true,
      'bri': briOverride ?? scene.defaultBri,
      'transition': scene.transition,
      'seg': [seg],
    });
  }

  Future<void> setOnOff(bool on) => _post('/json/state', {'on': on});

  Future<void> setBrightness(int bri) =>
      _post('/json/state', {'bri': bri.clamp(0, 255)});

  /// Wire a wall into a UDP sync group. Both flags true = full bidirectional
  /// sync; the spec uses room-level sync, so every wall in a room gets this.
  Future<void> setSyncEnabled({required bool send, required bool recv}) =>
      _post('/json/cfg', {
        'if': {
          'sync': {'send': send, 'recv': recv},
        },
      });

  /// Returns null instead of throwing — discovery probe needs to silently
  /// reject non-WLED hosts on the subnet.
  Future<WledInfo?> getInfo() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/json/info');
      final data = res.data;
      if (data == null) return null;
      return WledInfo.fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<void> _post(String path, Map<String, dynamic> body) async {
    await _dio.post<void>(path, data: body);
  }
}

/// Retries transient errors once. 4xx responses are treated as terminal —
/// a bad payload won't get better with a second attempt.
class _RetryInterceptor extends Interceptor {
  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final attempt = (err.requestOptions.extra['_retry'] as int?) ?? 0;
    if (attempt >= NetworkTiming.httpMaxRetries || !_isTransient(err)) {
      handler.next(err);
      return;
    }

    await Future<void>.delayed(NetworkTiming.httpRetryDelay);
    err.requestOptions.extra['_retry'] = attempt + 1;
    try {
      final response = await Dio().fetch<dynamic>(err.requestOptions);
      handler.resolve(response);
    } on DioException catch (e) {
      handler.next(e);
    }
  }

  bool _isTransient(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status >= 500;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return false;
    }
  }
}
