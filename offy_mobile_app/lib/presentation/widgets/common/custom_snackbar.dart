import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:office_app/core/theme/app_colors.dart';

class CustomSnackbar {
  static const String sessionExpiredMessage =
      'Your session has expired. Please log in again.';

  static bool _suppressOthers = false;

  /// Suppresses all snackbars except [sessionExpiredMessage] during the session-expiry logout flow.
  static void suppressExceptSessionExpired() {
    _suppressOthers = true;
    Future.delayed(const Duration(seconds: 4), () {
      _suppressOthers = false;
    });
  }

  /// Resets the suppression state.
  static void resetSuppression() {
    _suppressOthers = false;
  }

  static void clear([BuildContext? context]) {
    if (_suppressOthers) return;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
    }
  }

  static void hide([BuildContext? context]) {
    if (_suppressOthers) return;
    if (context != null && context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  static String _sanitizeMessage(String message) {
    if (message.contains(': ')) {
      final parts = message.split(': ');
      final prefix = parts[0];
      final errorDetail = parts.sublist(1).join(': ');

      final lowerDetail = errorDetail.toLowerCase();
      if (lowerDetail.contains('null is not a subtype') ||
          lowerDetail.contains('typeerror') ||
          lowerDetail.contains('formatexception') ||
          lowerDetail.contains('nosuchmethoderror') ||
          lowerDetail.contains('lateinitializationerror') ||
          lowerDetail.contains('rangeerror') ||
          lowerDetail.contains('assertionerror') ||
          lowerDetail.contains('unhandled exception') ||
          lowerDetail.contains('failed host lookup') ||
          lowerDetail.contains('socketexception') ||
          lowerDetail.contains('httpstatuscodeexception') ||
          lowerDetail.contains('connection timed out') ||
          lowerDetail.contains('connection refused') ||
          lowerDetail.contains('clientexception')) {
        if (lowerDetail.contains('socketexception') ||
            lowerDetail.contains('failed host lookup') ||
            lowerDetail.contains('connection')) {
          return '$prefix. Please check your internet connection.';
        }
        return '$prefix. Please try again later.';
      }
    } else {
      final lowerMessage = message.toLowerCase();
      if (lowerMessage.contains('null is not a subtype') ||
          lowerMessage.contains('typeerror') ||
          lowerMessage.contains('formatexception') ||
          lowerMessage.contains('nosuchmethoderror') ||
          lowerMessage.contains('lateinitializationerror') ||
          lowerMessage.contains('rangeerror') ||
          lowerMessage.contains('assertionerror') ||
          lowerMessage.contains('unhandled exception')) {
        return 'An unexpected error occurred. Please try again later.';
      }
    }
    return message;
  }

  static void show(
    BuildContext context, {
    required String message,
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
    SnackBarBehavior behavior = SnackBarBehavior.floating,
    bool isError = false,
    bool isSuccess = false,
  }) {
    if (_suppressOthers && message != sessionExpiredMessage) {
      log(
        '🚫 [CustomSnackbar] Suppressed snackbar during session expiry: $message',
      );
      return;
    }

    if (!context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final sanitizedMessage = _sanitizeMessage(message);
    log(
      '🔔 [CustomSnackbar] raw: $message | sanitized: $sanitizedMessage | isError: $isError',
    );

    Color bgColor;
    if (backgroundColor != null) {
      bgColor = backgroundColor;
    } else if (isError) {
      bgColor = isDark ? const Color(0xFF8C1D18) : const Color(0xFFB3261E);
    } else if (isSuccess) {
      bgColor = isDark ? const Color(0xFF2E7D32) : const Color(0xFF388E3C);
    } else {
      bgColor = isDark ? AppColors.darkNav : AppColors.black;
    }

    final textColor = isDark ? AppColors.light : AppColors.white;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          sanitizedMessage,
          style: TextStyle(
            color: textColor,
            fontSize: 14.sp,
            fontWeight: FontWeight.w500,
          ),
        ),
        duration: duration,
        behavior: behavior,
        backgroundColor: bgColor,
        margin: behavior == SnackBarBehavior.floating
            ? EdgeInsets.only(bottom: 20.h, left: 16.w, right: 16.w)
            : null,
        shape: behavior == SnackBarBehavior.floating
            ? RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r))
            : null,
      ),
    );
  }
}
