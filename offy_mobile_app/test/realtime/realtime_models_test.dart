import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/data/models/realtime_models.dart';

void main() {
  group('RealtimeMessage.tryParse', () {
    test('parses the Odoo bus envelope', () {
      final message = RealtimeMessage.tryParse({
        'id': 42,
        'message': {
          'type': 'mobile_sync',
          'payload': {
            'sections': ['attendance', 'activities'],
            'reason': 'attendance_checkin',
          },
        },
      });

      expect(message, isNotNull);
      expect(message!.id, 42);
      expect(message.type, 'mobile_sync');
      expect(message.sections, ['attendance', 'activities']);
      expect(message.reason, 'attendance_checkin');
    });

    test('returns null for malformed envelopes instead of throwing', () {
      expect(RealtimeMessage.tryParse(null), isNull);
      expect(RealtimeMessage.tryParse('not a map'), isNull);
      expect(RealtimeMessage.tryParse({'id': 'nope', 'message': {}}), isNull);
      expect(RealtimeMessage.tryParse({'id': 1}), isNull);
      expect(RealtimeMessage.tryParse({'id': 1, 'message': {'type': 7}}), isNull);
    });

    test('tolerates a missing payload', () {
      final message = RealtimeMessage.tryParse({
        'id': 3,
        'message': {'type': 'mobile_sync'},
      });
      expect(message, isNotNull);
      expect(message!.sections, isEmpty);
      expect(message.reason, '');
    });

    test('drops non-string entries from sections', () {
      final message = RealtimeMessage.tryParse({
        'id': 4,
        'message': {
          'type': 'mobile_sync',
          'payload': {
            'sections': ['attendance', 7, null],
          },
        },
      });
      expect(message!.sections, ['attendance']);
    });

    test('decodes the inline access payload', () {
      final message = RealtimeMessage.tryParse({
        'id': 9,
        'message': {
          'type': 'mobile_access',
          'payload': {
            'reason': 'feature_access_revoked',
            'access': {
              'user': {
                'id': 5,
                'name': 'Test',
                'login': 't@x.com',
                'active': true,
                'mobile_user': false,
              },
              'features': [
                {'code': 'attendance', 'name': 'Attendance', 'active': true},
              ],
            },
          },
        },
      });

      final access = message!.access;
      expect(access, isNotNull);
      expect(access!.user!.id, 5);
      expect(access.user!.mobileUser, isFalse,
          reason: 'revocation must be visible to the app');
      expect(access.features!.single.code, 'attendance');
    });

    test('access is null when the payload carries none', () {
      final message = RealtimeMessage.tryParse({
        'id': 10,
        'message': {'type': 'mobile_access', 'payload': {'reason': 'x'}},
      });
      expect(message!.access, isNull);
    });
  });

  group('RealtimeTicketModel', () {
    test('parses a ticket response', () {
      final ticket = RealtimeTicketModel.fromJson({
        'ticket': 'abc123',
        'expires_in': 60,
        'websocket_path': '/websocket',
        'websocket_version': '19.0-2',
      });
      expect(ticket.ticket, 'abc123');
      expect(ticket.expiresIn, 60);
      expect(ticket.websocketVersion, '19.0-2');
    });

    test('falls back sanely on a partial response', () {
      final ticket = RealtimeTicketModel.fromJson({'ticket': 'x'});
      expect(ticket.expiresIn, 60);
      expect(ticket.websocketPath, '/websocket');
      expect(ticket.websocketVersion, '');
    });
  });
}
