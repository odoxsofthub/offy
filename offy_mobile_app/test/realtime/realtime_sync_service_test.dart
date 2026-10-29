import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/services/realtime_sync_service.dart';
import 'package:office_app/data/datasources/realtime_remote_data_source.dart';
import 'package:office_app/data/models/realtime_models.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Hands out a fixed ticket without touching the network.
class _FakeTicketSource implements RealtimeRemoteDataSource {
  _FakeTicketSource({this.throwOnFetch = false});

  final bool throwOnFetch;
  int calls = 0;

  @override
  Future<RealtimeTicketModel> fetchTicket() async {
    calls++;
    if (throwOnFetch) throw Exception('no ticket');
    return const RealtimeTicketModel(
      ticket: 'ticket-abc',
      expiresIn: 60,
      websocketPath: '/websocket',
      websocketVersion: '19.0-2',
    );
  }
}

class _FakeSink implements WebSocketSink {
  final List<Object?> sent = [];
  bool closed = false;

  @override
  void add(Object? data) => sent.add(data);

  @override
  Future<void> close([int? closeCode, String? closeReason]) async {
    closed = true;
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {}

  @override
  Future<void> addStream(Stream<Object?> stream) async {}

  @override
  Future<void> get done async {}
}

class _FakeChannel implements WebSocketChannel {
  _FakeChannel(this.uri, {this.readyError});

  final Uri uri;

  /// When set, the handshake is refused the way staging's 400 refuses it.
  final Object? readyError;
  final _controller = StreamController<dynamic>.broadcast();

  final _FakeSink fakeSink = _FakeSink();

  void emit(Object payload) => _controller.add(jsonEncode(payload));
  void emitRaw(String raw) => _controller.add(raw);
  void kill() => _controller.close();

  @override
  Stream<dynamic> get stream => _controller.stream;

  @override
  WebSocketSink get sink => fakeSink;

  @override
  Future<void> get ready =>
      readyError == null ? Future<void>.value() : Future<void>.error(readyError!);

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({'saved_login_url': 'http://example.com'});
    final sharedPreferences = await SharedPreferences.getInstance();
    GetIt.instance.registerSingleton<SharedPreferences>(sharedPreferences);
  });

  tearDownAll(() async {
    await GetIt.instance.reset();
  });

  late _FakeTicketSource source;
  late _FakeChannel channel;
  late RealtimeSyncService service;
  late Uri connectedUri;

  RealtimeSyncService build({
    _FakeTicketSource? src,
    List<Object?> readyErrors = const [],
  }) {
    source = src ?? _FakeTicketSource();
    var connects = 0;
    return RealtimeSyncService(
      dataSource: source,
      connector: (uri) {
        connectedUri = uri;
        final error = connects < readyErrors.length ? readyErrors[connects] : null;
        connects++;
        channel = _FakeChannel(uri, readyError: error);
        return channel;
      },
    );
  }

  tearDown(() async {
    await service.stop();
  });

  group('connection', () {
    test('carries the ticket and the server-supplied version', () async {
      service = build();
      await service.start();

      expect(connectedUri.queryParameters['ticket'], 'ticket-abc');
      expect(connectedUri.queryParameters['version'], '19.0-2',
          reason: 'a version mismatch makes Odoo close the socket cleanly');
      expect(connectedUri.path, '/websocket');
    });

    test('builds a clean ws:// URL with no stray fragment', () async {
      service = build();
      await service.start();

      expect(connectedUri.scheme, 'ws');
      expect(connectedUri.hasFragment, isFalse);
      expect(connectedUri.toString(), isNot(contains('#')));
    });

    test('sends the Origin header Odoo demands', () {
      final headers = realtimeHandshakeHeaders();
      expect(headers.containsKey('Origin'), isTrue);
      expect(headers['Origin'], isNotEmpty);
    });

    test('subscribes with an empty channel list and the last cursor', () async {
      service = build();
      await service.start();

      final sent = jsonDecode(channel.fakeSink.sent.single as String);
      expect(sent['event_name'], 'subscribe');
      expect(sent['data']['channels'], isEmpty);
      expect(sent['data']['last'], 0);
    });

    test('start is idempotent', () async {
      service = build();
      await service.start();
      await service.start();
      expect(source.calls, 1);
    });

    test('a refused handshake is handled, not reported as uncaught', () async {
      final uncaught = <Object>[];
      await runZonedGuarded(() async {
        service = build(readyErrors: [
          WebSocketChannelException('HTTP status code: 400'),
        ]);
        await service.start();
        await Future<void>.delayed(Duration.zero);
      }, (error, _) => uncaught.add(error));

      expect(uncaught, isEmpty,
          reason: 'main.dart records every uncaught error as a fatal crash');
      expect(service.isConnected, isFalse);
      expect(channel.fakeSink.sent, isEmpty,
          reason: 'nothing is sent on a socket that never opened');
    });

    test('a refused handshake is retried and the retry refetches', () async {
      service = build(readyErrors: [
        WebSocketChannelException('HTTP status code: 400'),
      ]);
      final received = <List<String>>[];
      final sub = service.staleSections.listen(received.add);
      await service.start();
      expect(service.isConnected, isFalse);

      await Future<void>.delayed(const Duration(milliseconds: 3500));
      await sub.cancel();

      expect(source.calls, 2, reason: 'one retry after the back-off');
      expect(service.isConnected, isTrue);
      expect(received, isNotEmpty);
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('a failed ticket fetch does not throw', () async {
      service = build(src: _FakeTicketSource(throwOnFetch: true));
      await service.start();
      expect(service.isConnected, isFalse);
    });
  });

  group('incoming messages', () {
    test('emits stale sections from a mobile_sync frame', () async {
      service = build();
      await service.start();

      final future = service.staleSections.first;
      channel.emit([
        {
          'id': 7,
          'message': {
            'type': 'mobile_sync',
            'payload': {
              'sections': ['attendance', 'activities'],
              'reason': 'attendance_checkin',
            },
          },
        }
      ]);

      expect(await future, ['attendance', 'activities']);
    });

    test('emits the inline payload from a mobile_access frame', () async {
      service = build();
      await service.start();

      final future = service.accessUpdates.first;
      channel.emit([
        {
          'id': 8,
          'message': {
            'type': 'mobile_access',
            'payload': {
              'reason': 'revoked',
              'access': {
                'user': {
                  'id': 1,
                  'name': 'A',
                  'login': 'a@b.c',
                  'active': true,
                  'mobile_user': false,
                },
              },
            },
          },
        }
      ]);

      final message = await future;
      expect(message.access!.user!.mobileUser, isFalse);
    });

    test('advances the last cursor to the highest id seen', () async {
      service = build();
      await service.start();

      channel.emit([
        {'id': 3, 'message': {'type': 'mobile_sync', 'payload': {'sections': ['expense']}}},
        {'id': 11, 'message': {'type': 'mobile_sync', 'payload': {'sections': ['payslip']}}},
        {'id': 9, 'message': {'type': 'mobile_sync', 'payload': {'sections': ['calendar']}}},
      ]);
      await Future<void>.delayed(Duration.zero);

      expect(service.lastId, 11, reason: 'the cursor must never go backwards');
    });

    test('one malformed entry does not discard the rest of the batch', () async {
      service = build();
      await service.start();

      final received = <List<String>>[];
      final sub = service.staleSections.listen(received.add);

      channel.emit([
        {'id': 'bad', 'message': null},
        {'id': 5, 'message': {'type': 'mobile_sync', 'payload': {'sections': ['expense']}}},
      ]);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, [
        ['expense']
      ]);
      expect(service.lastId, 5);
    });

    test('unparseable frames are ignored', () async {
      service = build();
      await service.start();

      final received = <List<String>>[];
      final sub = service.staleSections.listen(received.add);

      channel.emitRaw('}{ not json');
      channel.emitRaw('"a string, not a list"');
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, isEmpty);
      expect(service.lastId, 0);
    });

    test('unknown notification types are ignored', () async {
      service = build();
      await service.start();

      final received = <List<String>>[];
      final sub = service.staleSections.listen(received.add);

      channel.emit([
        {'id': 2, 'message': {'type': 'mail.message/insert', 'payload': {}}},
      ]);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, isEmpty);
      expect(service.lastId, 2,
          reason: 'the cursor still advances past foreign traffic');
    });

    test('a sync frame with no sections emits nothing', () async {
      service = build();
      await service.start();

      final received = <List<String>>[];
      final sub = service.staleSections.listen(received.add);

      channel.emit([
        {'id': 6, 'message': {'type': 'mobile_sync', 'payload': {'sections': []}}},
      ]);
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, isEmpty);
    });
  });

  group('lifecycle', () {
    test('stop closes the socket and prevents reconnection', () async {
      service = build();
      await service.start();
      await service.stop();

      expect(service.isConnected, isFalse);
      expect(channel.fakeSink.closed, isTrue);
    });

    test('the first connect does not force a full refetch', () async {
      service = build();
      final received = <List<String>>[];
      final sub = service.staleSections.listen(received.add);
      await service.start();
      await Future<void>.delayed(Duration.zero);
      await sub.cancel();

      expect(received, isEmpty);
    });

    test('a reconnect refetches every section', () async {
      service = build();
      await service.start();

      final received = <List<String>>[];
      final sub = service.staleSections.listen(received.add);

      channel.kill();
      await Future<void>.delayed(const Duration(milliseconds: 3500));
      await sub.cancel();

      expect(received, isNotEmpty);
      expect(
        received.first,
        containsAll(<String>['attendance', 'time_off', 'expense', 'calendar']),
      );
    }, timeout: const Timeout(Duration(seconds: 15)));

    test('a drop after stop does not reconnect', () async {
      service = build();
      await service.start();
      await service.stop();
      final callsAfterStop = source.calls;

      channel.kill();
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(source.calls, callsAfterStop);
    });
  });
}
