import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:office_app/core/theme/app_colors.dart';
import 'package:google_fonts/google_fonts.dart';
import 'navigation_item.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onItemSelected;
  final Color backgroundColor;
  final List<NavigationItemData> items;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onItemSelected,
    this.backgroundColor = AppColors.light,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    // Measure navigation bar labels at maximum font settings with a safety margin
    double minScale = 1.0;
    for (var item in items) {
      final textPainter = TextPainter(
        text: TextSpan(
          text: item.label,
          style: GoogleFonts.urbanist(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();

      final maxAllowedWidth = 70.w - 6.w;
      if (textPainter.width > maxAllowedWidth) {
        final scale = maxAllowedWidth / textPainter.width;
        if (scale < minScale) {
          minScale = scale;
        }
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? null
            : backgroundColor,
        gradient: Theme.of(context).brightness == Brightness.dark
            ? const LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [Color(0xFF170D04), Color(0xFF2F1A06)],
              )
            : null,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(12.r),
          topRight: Radius.circular(12.r),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0x40000000), // #00000040
            blurRadius: 14.r,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            top: 16.h,
            right: 15.w,
            bottom: 10.h,
            left: 15.w,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(items.length, (index) {
              final item = items[index];
              return Expanded(
                child: NavigationItemWidget(
                  selectedAsset: item.selectedAsset,
                  unselectedAsset: item.unselectedAsset,
                  label: item.label,
                  isSelected: currentIndex == index,
                  onTap: () => onItemSelected(index),
                  scale: minScale,
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}
