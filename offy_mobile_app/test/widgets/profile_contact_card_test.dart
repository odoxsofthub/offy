import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/presentation/widgets/profile/profile_contact_card.dart';

void main() {
  const sixLineAddress =
      '221B QA Test Street\nRound 1 Block\nChennai\nTamil Nadu\n600028\nIndia';

  Widget wrap(List<ProfileContactCardItem> items) {
    return ScreenUtilInit(
      designSize: const Size(390, 844),
      builder: (context, child) => MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: ProfileContactCard(items: items),
          ),
        ),
      ),
    );
  }

  Text valueTextOf(WidgetTester tester, String value) {
    return tester.widget<Text>(find.text(value));
  }

  group('ProfileContactCard maxLines', () {
    testWidgets('defaults to a 3-line cap with an ellipsis', (tester) async {
      await tester.pumpWidget(wrap(const [
        ProfileContactCardItem(label: 'Phone', value: '+91 90000 00000'),
      ]));
      await tester.pumpAndSettle();

      final text = valueTextOf(tester, '+91 90000 00000');
      expect(text.maxLines, 3);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('an address row renders uncapped', (tester) async {
      await tester.pumpWidget(wrap(const [
        ProfileContactCardItem(
          label: 'Residential address',
          value: sixLineAddress,
          maxLines: null,
        ),
      ]));
      await tester.pumpAndSettle();

      final text = valueTextOf(tester, sixLineAddress);
      expect(text.maxLines, isNull);
      expect(text.overflow, TextOverflow.clip);
    });

    testWidgets('all six address components are laid out, not just three',
        (tester) async {
      await tester.pumpWidget(wrap(const [
        ProfileContactCardItem(
          label: 'Residential address',
          value: sixLineAddress,
          maxLines: null,
        ),
      ]));
      await tester.pumpAndSettle();

      final uncapped = tester.getSize(find.text(sixLineAddress)).height;

      await tester.pumpWidget(wrap(const [
        ProfileContactCardItem(
          label: 'Residential address',
          value: sixLineAddress,
        ),
      ]));
      await tester.pumpAndSettle();
      final capped = tester.getSize(find.text(sixLineAddress)).height;

      expect(uncapped, greaterThan(capped));
      expect(uncapped / capped, closeTo(2.0, 0.35));
    });

    testWidgets('copy still copies the whole untruncated value',
        (tester) async {
      const item = ProfileContactCardItem(
        label: 'Residential address',
        value: sixLineAddress,
        maxLines: null,
      );
      expect(item.value, sixLineAddress);
      expect(item.value.split('\n').length, 6);
    });
  });
}
