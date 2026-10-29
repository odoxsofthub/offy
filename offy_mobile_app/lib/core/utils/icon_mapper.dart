import 'package:flutter/material.dart';

class IconMapper {
  static IconData getExpenseIcon(String? slug, {bool isOutlined = false}) {
    final key = slug?.toLowerCase() ?? '';
    switch (key) {
      case 'fuel':
        return isOutlined
            ? Icons.local_gas_station_outlined
            : Icons.local_gas_station;
      case 'parking':
        return isOutlined ? Icons.local_parking_outlined : Icons.local_parking;
      case 'toll':
        return isOutlined ? Icons.toll_outlined : Icons.toll;
      case 'plane':
        return isOutlined ? Icons.flight_outlined : Icons.flight;
      case 'train':
        return isOutlined ? Icons.train_outlined : Icons.train;
      case 'bus':
        return isOutlined
            ? Icons.directions_bus_outlined
            : Icons.directions_bus;
      case 'car':
        return isOutlined
            ? Icons.directions_car_outlined
            : Icons.directions_car;
      case 'hotel':
        return isOutlined ? Icons.hotel_outlined : Icons.hotel;
      case 'passport':
        return isOutlined ? Icons.badge_outlined : Icons.badge;
      case 'coffee':
        return isOutlined ? Icons.local_cafe_outlined : Icons.local_cafe;
      case 'utensils':
        return isOutlined ? Icons.restaurant_outlined : Icons.restaurant;
      case 'entertainment':
        return isOutlined
            ? Icons.confirmation_number_outlined
            : Icons.confirmation_number;
      case 'gift':
        return isOutlined ? Icons.card_giftcard_outlined : Icons.card_giftcard;
      case 'health':
        return isOutlined
            ? Icons.medical_services_outlined
            : Icons.medical_services;
      case 'education':
        return isOutlined ? Icons.school_outlined : Icons.school;
      case 'software':
        return isOutlined ? Icons.code_outlined : Icons.code;
      case 'laptop':
        return isOutlined ? Icons.laptop_outlined : Icons.laptop;
      case 'phone':
        return isOutlined ? Icons.phone_android_outlined : Icons.phone_android;
      case 'wifi':
        return isOutlined ? Icons.wifi_outlined : Icons.wifi;
      case 'printer':
        return isOutlined ? Icons.print_outlined : Icons.print;
      case 'postage':
        return isOutlined
            ? Icons.local_shipping_outlined
            : Icons.local_shipping;
      case 'building':
        return isOutlined ? Icons.apartment_outlined : Icons.apartment;
      case 'box':
        return isOutlined ? Icons.inventory_2_outlined : Icons.inventory_2;
      case 'marketing':
        return isOutlined ? Icons.campaign_outlined : Icons.campaign;
      case 'legal':
        return isOutlined ? Icons.gavel_outlined : Icons.gavel;
      case 'bank':
        return isOutlined
            ? Icons.account_balance_outlined
            : Icons.account_balance;
      case 'insurance':
        return isOutlined ? Icons.shield_outlined : Icons.shield;
      case 'tax':
        return isOutlined ? Icons.request_quote_outlined : Icons.request_quote;
      case 'membership':
        return isOutlined
            ? Icons.card_membership_outlined
            : Icons.card_membership;
      case 'receipt':
      default:
        return isOutlined ? Icons.receipt_long_outlined : Icons.receipt_long;
    }
  }

  static IconData getNotificationIcon(
    String? type, {
    Map<String, dynamic>? data,
  }) {
    if (data != null && data.containsKey('icon') && data['icon'] is String) {
      final categoryIconSlug = (data['icon'] as String).trim();
      if (categoryIconSlug.isNotEmpty) {
        return getExpenseIcon(categoryIconSlug, isOutlined: true);
      }
    }

    final key = type?.toLowerCase() ?? '';
    switch (key) {
      case 'timeoff_approved':
        return Icons.event_available_outlined;
      case 'timeoff_refused':
        return Icons.event_busy_outlined;
      case 'expense_approved':
        return Icons.receipt_long_outlined;
      case 'expense_refused':
        return Icons.assignment_late_outlined;
      case 'expense_paid':
        return Icons.payments_outlined;
      case 'payslip_available':
        return Icons.account_balance_wallet_outlined;
      default:
        if (key.contains('expense')) return Icons.receipt_long_outlined;
        if (key.contains('overtime')) return Icons.access_time_filled;
        if (key.contains('announcement') || key.contains('notice')) {
          return Icons.campaign_outlined;
        }
        if (key.contains('payslip')) {
          return Icons.account_balance_wallet_outlined;
        }
        if (key.contains('payment') || key.contains('disbursement')) {
          return Icons.payments_outlined;
        }
        if (key.contains('timeoff') || key.contains('leave')) {
          return Icons.event;
        }
        return Icons.notifications_outlined;
    }
  }
}
