import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/theme/app_colors.dart';

class DayCell extends StatefulWidget {
  final int day;
  final bool isCurrentMonth;
  final bool isSelected;
  final List<Color>? events;
  final VoidCallback? onTap;
  final List<String>? tooltipTitles;
  final List<String>? tooltipSubtitles;
  final bool? isBottomRow;
  final bool? showTooltip;
  final bool? isToday;
  final VoidCallback? onTooltipDismissed;
  final bool hasTooltipError;
  final VoidCallback? onTooltipRetry;

  const DayCell({
    super.key,
    required this.day,
    required this.isCurrentMonth,
    required this.isSelected,
    this.events,
    this.onTap,
    this.tooltipTitles,
    this.tooltipSubtitles,
    this.isBottomRow,
    this.showTooltip,
    this.isToday,
    this.onTooltipDismissed,
    this.hasTooltipError = false,
    this.onTooltipRetry,
  });

  @override
  State<DayCell> createState() => _DayCellState();
}

class _DayCellState extends State<DayCell> with SingleTickerProviderStateMixin {
  static OverlayEntry? _activeGlobalOverlay;
  static VoidCallback? _activeGlobalDismiss;

  static void _dismissActiveGlobalTooltip() {
    _activeGlobalDismiss?.call();
    _activeGlobalDismiss = null;
    if (_activeGlobalOverlay != null) {
      _activeGlobalOverlay!.remove();
      _activeGlobalOverlay = null;
    }
  }

  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _overlayEntry;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _toggleTooltip();
    });
  }

  @override
  void didUpdateWidget(covariant DayCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showTooltip != widget.showTooltip ||
        oldWidget.isSelected != widget.isSelected ||
        oldWidget.tooltipTitles != widget.tooltipTitles ||
        oldWidget.tooltipSubtitles != widget.tooltipSubtitles ||
        oldWidget.hasTooltipError != widget.hasTooltipError) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _toggleTooltip();
      });
    }
  }

  @override
  void dispose() {
    _hideTooltipImmediate();
    _animationController.dispose();
    super.dispose();
  }

  void _toggleTooltip() {
    if (!mounted) return;
    final bool hasEvents = widget.events != null && widget.events!.isNotEmpty;
    if (widget.isSelected && widget.showTooltip == true && hasEvents) {
      _showTooltip();
    } else {
      _hideTooltipAnimated();
    }
  }

  void _showTooltip() {
    if (!mounted) return;
    _dismissActiveGlobalTooltip();
    _hideTooltipImmediate(); // clear instantly if any is lingering

    final renderBox = context.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final cellOffset = renderBox.localToGlobal(Offset.zero);
    final double cellWidth = renderBox.size.width;
    final double cellCenter = cellOffset.dx + cellWidth / 2;

    final double screenWidth = MediaQuery.of(context).size.width;
    final double calendarLeft = 28.w;
    final double calendarRight = screenWidth - 28.w;
    final double tooltipWidth = 137.w;

    final double idealLeft = cellCenter - tooltipWidth / 2;
    final double tooltipLeft = idealLeft.clamp(
      calendarLeft,
      calendarRight - tooltipWidth,
    );

    final double offsetDx = tooltipLeft - idealLeft;
    final double radius = 10.r;
    final double arrowWidth = 18.w;
    final double arrowCenter = (cellCenter - tooltipLeft).clamp(
      radius + arrowWidth / 2,
      tooltipWidth - radius - arrowWidth / 2,
    );

    final bool isBottomRow = widget.isBottomRow ?? false;

    final overlayState = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (context) {
        return Positioned(
          width: tooltipWidth,
          child: CompositedTransformFollower(
            link: _layerLink,
            showWhenUnlinked: false,
            targetAnchor: isBottomRow
                ? Alignment.topCenter
                : Alignment.bottomCenter,
            followerAnchor: isBottomRow
                ? Alignment.bottomCenter
                : Alignment.topCenter,
            offset: Offset(offsetDx, isBottomRow ? 2.h : -2.h),
            child: TapRegion(
              onTapOutside: (event) {
                _hideTooltipAnimated();
                widget.onTooltipDismissed?.call();
              },
              child: FadeTransition(
                opacity: _animationController,
                child: Material(
                  color: Colors.transparent,
                  child: BalloonTooltip(
                    titles: widget.tooltipTitles ?? [],
                    subtitles: widget.tooltipSubtitles ?? [],
                    eventColors: widget.events,
                    arrowCenter: arrowCenter,
                    isBottomRow: isBottomRow,
                    hasError: widget.hasTooltipError,
                    onRetry: widget.onTooltipRetry,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (!mounted) return;
    setState(() {
      _overlayEntry = entry;
      _activeGlobalOverlay = entry;
      _activeGlobalDismiss = () => _hideTooltipImmediate();
    });

    overlayState.insert(entry);
    _animationController.forward();
  }

  void _hideTooltipAnimated() {
    if (_overlayEntry != null &&
        !_animationController.isAnimating &&
        _animationController.status != AnimationStatus.dismissed) {
      _animationController.reverse().then((_) {
        if (!mounted) return;
        _hideTooltipImmediate();
      });
    }
  }

  void _hideTooltipImmediate() {
    if (_activeGlobalOverlay == _overlayEntry) {
      _activeGlobalOverlay = null;
      _activeGlobalDismiss = null;
    }
    if (_overlayEntry != null) {
      _overlayEntry!.remove();
      _overlayEntry = null;
    }
    _animationController.reset();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dayEvents = widget.events;

    Color textColor;
    if (widget.isSelected) {
      textColor = AppColors.white;
    } else if (widget.isCurrentMonth) {
      textColor = isDark ? AppColors.white : AppColors.black;
    } else {
      textColor = isDark
          ? AppColors.white.withValues(alpha: 0.25)
          : const Color(0xEAE4BEB4).withValues(alpha: 0.4);
    }

    final bool showDateDots =
        dayEvents != null && dayEvents.isNotEmpty && !widget.isSelected;

    Widget cellContent = Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (widget.isSelected)
            Container(
              width: 41.58.r,
              height: 41.58.r,
              decoration: const BoxDecoration(
                color: Color(0xFFFF5722),
                shape: BoxShape.circle,
              ),
            )
          else if (widget.isToday == true)
            Container(
              width: 41.58.r,
              height: 41.58.r,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFFFF5722),
                  width: 1.5.w,
                ),
              ),
            ),
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (showDateDots) SizedBox(height: 6.23.h),
              Text(
                widget.day.toString(),
                style: GoogleFonts.inter(
                  fontSize: 14.sp,
                  fontWeight: widget.isSelected
                      ? FontWeight.w600
                      : FontWeight.w400,
                  height: 21 / 14,
                  color: textColor,
                ),
              ),
              if (showDateDots) ...[
                SizedBox(height: 2.h),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: dayEvents.take(3).map((color) {
                    return Container(
                      width: widget.isSelected ? 6.23.w : 4.23.w,
                      height: widget.isSelected ? 6.23.h : 4.23.h,
                      margin: EdgeInsets.symmetric(horizontal: 1.w),
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: widget.isSelected
                            ? Border.all(color: Colors.white, width: 1.w)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ],
      ),
    );

    return CompositedTransformTarget(
      link: _layerLink,
      child: GestureDetector(
        onTap: widget.onTap,
        behavior: HitTestBehavior.opaque,
        child: cellContent,
      ),
    );
  }
}

class BalloonTooltip extends StatefulWidget {
  final List<String> titles;
  final List<String> subtitles;
  final List<Color>? eventColors;
  final double arrowCenter;
  final bool isBottomRow;
  final bool hasError;
  final VoidCallback? onRetry;

  const BalloonTooltip({
    super.key,
    required this.titles,
    required this.subtitles,
    this.eventColors,
    required this.arrowCenter,
    required this.isBottomRow,
    this.hasError = false,
    this.onRetry,
  });

  @override
  State<BalloonTooltip> createState() => _BalloonTooltipState();
}

class _BalloonTooltipState extends State<BalloonTooltip> {
  late PageController _pageController;
  int _currentPage = 0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget _buildTitle(String title) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minScale = 14.sp / 18.sp;
        final maxChildWidth = constraints.maxWidth > 0
            ? constraints.maxWidth / minScale
            : double.infinity;

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxChildWidth),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 18.sp,
                fontWeight: FontWeight.w600,
                height: 24 / 18,
                color: AppColors.black,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubtitle(String subtitle) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final minScale = 12.sp / 14.sp;
        final maxChildWidth = constraints.maxWidth > 0
            ? constraints.maxWidth / minScale
            : double.infinity;

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxChildWidth),
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w400,
                height: 24 / 14,
                color: AppColors.secondary,
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double arrowHeight = 12.h;
    final bool hasMultiple = widget.titles.length > 1;

    Widget content;
    if (widget.hasError) {
      content = Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onRetry,
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8.h, horizontal: 10.w),
            child: Icon(
              Icons.refresh,
              size: 20.r,
              color: AppColors.main,
            ),
          ),
        ),
      );
    } else if (widget.titles.isEmpty) {
      content = Shimmer.fromColors(
        baseColor: AppColors.secondary.withValues(alpha: 0.25),
        highlightColor: AppColors.white,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 75.w,
              height: 14.h,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(height: 6.h),
            Container(
              width: 50.w,
              height: 10.h,
              decoration: BoxDecoration(
                color: AppColors.secondary,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
          ],
        ),
      );
    } else if (hasMultiple) {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
            height: 52.h,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.titles.length,
              onPageChanged: (page) {
                setState(() {
                  _currentPage = page;
                });
              },
              itemBuilder: (context, index) {
                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildTitle(widget.titles[index]),
                    _buildSubtitle(widget.subtitles[index]),
                  ],
                );
              },
            ),
          ),
          SizedBox(height: 6.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.titles.length, (index) {
              final isSelected = index == _currentPage;
              Color dotColor = const Color(0xFFFF5722);
              if (widget.eventColors != null &&
                  index < widget.eventColors!.length) {
                dotColor = widget.eventColors![index];
              }

              return AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: isSelected ? 6.r : 4.r,
                height: isSelected ? 6.r : 4.r,
                margin: EdgeInsets.symmetric(horizontal: 2.w),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? dotColor
                      : AppColors.secondary.withValues(alpha: 0.4),
                ),
              );
            }),
          ),
        ],
      );
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildTitle(widget.titles.first),
          SizedBox(height: 2.h),
          _buildSubtitle(widget.subtitles.first),
        ],
      );
    }

    return CustomPaint(
      painter: BalloonPainter(
        color: AppColors.light,
        arrowCenter: widget.arrowCenter,
        isBottomRow: widget.isBottomRow,
      ),
      child: Container(
        width: 137.w,
        padding: widget.isBottomRow
            ? EdgeInsets.fromLTRB(12.w, 8.h, 12.w, 8.h + arrowHeight)
            : EdgeInsets.fromLTRB(12.w, 8.h + arrowHeight, 12.w, 8.h),
        child: content,
      ),
    );
  }
}

class BalloonPainter extends CustomPainter {
  final Color color;
  final double arrowCenter;
  final bool isBottomRow;

  BalloonPainter({
    required this.color,
    required this.arrowCenter,
    required this.isBottomRow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = Path();
    final double w = size.width;
    final double h = size.height;
    final double arrowHeight = 12.h;
    final double arrowWidth = 18.w;
    final double radius = 10.r;

    if (isBottomRow) {
      final double bodyHeight = h - arrowHeight;

      path.moveTo(radius, 0);
      path.lineTo(w - radius, 0);
      path.arcToPoint(Offset(w, radius), radius: Radius.circular(radius));

      path.lineTo(w, bodyHeight - radius);
      path.arcToPoint(
        Offset(w - radius, bodyHeight),
        radius: Radius.circular(radius),
      );

      // Bottom line with pointer pointing down
      path.lineTo(arrowCenter + arrowWidth / 2, bodyHeight);

      // Curved pointer peak rounding pointing down
      path.quadraticBezierTo(
        arrowCenter + arrowWidth / 4,
        bodyHeight + arrowHeight / 2,
        arrowCenter + 2.w,
        h - 2.h,
      );
      path.quadraticBezierTo(arrowCenter, h, arrowCenter - 2.w, h - 2.h);
      path.quadraticBezierTo(
        arrowCenter - arrowWidth / 4,
        bodyHeight + arrowHeight / 2,
        arrowCenter - arrowWidth / 2,
        bodyHeight,
      );

      path.lineTo(radius, bodyHeight);
      path.arcToPoint(
        Offset(0, bodyHeight - radius),
        radius: Radius.circular(radius),
      );

      path.lineTo(0, radius);
      path.arcToPoint(Offset(radius, 0), radius: Radius.circular(radius));
    } else {
      path.moveTo(radius, arrowHeight);

      // Top line with pointer pointing up
      path.lineTo(arrowCenter - arrowWidth / 2, arrowHeight);

      // Curved pointer peak rounding pointing up
      path.quadraticBezierTo(
        arrowCenter - arrowWidth / 4,
        arrowHeight / 2,
        arrowCenter - 2.w,
        2.h,
      );
      path.quadraticBezierTo(arrowCenter, 0, arrowCenter + 2.w, 2.h);
      path.quadraticBezierTo(
        arrowCenter + arrowWidth / 4,
        arrowHeight / 2,
        arrowCenter + arrowWidth / 2,
        arrowHeight,
      );

      path.lineTo(w - radius, arrowHeight);
      path.arcToPoint(
        Offset(w, arrowHeight + radius),
        radius: Radius.circular(radius),
      );

      path.lineTo(w, h - radius);
      path.arcToPoint(Offset(w - radius, h), radius: Radius.circular(radius));

      path.lineTo(radius, h);
      path.arcToPoint(Offset(0, h - radius), radius: Radius.circular(radius));

      path.lineTo(0, arrowHeight + radius);
      path.arcToPoint(
        Offset(radius, arrowHeight),
        radius: Radius.circular(radius),
      );
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
