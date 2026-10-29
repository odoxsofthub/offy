import 'access_details_response_model.dart';

/// Notification type strings sent by `mobile.sync.service` on the Odoo bus.
class RealtimeTypes {
  const RealtimeTypes._();

  /// Home sections went stale — refetch them.
  static const String sync = 'mobile_sync';

  /// Full permission payload, applied immediately.
  static const String access = 'mobile_access';
}

/// The short-lived credential that opens a websocket.
class RealtimeTicketModel {
  final String ticket;
  final int expiresIn;
  final String websocketPath;

  final String websocketVersion;

  const RealtimeTicketModel({
    required this.ticket,
    required this.expiresIn,
    required this.websocketPath,
    required this.websocketVersion,
  });

  factory RealtimeTicketModel.fromJson(Map<String, dynamic> json) {
    return RealtimeTicketModel(
      ticket: json['ticket'] as String? ?? '',
      expiresIn: json['expires_in'] as int? ?? 60,
      websocketPath: json['websocket_path'] as String? ?? '/websocket',
      websocketVersion: json['websocket_version'] as String? ?? '',
    );
  }
}

/// One entry from the JSON array pushed down the socket.
class RealtimeMessage {
  final int id;
  final String type;
  final Map<String, dynamic> payload;

  const RealtimeMessage({
    required this.id,
    required this.type,
    required this.payload,
  });

  static RealtimeMessage? tryParse(dynamic entry) {
    if (entry is! Map) return null;
    final id = entry['id'];
    final message = entry['message'];
    if (id is! int || message is! Map) return null;
    final type = message['type'];
    if (type is! String) return null;
    final payload = message['payload'];
    return RealtimeMessage(
      id: id,
      type: type,
      payload: payload is Map
          ? Map<String, dynamic>.from(payload)
          : <String, dynamic>{},
    );
  }

  /// Home sections named by a `mobile_sync` message.
  List<String> get sections {
    final raw = payload['sections'];
    if (raw is! List) return const [];
    return raw.whereType<String>().toList();
  }

  String get reason => payload['reason'] as String? ?? '';

  /// The access-details body carried inline by a `mobile_access` message.
  AccessDetailsResponseModel? get access {
    final raw = payload['access'];
    if (raw is! Map) return null;
    return AccessDetailsResponseModel.fromJson(
      Map<String, dynamic>.from(raw),
    );
  }
}
