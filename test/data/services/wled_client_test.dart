import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:living_wall_app/data/services/wled_client.dart';

/// Captures every HTTP call made through Dio so we can assert on the
/// payload structure. We bypass the network entirely — a 200 OK with an
/// empty JSON body keeps the client happy without a real WLED to talk to.
class _CapturingAdapter implements HttpClientAdapter {
  final List<({String path, Map<String, dynamic> body})> calls = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    Map<String, dynamic> decoded = const {};
    if (requestStream != null) {
      final bytes = await requestStream
          .fold<BytesBuilder>(BytesBuilder(), (b, chunk) => b..add(chunk));
      final raw = utf8.decode(bytes.toBytes());
      if (raw.isNotEmpty) {
        decoded = jsonDecode(raw) as Map<String, dynamic>;
      }
    }
    calls.add((path: options.path, body: decoded));
    return ResponseBody.fromString(
      '{}',
      200,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

WledClient _clientWith(_CapturingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'http://192.168.1.50'));
  dio.httpClientAdapter = adapter;
  return WledClient(baseUrl: 'http://192.168.1.50', dio: dio);
}

void main() {
  group('WledClient.configureMatrix', () {
    test('POSTs to /json/cfg with matrix + udpn batched in one call', () async {
      final adapter = _CapturingAdapter();
      final client = _clientWith(adapter);

      await client.configureMatrix(gridWidth: 72, gridHeight: 48);

      expect(adapter.calls, hasLength(1));
      expect(adapter.calls.single.path, '/json/cfg');
    });

    test('matrix payload uses WLED 0.14+ panel schema with serpentine',
        () async {
      final adapter = _CapturingAdapter();
      final client = _clientWith(adapter);

      await client.configureMatrix(gridWidth: 72, gridHeight: 48);

      final body = adapter.calls.single.body;
      final matrix = (body['hw'] as Map)['led']['matrix'] as Map;
      expect(matrix['mpc'], 1);
      final panels = matrix['panels'] as List;
      expect(panels, hasLength(1));
      final panel = panels.single as Map;
      // Production convention: bottom-left origin, row-major, serpentine.
      expect(panel['b'], isTrue, reason: 'bottom-start');
      expect(panel['r'], isFalse, reason: 'left-start (not right)');
      expect(panel['v'], isFalse, reason: 'row-major (not vertical)');
      expect(panel['s'], isTrue, reason: 'serpentine zigzag');
      expect(panel['x'], 0);
      expect(panel['y'], 0);
      expect(panel['w'], 72);
      expect(panel['h'], 48);
    });

    test('batches UDP sync send + recv flags into the same /json/cfg call', () async {
      final adapter = _CapturingAdapter();
      final client = _clientWith(adapter);

      await client.configureMatrix(gridWidth: 108, gridHeight: 72);

      final body = adapter.calls.single.body;
      final sync = (body['if'] as Map)['sync'] as Map;
      // send.en is what WLED actually reads from /json/cfg — a bare bool
      // would silently no-op.
      expect((sync['send'] as Map)['en'], isTrue);
      final recv = sync['recv'] as Map;
      expect(recv['bri'], isTrue);
      expect(recv['col'], isTrue);
      expect(recv['fx'], isTrue);
      expect(recv['pal'], isTrue);
    });

    test('different grid dims produce different panel w/h', () async {
      final adapter = _CapturingAdapter();
      final client = _clientWith(adapter);

      await client.configureMatrix(gridWidth: 144, gridHeight: 96);

      final panel =
          (((adapter.calls.single.body['hw'] as Map)['led']
                  as Map)['matrix'] as Map)['panels'][0] as Map;
      expect(panel['w'], 144);
      expect(panel['h'], 96);
    });
  });

  group('WledClient.setSyncEnabled', () {
    test('disabling sync sends false on all recv flags', () async {
      final adapter = _CapturingAdapter();
      final client = _clientWith(adapter);

      await client.setSyncEnabled(send: false, recv: false);

      final body = adapter.calls.single.body;
      final sync = (body['if'] as Map)['sync'] as Map;
      expect((sync['send'] as Map)['en'], isFalse);
      final recv = sync['recv'] as Map;
      expect(recv['bri'], isFalse);
      expect(recv['col'], isFalse);
      expect(recv['fx'], isFalse);
      expect(recv['pal'], isFalse);
    });

    test('enabling sync sends true', () async {
      final adapter = _CapturingAdapter();
      final client = _clientWith(adapter);

      await client.setSyncEnabled(send: true, recv: true);

      final sync = (adapter.calls.single.body['if'] as Map)['sync'] as Map;
      expect((sync['send'] as Map)['en'], isTrue);
      expect((sync['recv'] as Map)['bri'], isTrue);
    });
  });
}
