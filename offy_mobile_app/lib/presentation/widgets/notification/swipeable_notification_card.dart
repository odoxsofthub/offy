import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../data/models/notification_model.dart';
import '../../viewmodels/notification/notification_provider.dart';
import 'notification_card.dart';

class SwipeableNotificationCard extends StatefulWidget {
  final NotificationItem item;
  final bool isNew;
  final bool isRevealed;
  final VoidCallback onReveal;
  final VoidCallback onCollapse;

  const SwipeableNotificationCard({
    super.key,
    required this.item,
    required this.isNew,
    required this.isRevealed,
    required this.onReveal,
    required this.onCollapse,
  });

  @override
  State<SwipeableNotificationCard> createState() =>
      _SwipeableNotificationCardState();
}

class _SwipeableNotificationCardState extends State<SwipeableNotificationCard> {
  // Accumulates horizontal drag delta during a single drag gesture.
  double _dragDeltaX = 0;

  // Threshold (in logical pixels) to trigger reveal or collapse.
  static const double _revealThreshold = 40.0;

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    _dragDeltaX += details.delta.dx;

    // Swipe left past threshold → reveal delete button.
    if (!widget.isRevealed && _dragDeltaX < -_revealThreshold) {
      widget.onReveal();
    }
    // Swipe right past threshold while revealed → collapse.
    else if (widget.isRevealed && _dragDeltaX > _revealThreshold) {
      widget.onCollapse();
    }
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    // Reset accumulated delta after each gesture ends.
    _dragDeltaX = 0;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onHorizontalDragEnd: _onHorizontalDragEnd,
      // Tap on the card while revealed → collapse.
      onTap: widget.isRevealed ? widget.onCollapse : null,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Card shrinks naturally when delete button appears.
              Expanded(
                child: NotificationCard(
                  item: widget.item,
                  isNew: widget.isNew,
                ),
              ),

              // Delete button revealed on swipe.
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: ClipRect(
                      child: SizeTransition(
                        sizeFactor: animation,
                        axis: Axis.horizontal,
                        child: child,
                      ),
                    ),
                  );
                },
                child: widget.isRevealed
                    ? Padding(
                        key: const ValueKey('delete-btn'),
                        padding: EdgeInsets.only(left: 8.w),
                        child: _DeleteButton(onTap: () {
                          context
                              .read<NotificationProvider>()
                              .dismissNotification(widget.item.id);
                          widget.onCollapse();
                        }),
                      )
                    : const SizedBox.shrink(key: ValueKey('empty')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DeleteButton extends StatelessWidget {
  final VoidCallback onTap;

  const _DeleteButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50.w,
        decoration: BoxDecoration(
          // rgba(255, 227, 227, 0.5) → ARGB 0x80FFE3E3
          color: const Color(0x80FFE3E3),
          border: Border.all(
            color: const Color(0xFFFFAEAE),
            width: 1,
          ),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Center(
          child: Icon(
            Icons.delete_outline,
            size: 24.w,
            color: AppColors.red,
          ),
        ),
      ),
    );
  }
}
