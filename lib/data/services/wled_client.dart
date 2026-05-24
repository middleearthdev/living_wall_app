import 'package:dio/dio.dart';

import '../../core/constants/network.dart';
import '../models/scene.dart';
import '../models/wall_state.dart';
import '../models/wled_info.dart';

/// HTTP client for a single WLED device. One instance per wall — baseUrl is fixed.
/// Errors bubble up as [DioException]; callers wrap in AsyncValue.
class WledClient {
  WledClient({required String baseUrl, Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: baseUrl,
              connectTimeout: NetworkTiming.httpConnectTimeout,
              receiveTimeout: NetworkTiming.httpReceiveTimeout,
              responseType: ResponseType.json,
            ),
          ) {
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
    final seg = <String, dynamic>{'id': 0, 'fx': scene.fx, 'pal': scene.pal};
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

  /// One-shot provisioning at add-wall time: declare the wall's 2D matrix
  /// layout and join its room's UDP sync group.
  ///
  /// Matrix config tells WLED to render 2D effects in (x, y) space across a
  /// serpentine-wired panel, instead of treating the strip as a 1D list of
  /// LEDs. Without this, scenes like Sunset render as scrambled zig-zags on
  /// a real wall.
  ///
  /// Wiring convention is fixed by production: zigzag, bottom-left origin,
  /// row-major. That maps to WLED panel flags `b=true, r=false, v=false,
  /// s=true`.
  ///
  /// Writes to flash — call this once per wall (add-wall or explicit
  /// reconfigure), never on app launch.
  Future<void> configureMatrix({
    required int gridWidth,
    required int gridHeight,
  }) => _post('/json/cfg', {
    'hw': {
      'led': {
        'matrix': {
          'mpc': 1,
          'panels': [
            {
              'b': true, // wiring starts at the bottom row
              'r': false, // ...progressing left-to-right
              'v': false, // row-major (rows, not columns)
              's': true, // serpentine (zigzag)
              'x': 0,
              'y': 0,
              'w': gridWidth,
              'h': gridHeight,
            },
          ],
        },
      },
    },
    // Enable full bidirectional sync. The room-level group concept lives in
    // the app; WLED handles the actual UDP broadcast between walls.
    'if': {
      'sync': {
        'send': {'en': true},
        'recv': {'bri': true, 'col': true, 'fx': true, 'pal': true},
      },
    },
  });

  /// Toggle whether this wall participates in its room's UDP sync group.
  /// Used by the per-wall exclude flow on the room screen.
  ///
  /// WLED stores send/recv as nested objects under `if.sync` (each with its
  /// own sub-flags); passing the top-level booleans as objects' contents
  /// keeps the call atomic from the app's point of view.
  Future<void> setSyncEnabled({required bool send, required bool recv}) =>
      _post('/json/cfg', {
        'if': {
          'sync': {
            'send': {'en': send},
            'recv': {'bri': recv, 'col': recv, 'fx': recv, 'pal': recv},
          },
        },
      });

  /// One-shot read of the current state. Used to seed [wallStateProvider] so
  /// the UI doesn't sit in a loading state waiting for the first WebSocket
  /// frame (WLED only pushes deltas — there's no "current state on connect").
  Future<WallState?> getState() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/json/state');
      final data = res.data;
      if (data == null) return null;
      return WallState.fromWledJson(data);
    } catch (_) {
      return null;
    }
  }

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
