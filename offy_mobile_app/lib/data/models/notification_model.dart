import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_parser_utils.dart';
import '../../core/utils/date_formatter.dart';
import '../../core/utils/icon_mapper.dart';

class NotificationResponseModel {
  final List<NotificationItem> notifications;
  final int unreadCount;
  final PaginationModel pagination;

  NotificationResponseModel({
    required this.notifications,
    required this.unreadCount,
    required this.pagination,
  });

  factory NotificationResponseModel.fromJson(Map<String, dynamic> json) {
    final notifsList = json['notifications'] as List<dynamic>? ?? [];

    return NotificationResponseModel(
      notifications: notifsList
          .whereType<Map<String, dynamic>>()
          .map((e) => NotificationItem.fromJson(e))
          .toList(),
      unreadCount: parseField<int>(json['unread_count_before_fetch']) ?? 0,
      pagination: PaginationModel.fromJson(
        parseField<Map<String, dynamic>>(json['pagination']) ?? {},
      ),
    );
  }
}

class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final bool hasNext;

  PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasNext,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: parseField<int>(json['page']) ?? 1,
      limit: parseField<int>(json['limit']) ?? 20,
      total: parseField<int>(json['total']) ?? 0,
      hasNext: parseField<bool>(json['has_next']) ?? false,
    );
  }
}

class NotificationItem {
  final int id;
  final String type;
  final String title;
  final String description;
  final Map<String, dynamic> data;
  final bool isRead;
  final DateTime? readAt;
  final DateTime date;
  final String? deliveryStatus;

  NotificationItem({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.data,
    required this.isRead,
    this.readAt,
    required this.date,
    this.deliveryStatus,
  });

  factory NotificationItem.fromJson(Map<String, dynamic> json) {
    final createdAtStr = parseField<String>(json['created_at']);
    final readAtStr = parseField<String>(json['read_at']);
    return NotificationItem(
      id: parseField<int>(json['id']) ?? 0,
      type: parseField<String>(json['type']) ?? '',
      title: parseField<String>(json['title']) ?? '',
      description: parseField<String>(json['message']) ?? '',
      data: parseField<Map<String, dynamic>>(json['data']) ?? {},
      isRead: parseField<bool>(json['is_read']) ?? false,
      readAt: readAtStr != null ? DateTime.tryParse(readAtStr)?.toLocal() : null,
      date: createdAtStr != null
          ? DateTime.tryParse(createdAtStr)?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      deliveryStatus: parseField<String>(json['delivery_status']),
    );
  }

  String get time {
    return AppDateFormatter.notificationTime(date);
  }

  IconData get icon {
    return IconMapper.getNotificationIcon(type, data: data);
  }

  bool get isMirroredIcon {
    return type.contains('payment') || type.contains('disbursement');
  }

  Color get iconColor {
    if (type.contains('announcement') || type.contains('notice')) {
      return AppColors.tertiary;
    }
    if (type.contains('expense') ||
        type.contains('overtime') ||
        type.contains('payment') ||
        type.contains('disbursement') ||
        type.contains('payslip') ||
        type.contains('timeoff') ||
        type.contains('leave')) {
      return AppColors.main;
    }
    return AppColors.tertiary; // general
  }

  Color get iconBgColor {
    if (type.contains('announcement') || type.contains('notice')) {
      return const Color(0x1A5B4039);
    }
    if (type.contains('expense') ||
        type.contains('overtime') ||
        type.contains('payment') ||
        type.contains('disbursement') ||
        type.contains('payslip') ||
        type.contains('timeoff') ||
        type.contains('leave')) {
      return const Color(0x1AFD5223);
    }
    return const Color(0x1A5B4039); // general
  }
}
