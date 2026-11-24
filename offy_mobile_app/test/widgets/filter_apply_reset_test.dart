import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/presentation/viewmodels/time_off/time_off_provider.dart';
import 'package:office_app/presentation/widgets/common/filter/app_filter_action_bar.dart';

/// Filters only take effect on Apply: back restores the applied snapshot, Reset clears the draft.
void main() {
  group('TimeOffFilterState', () {
    TimeOffFilterState applied() {
      final state = TimeOffFilterState();
      state.selectedTypeIds.add(1);
      state.selectedStatusIds.add('validate');
      state.selectedMonthIds.add('2026-09');
      state.isMonthActive = true;
      state.snapshotAppliedFilters();
      return state;
    }

    test('ticks then back: restoreAppliedFilters undoes every change', () {
      final state = applied();
      state.selectedTypeIds.add(2);
      state.selectedStatusIds.clear();
      state.selectedMonthIds.add('2026-08');
      state.isCustomRangeActive = true;
      state.selectedDateRange = DateTimeRange(
        start: DateTime(2026, 9, 1),
        end: DateTime(2026, 9, 5),
      );
      expect(state.hasFilterChanges, isTrue);

      state.restoreAppliedFilters();

      expect(state.hasFilterChanges, isFalse);
      expect(state.selectedTypeIds, {1});
      expect(state.selectedStatusIds, {'validate'});
      expect(state.selectedMonthIds, {'2026-09'});
      expect(state.isCustomRangeActive, isFalse);
      expect(state.selectedDateRange, isNull);
    });

    test('Reset clears the draft but keeps the applied snapshot for Apply', () {
      final state = applied();
      state.clearSelections();

      expect(state.selectedTypeIds, isEmpty);
      expect(state.selectedStatusIds, isEmpty);
      expect(state.selectedMonthIds, isEmpty);
      expect(state.isMonthActive, isFalse);
      expect(state.hasFilterChanges, isTrue, reason: 'Apply must still send it');

      state.restoreAppliedFilters();
      expect(state.selectedTypeIds, {1}, reason: 'Reset then back = no change');
    });
  });

  group('AppFilterActionBar', () {
    Future<void> pump(
      WidgetTester tester, {
      required VoidCallback onReset,
      required VoidCallback onApply,
      bool busy = false,
    }) {
      return tester.pumpWidget(
        ScreenUtilInit(
          designSize: const Size(375, 812),
          builder: (_, _) => MaterialApp(
            home: Scaffold(
              body: AppFilterActionBar(
                onReset: onReset,
                onPrimary: onApply,
                isBusy: busy,
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('Reset and Apply call their own callbacks', (tester) async {
      var resets = 0, applies = 0;
      await pump(tester, onReset: () => resets++, onApply: () => applies++);

      await tester.tap(find.text('Reset'));
      await tester.tap(find.text('Apply'));

      expect(resets, 1);
      expect(applies, 1);
    });

    testWidgets('while applying, both buttons are disabled', (tester) async {
      var taps = 0;
      await pump(tester, onReset: () => taps++, onApply: () => taps++, busy: true);

      await tester.tap(find.text('Reset'));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(taps, 0);
    });
  });
}
