import 'package:flutter/material.dart';
import '../../core/utils/icon_mapper.dart';

class ExpenseCategoryModel {
  final int id;
  final String name;
  final String iconStr;
  final int sequence;
  final bool requiresReceipt;

  ExpenseCategoryModel({
    required this.id,
    required this.name,
    required this.iconStr,
    required this.sequence,
    required this.requiresReceipt,
  });

  factory ExpenseCategoryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseCategoryModel(
      id: json['id'] ?? 0,
      name: json['name'] ?? '',
      iconStr: json['icon'] ?? '',
      sequence: json['sequence'] ?? 0,
      requiresReceipt: json['requires_receipt'] ?? false,
    );
  }

  IconData get icon => IconMapper.getExpenseIcon(iconStr, isOutlined: true);
}
