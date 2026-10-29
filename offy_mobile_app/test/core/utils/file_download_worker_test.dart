import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/core/utils/file_download_worker.dart';

void main() {
  group('FileDownloadWorker.safeFileName', () {
    test('keeps a plain name', () {
      expect(FileDownloadWorker.safeFileName('Payslip Oct.pdf', 'f.pdf'), 'Payslip Oct.pdf');
    });

    test('turns path separators into a single name', () {
      expect(FileDownloadWorker.safeFileName('../../etc/passwd', 'f'), '.._.._etc_passwd');
      expect(FileDownloadWorker.safeFileName(r'..\..\x.pdf', 'f'), '.._.._x.pdf');
      expect(FileDownloadWorker.safeFileName('Report 2026/10.pdf', 'f'), 'Report 2026_10.pdf');
    });

    test('falls back for empty, dot or control-only names', () {
      for (final name in [null, '', '  ', '.', '..', '\u0000']) {
        expect(FileDownloadWorker.safeFileName(name, 'fallback.pdf'), 'fallback.pdf');
      }
    });
  });
}
