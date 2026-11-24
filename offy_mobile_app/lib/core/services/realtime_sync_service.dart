import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../data/datasources/realtime_remote_data_source.dart';
import '../../data/models/realtime_models.dart';
import '../constants/api_constants.dart';
import '../constants/app_globals.dart';

/// Signature for opening a socket. Injectable so tests can supply a fake
/// without touching the network.
typedef WebSocketConnector = WebSocketChannel Function(Uri uri);

/// Headers required for the websocket handshake.
Map<String, dynamic> realtimeHandshakeHeaders() => {
      'Origin': ApiConstants.wsOrigin,
    };

/// Opens the socket with those headers.
WebSocketChannel _defaultConnector(Uri uri) {
  return IOWebSocketChannel.connect(
    uri,
    headers: realtimeHandshakeHeaders(),
    pingInterval: const Duration(seconds: 30),
  );
}

/// Keeps the app's permissions and home data synchronized in real-time.
class RealtimeSyncService {
  RealtimeSyncService({
    required this.dataSource,
    WebSocketConnector? connector,
  }) : _connect = connector ?? _defaultConnector;

  final RealtimeRemoteDataSource dataSource;
  final WebSocketConnector _connect;

  WebSocketChannel? _channel;
  StreamSubscription<dynamic>? _subscription;
  Timer? _reconnectTimer;

  bool _started = false;
  bool _connecting = false;
  int _attempt = 0;

  int _lastId = 0;
  int get lastId => _lastId;

  bool get isConnected => _channel != null;

  /// Emitted with the stale section names from a `mobile_sync` message.
  final _sections = StreamController<List<String>>.broadcast();
  Stream<List<String>> get staleSections => _sections.stream;

  /// Emitted with the inline payload from a `mobile_access` message.
  final _access = StreamController<RealtimeMessage>.broadcast();
  Stream<RealtimeMessage> get accessUpdates => _access.stream;

  static const Duration _staleCursorAfter = Duration(hours: 20);
  DateTime? _lastMessageAt;

  // --- Lifecycle ---
  Future<void> start() async {
    if (_started || AppGlobals.isDesignMode) return;
    _started = true;
    await _open();
  }

  /// Called when the app returns from background to ensure the socket is alive.
  Future<void> syncOnResume() async {
    if (!_started || AppGlobals.isDesignMode) return;
    if (_channel == null) {
      debugPrint('RealtimeSyncService: Reopening socket after app resumed');
      await _open();
    } else {
      // Re-send subscription with _lastId to catch up on missed frames or detect a dead connection
      try {
        _sendSubscribe();
      } catch (_) {
        await _teardown();
        await _open();
      }
    }
  }

  Future<void> stop() async {
    _started = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _teardown();
    _attempt = 0;
  }

  Future<void> _teardown() async {
    await _subscription?.cancel();
    _subscription = null;
    try {
      await _channel?.sink.close();
    } catch (e) {
      // Closing an already-dead socket is expected and safe to ignore.
      debugPrint('RealtimeSyncService: Ignored socket close exception during teardown: $e');
    }
    _channel = null;
  }

  Future<void> _open() async {
    if (!_started || _connecting || _channel != null || AppGlobals.isDesignMode) return;
    _connecting = true;
    try {
      final ticket = await dataSource.fetchTicket();
      if (!_started || AppGlobals.isDesignMode) return;

      final uri = _buildUri(ticket);
      WebSocketChannel channel;
      try {
        channel = _connect(uri);
        // A refused handshake is reported only through `ready`; left unawaited
        // it escapes as an uncaught error and Crashlytics logs it as fatal.
        await channel.ready;
      } catch (e) {
        debugPrint('RealtimeSyncService: websocket handshake failed — $e');
        await _teardown();
        _scheduleReconnect();
        return;
      }
      _channel = channel;
      if (!_started || AppGlobals.isDesignMode) {
        await _teardown();
        return;
      }

      _subscription = channel.stream.listen(
        _onFrame,
        onError: (Object error) => _onDisconnected('error: $error'),
        onDone: () => _onDisconnected('closed'),
        cancelOnError: true,
      );

      _sendSubscribe();

      if (_attempt > 0) {
        _sections.add(const [
          'attendance', 'time_off', 'expense', 'payslip', 'calendar',
          'activities',
        ]);
      }

      _attempt = 0;
    } catch (e) {
      debugPrint('RealtimeSyncService: connect failed — $e');
      await _teardown();
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Uri _buildUri(RealtimeTicketModel ticket) {
    final base = Uri.parse(ApiConstants.baseUrl);
    return Uri(
      scheme: base.scheme == 'https' ? 'wss' : 'ws',
      host: base.host,
      port: base.hasPort ? base.port : null,
      path: ticket.websocketPath,
      queryParameters: {
        'ticket': ticket.ticket,
        if (ticket.websocketVersion.isNotEmpty)
          'version': ticket.websocketVersion,
      },
    );
  }

  void _sendSubscribe() {
    _send({
      'event_name': 'subscribe',
      'data': {'channels': <String>[], 'last': _lastId},
    });
  }

  void _send(Map<String, dynamic> message) {
    try {
      _channel?.sink.add(jsonEncode(message));
    } catch (e) {
      debugPrint('RealtimeSyncService: send failed — $e');
    }
  }

  // --- Incoming frames ---
  void _onFrame(dynamic frame) {
    if (frame is! String) return;
    dynamic decoded;
    try {
      decoded = jsonDecode(frame);
    } catch (_) {
      debugPrint('RealtimeSyncService: dropped unparseable frame');
      return;
    }
    if (decoded is! List) return;

    for (final entry in decoded) {
      final message = RealtimeMessage.tryParse(entry);
      if (message == null) continue;
      if (message.id > _lastId) _lastId = message.id;
      _lastMessageAt = DateTime.now();
      _dispatch(message);
    }
  }

  void _dispatch(RealtimeMessage message) {
    switch (message.type) {
      case RealtimeTypes.sync:
        final sections = message.sections;
        if (sections.isNotEmpty) _sections.add(sections);
        break;
      case RealtimeTypes.access:
        _access.add(message);
        break;
      default:
        break;
    }
  }

  // --- Reconnection ---
  void _onDisconnected(String reason) {
    debugPrint('RealtimeSyncService: disconnected ($reason)');
    _teardown();
    if (_started && !AppGlobals.isDesignMode) _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (!_started || AppGlobals.isDesignMode) return;
    _reconnectTimer?.cancel();
    _attempt = min(_attempt + 1, 6);
    final base = pow(2, _attempt).toInt();
    final jitter = Random().nextInt(1000);
    final delay = Duration(
      milliseconds: min(base * 1000, 60000) + jitter,
    );

    if (_lastMessageAt != null &&
        DateTime.now().difference(_lastMessageAt!) > _staleCursorAfter) {
      _lastId = 0;
      _lastMessageAt = null;
      _sections.add(const ['attendance', 'time_off', 'expense', 'payslip',
          'calendar', 'activities']);
    }

    _reconnectTimer = Timer(delay, _open);
  }

  Future<void> dispose() async {
    await stop();
    await _sections.close();
    await _access.close();
  }
}
