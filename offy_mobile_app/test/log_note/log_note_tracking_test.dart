import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/data/models/log_note_model.dart';

void main() {
  group('LogNoteTrackingModel', () {
    test('formats a field change', () {
      final t = LogNoteTrackingModel.tryParse(
          {'field': 'Status', 'old_value': 'Draft', 'new_value': 'Submitted'});
      expect(t!.display, 'Status: Draft → Submitted');
    });

    test('handles a first-time value with no previous', () {
      final t = LogNoteTrackingModel.tryParse(
          {'field': 'Status', 'new_value': 'Submitted'});
      expect(t!.display, 'Status: Submitted');
    });

    test('renders booleans and numbers as text', () {
      expect(LogNoteTrackingModel.tryParse(
          {'field': 'Paid', 'new_value': true})!.display, 'Paid: Yes');
      expect(LogNoteTrackingModel.tryParse(
          {'field': 'Total', 'old_value': 10, 'new_value': 25.5})!.display,
          'Total: 10 → 25.5');
    });

    test('rejects rows with no field name', () {
      expect(LogNoteTrackingModel.tryParse({'old_value': 'a'}), isNull);
      expect(LogNoteTrackingModel.tryParse('nope'), isNull);
      expect(LogNoteTrackingModel.tryParse({'field': ''}), isNull);
    });
  });

  group('LogNoteModel', () {
    test('parses tracking and flags a body-less note', () {
      final m = LogNoteModel.fromJson({
        'id': 1,
        'author': {'name': 'OdooBot'},
        'message': '',
        'tracking': [
          {'field': 'Status', 'old_value': 'Draft', 'new_value': 'Submitted'},
          'garbage',
        ],
      });
      expect(m.tracking.length, 1);
      expect(m.isTrackingOnly, isTrue);
      expect(m.isEmpty, isFalse);
    });

    test('a note with neither body nor tracking is empty', () {
      final m = LogNoteModel.fromJson({'id': 2, 'message': ''});
      expect(m.isEmpty, isTrue);
      expect(m.isTrackingOnly, isFalse);
    });

    test('a typed comment is not tracking-only', () {
      final m = LogNoteModel.fromJson({'id': 3, 'message': 'Looks good'});
      expect(m.isTrackingOnly, isFalse);
      expect(m.isEmpty, isFalse);
    });
  });
}
