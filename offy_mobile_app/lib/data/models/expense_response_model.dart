import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/api_parser_utils.dart';
import '../../core/utils/icon_mapper.dart';
import '../../domain/entities/attachment_entity.dart';
import 'filter_model.dart';

enum ExpenseStatus {
  draft,
  approved,
  pending,
  paid,
  rejected,
  custom;

  static ExpenseStatus fromString(String? status) {
    switch (status?.toLowerCase()) {
      case 'draft':
        return ExpenseStatus.draft;
      case 'approved' || 'validate' || 'validated':
        return ExpenseStatus.approved;
      case 'pending' || 'confirm' || 'confirmed':
        return ExpenseStatus.pending;
      case 'paid' || 'done':
        return ExpenseStatus.paid;
      case 'rejected' || 'refused':
        return ExpenseStatus.rejected;
      default:
        return ExpenseStatus.custom;
    }
  }

  Color getColor({bool isDark = false}) {
    switch (this) {
      case ExpenseStatus.approved:
        return AppColors.teal;
      case ExpenseStatus.draft:
      case ExpenseStatus.pending:
      case ExpenseStatus.custom:
        return isDark ? AppColors.darkYellow : AppColors.yellow;
      case ExpenseStatus.paid:
        return isDark ? AppColors.green : AppColors.darkGreen;
      case ExpenseStatus.rejected:
        return AppColors.pink;
    }
  }

  Color get color => getColor();

  IconData get icon {
    switch (this) {
      case ExpenseStatus.approved:
      case ExpenseStatus.paid:
        return Icons.check_circle_rounded;
      case ExpenseStatus.draft:
      case ExpenseStatus.pending:
      case ExpenseStatus.custom:
        return Icons.access_time_outlined;
      case ExpenseStatus.rejected:
        return Icons.cancel_rounded;
    }
  }
}

class ExpenseSummaryModel {
  final double pendingReimbursementAmount;
  final String pendingReimbursementDisplay;
  final int pendingCount;
  final AverageApprovalTimeModel? averageApprovalTime;
  final List<RecentExpenseModel> recentExpenses;

  ExpenseSummaryModel({
    required this.pendingReimbursementAmount,
    required this.pendingReimbursementDisplay,
    required this.pendingCount,
    this.averageApprovalTime,
    required this.recentExpenses,
  });

  factory ExpenseSummaryModel.fromJson(Map<String, dynamic> json) {
    return ExpenseSummaryModel(
      pendingReimbursementAmount: (json['pending_reimbursement_amount'] ?? 0.0)
          .toDouble(),
      pendingReimbursementDisplay: json['pending_reimbursement_display'] ?? '',
      pendingCount: json['pending_count'] ?? 0,
      averageApprovalTime: json['average_approval_time'] != null
          ? AverageApprovalTimeModel.fromJson(json['average_approval_time'])
          : null,
      recentExpenses: json['recent_expenses'] != null
          ? List<RecentExpenseModel>.from(
              json['recent_expenses'].map(
                (x) => RecentExpenseModel.fromJson(x),
              ),
            )
          : [],
    );
  }
}

class AverageApprovalTimeModel {
  final int value;
  final String unit;
  final String display;
  final String source;

  AverageApprovalTimeModel({
    required this.value,
    required this.unit,
    required this.display,
    required this.source,
  });

  factory AverageApprovalTimeModel.fromJson(Map<String, dynamic> json) {
    return AverageApprovalTimeModel(
      value: json['value'] ?? 0,
      unit: json['unit'] ?? '',
      display: json['display'] ?? '',
      source: json['source'] ?? '',
    );
  }
}

class ExpenseBreakdownItem {
  final int id;
  final String date;
  final double amount;
  final String amountDisplay;
  final String currency;
  final String state;
  final String memo;

  ExpenseBreakdownItem({
    this.id = 0,
    required this.date,
    required this.amount,
    required this.amountDisplay,
    this.currency = '',
    this.state = '',
    this.memo = '',
  });

  factory ExpenseBreakdownItem.fromJson(Map<String, dynamic> json) {
    return ExpenseBreakdownItem(
      id: parseField<int>(json['id']) ?? 0,
      date: parseField<String>(json['date']) ?? '',
      amount:
          parseField<double>(json['amount']) ??
          (parseField<int>(json['amount'])?.toDouble() ?? 0.0),
      amountDisplay:
          parseField<String>(json['amount_display']) ??
          parseField<String>(json['amount']) ??
          '',
      currency: parseField<String>(json['currency']) ?? '',
      state: parseField<String>(json['state']) ?? '',
      memo: parseField<String>(json['memo']) ?? '',
    );
  }
}

class RecentExpenseModel {
  final int id;
  final String title;
  final String category;
  final String date;
  final double amount;
  final String amountDisplay;
  final String currency;
  final String status;
  final String statusDisplay;
  final String icon;
  final bool hasReceipt;
  final List<AttachmentEntity>? attachments;
  final double? totalAmount;
  final String? totalAmountDisplay;
  final double? amountPaid;
  final String? amountPaidDisplay;
  final double? amountDue;
  final String? amountDueDisplay;
  final String? paymentCurrency;
  final String? paymentStatus;
  final String? paymentStatusDisplay;
  final bool isFullyPaid;
  final bool isPartiallyPaid;
  final List<ExpenseBreakdownItem>? breakdownItems;
  final bool isEditable;
  final bool isDeletable;

  RecentExpenseModel({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.amount,
    required this.amountDisplay,
    required this.currency,
    required this.status,
    required this.statusDisplay,
    required this.icon,
    required this.hasReceipt,
    this.attachments,
    this.totalAmount,
    this.totalAmountDisplay,
    this.amountPaid,
    this.amountPaidDisplay,
    this.amountDue,
    this.amountDueDisplay,
    this.paymentCurrency,
    this.paymentStatus,
    this.paymentStatusDisplay,
    this.isFullyPaid = false,
    this.isPartiallyPaid = false,
    this.breakdownItems,
    this.isEditable = false,
    this.isDeletable = false,
  });

  factory RecentExpenseModel.fromJson(Map<String, dynamic> json) {
    List<AttachmentEntity>? parsedAttachments;
    if (json['attachments'] is List) {
      parsedAttachments = [];
      for (var e in (json['attachments'] as List)) {
        if (e != null) {
          if (e is Map) {
            parsedAttachments.add(
              AttachmentEntity.fromJson(Map<String, dynamic>.from(e)),
            );
          } else {
            final str = e.toString();
            if (str.isNotEmpty) {
              parsedAttachments.add(AttachmentEntity(url: str));
            }
          }
        }
      }
    }

    List<ExpenseBreakdownItem>? parsedBreakdownItems;
    if (json['payments'] is List) {
      parsedBreakdownItems = (json['payments'] as List)
          .whereType<Map<String, dynamic>>()
          .map((x) => ExpenseBreakdownItem.fromJson(x))
          .toList();
    } else if (json['breakdown_items'] is List) {
      parsedBreakdownItems = (json['breakdown_items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((x) => ExpenseBreakdownItem.fromJson(x))
          .toList();
    } else if (json['items'] is List) {
      parsedBreakdownItems = (json['items'] as List)
          .whereType<Map<String, dynamic>>()
          .map((x) => ExpenseBreakdownItem.fromJson(x))
          .toList();
    }

    return RecentExpenseModel(
      id: parseField<int>(json['id']) ?? 0,
      title:
          parseField<String>(json['title']) ??
          parseField<String>(json['name']) ??
          '',
      category: parseField<String>(json['category']) ?? '',
      date: parseField<String>(json['date']) ?? '',
      amount:
          parseField<double>(json['amount']) ??
          (parseField<int>(json['amount'])?.toDouble() ?? 0.0),
      amountDisplay: parseField<String>(json['amount_display']) ?? '',
      currency: parseField<String>(json['currency']) ?? '',
      status: parseField<String>(json['status']) ?? '',
      statusDisplay: parseField<String>(json['status_display']) ?? '',
      icon: parseField<String>(json['icon']) ?? '',
      hasReceipt: parseField<bool>(json['has_receipt']) ?? false,
      attachments: parsedAttachments,
      totalAmount:
          parseField<double>(json['total_amount']) ??
          (parseField<int>(json['total_amount'])?.toDouble()),
      totalAmountDisplay: parseField<String>(json['total_amount_display']),
      amountPaid:
          parseField<double>(json['amount_paid']) ??
          (parseField<int>(json['amount_paid'])?.toDouble()),
      amountPaidDisplay: parseField<String>(json['amount_paid_display']),
      amountDue:
          parseField<double>(json['amount_due']) ??
          (parseField<int>(json['amount_due'])?.toDouble()),
      amountDueDisplay: parseField<String>(json['amount_due_display']),
      paymentCurrency: parseField<String>(json['payment_currency']),
      paymentStatus: parseField<String>(json['payment_status']),
      paymentStatusDisplay:
          parseField<String>(json['payment_status_display']) ??
          parseField<String>(json['payment_status']),
      isFullyPaid: parseField<bool>(json['is_fully_paid']) ?? false,
      isPartiallyPaid: parseField<bool>(json['is_partially_paid']) ?? false,
      breakdownItems: parsedBreakdownItems,
      isEditable: parseField<bool>(json['is_editable']) ?? false,
      isDeletable: parseField<bool>(json['is_deletable']) ?? false,
    );
  }

  IconData get iconData => IconMapper.getExpenseIcon(icon);

  ExpenseStatus get statusEnum =>
      ExpenseStatus.fromString(status.isNotEmpty ? status : statusDisplay);

  bool get isDraft => statusEnum == ExpenseStatus.draft;
  bool get isPending => statusEnum == ExpenseStatus.pending;
}

class PaginationModel {
  final int page;
  final int limit;
  final int total;
  final bool hasNext;
  final bool hasPrevious;

  PaginationModel({
    required this.page,
    required this.limit,
    required this.total,
    required this.hasNext,
    required this.hasPrevious,
  });

  factory PaginationModel.fromJson(Map<String, dynamic> json) {
    return PaginationModel(
      page: parseField<int>(json['page']) ?? 1,
      limit: parseField<int>(json['limit']) ?? 20,
      total: parseField<int>(json['total']) ?? 0,
      hasNext: parseField<bool>(json['has_next']) ?? false,
      hasPrevious: parseField<bool>(json['has_previous']) ?? false,
    );
  }
}

class ExpenseGroupModel {
  final String timeline;
  final double totalAmount;
  final String totalAmountDisplay;
  final String currency;
  final List<RecentExpenseModel> expenses;

  ExpenseGroupModel({
    required this.timeline,
    this.totalAmount = 0.0,
    this.totalAmountDisplay = '',
    this.currency = '',
    required this.expenses,
  });

  factory ExpenseGroupModel.fromJson(Map<String, dynamic> json) {
    final rawExpenses = parseField<List>(json['expenses']);
    return ExpenseGroupModel(
      timeline: parseField<String>(json['timeline']) ?? '',
      totalAmount:
          parseField<double>(json['total_amount']) ??
          (parseField<int>(json['total_amount'])?.toDouble() ?? 0.0),
      totalAmountDisplay:
          parseField<String>(json['total_amount_display']) ?? '',
      currency: parseField<String>(json['currency']) ?? '',
      expenses: rawExpenses != null
          ? rawExpenses
                .whereType<Map<String, dynamic>>()
                .map((x) => RecentExpenseModel.fromJson(x))
                .toList()
          : [],
    );
  }
}

class ExpenseListFiltersModel {
  final ActiveFilterModel? active;

  ExpenseListFiltersModel({this.active});

  factory ExpenseListFiltersModel.fromJson(Map<String, dynamic> json) {
    final activeMap =
        json['active'] != null && json['active'] is Map<String, dynamic>
        ? json['active'] as Map<String, dynamic>
        : null;
    return ExpenseListFiltersModel(
      active: activeMap != null ? ActiveFilterModel.fromJson(activeMap) : null,
    );
  }
}

class ExpenseListResponseModel {
  final List<RecentExpenseModel> items;
  final List<ExpenseGroupModel> groups;
  final PaginationModel pagination;
  final ExpenseListFiltersModel? filters;

  ExpenseListResponseModel({
    this.items = const [],
    this.groups = const [],
    required this.pagination,
    this.filters,
  });

  factory ExpenseListResponseModel.fromList(List<dynamic> list) {
    final parsedItems = list
        .whereType<Map<String, dynamic>>()
        .map((x) => RecentExpenseModel.fromJson(x))
        .toList();
    return ExpenseListResponseModel(
      items: parsedItems,
      groups: const [],
      pagination: PaginationModel(
        page: 1,
        limit: 20,
        total: parsedItems.length,
        hasNext: false,
        hasPrevious: false,
      ),
    );
  }

  factory ExpenseListResponseModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> target =
        (json.containsKey('data') && json['data'] is Map<String, dynamic>)
        ? json['data'] as Map<String, dynamic>
        : json;
    final rawItems = parseField<List>(target['items']) ??
        parseField<List>(target['expenses']) ??
        parseField<List>(target['recent_expenses']) ??
        parseField<List>(target['records']) ??
        (json.containsKey('data') && json['data'] is List
            ? json['data'] as List
            : null);
    final rawGroups = parseField<List>(target['groups']);
    final paginationMap =
        target['pagination'] != null &&
            target['pagination'] is Map<String, dynamic>
        ? target['pagination'] as Map<String, dynamic>
        : null;
    final filtersMap =
        target['filters'] != null && target['filters'] is Map<String, dynamic>
        ? target['filters'] as Map<String, dynamic>
        : null;

    final parsedGroups = rawGroups != null
        ? rawGroups
            .whereType<Map<String, dynamic>>()
            .map((x) => ExpenseGroupModel.fromJson(x))
            .toList()
        : <ExpenseGroupModel>[];

    final parsedItems = rawItems != null
        ? rawItems
            .whereType<Map<String, dynamic>>()
            .map((x) => RecentExpenseModel.fromJson(x))
            .toList()
        : (parsedGroups.isNotEmpty
            ? parsedGroups.expand((g) => g.expenses).toList()
            : <RecentExpenseModel>[]);

    return ExpenseListResponseModel(
      items: parsedItems,
      groups: parsedGroups,
      pagination: paginationMap != null
          ? PaginationModel.fromJson(paginationMap)
          : PaginationModel(
              page: 1,
              limit: 20,
              total: parsedItems.length,
              hasNext: false,
              hasPrevious: false,
            ),
      filters: filtersMap != null
          ? ExpenseListFiltersModel.fromJson(filtersMap)
          : null,
    );
  }
}
