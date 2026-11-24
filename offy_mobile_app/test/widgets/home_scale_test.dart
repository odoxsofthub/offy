import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:office_app/presentation/widgets/home/home_scale.dart';

void main() {
  Future<void> withScreenUtil(WidgetTester tester, VoidCallback body) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(375, 812),
        builder: (context, child) => Builder(
          builder: (context) {
            body();
            return const SizedBox();
          },
        ),
      ),
    );
  }

  testWidgets('keeps full size when the content already fits', (tester) async {
    await withScreenUtil(tester, () {
      expect(HomeScale.fit(available: 2000, naturalHeight: 600).factor, 1);
    });
  });

  testWidgets('shrinks to fit the available height', (tester) async {
    await withScreenUtil(tester, () {
      final scale = HomeScale.fit(available: 400, naturalHeight: 600);
      expect(scale.factor, closeTo(400 / 600.h, 0.0001));
      expect(scale.factor, lessThan(1));
    });
  });

  testWidgets('never shrinks below the minimum factor', (tester) async {
    await withScreenUtil(tester, () {
      final scale = HomeScale.fit(available: 10, naturalHeight: 600);
      expect(scale.factor, HomeScale.minFactor);
    });
  });

  testWidgets('fonts shrink less than layout', (tester) async {
    await withScreenUtil(tester, () {
      const scale = HomeScale(HomeScale.minFactor);
      expect(scale.sp(10) / 10.sp, HomeScale.minFontFactor);
    });
  });
}
