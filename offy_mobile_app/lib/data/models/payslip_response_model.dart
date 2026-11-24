import '../../core/utils/api_parser_utils.dart';

class PayslipResponseModel {
  final bool? success;
  final String? message;
  final PayslipModel? data;

  PayslipResponseModel({
    this.success,
    this.message,
    this.data,
  });

  factory PayslipResponseModel.fromJson(Map<String, dynamic> json) {
    final dataMap = parseField<Map>(json['data']);
    return PayslipResponseModel(
      success: parseField<bool>(json['success']),
      message: parseField<String>(json['message']),
      data: dataMap != null
          ? PayslipModel.fromJson(Map<String, dynamic>.from(dataMap))
          : null,
    );
  }
}

class PayslipModel {
  final int id;
  final String period;

  final int? year;

  final String dateFrom;
  final String dateTo;
  final dynamic netPay;
  final String state;
  final String distributedDate;
  final String filename;
  final String downloadUrl;
  final bool downloadRequiresAuth;
  final List<PayslipLineItemModel>? earnings;
  final List<PayslipLineItemModel>? deductions;
  final List<PayslipModel>? history;

  PayslipModel({
    required this.id,
    required this.period,
    required this.dateFrom,
    required this.dateTo,
    required this.netPay,
    required this.state,
    required this.distributedDate,
    this.year,
    this.filename = '',
    this.downloadUrl = '',
    this.downloadRequiresAuth = false,
    this.earnings,
    this.deductions,
    this.history,
  });

  static int? _yearFrom(String dateTo, String dateFrom) {
    for (final raw in [dateTo, dateFrom]) {
      if (raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed != null) return parsed.year;
    }
    return null;
  }

  factory PayslipModel.fromJson(Map<String, dynamic> json) {
    final dateTo = parseField<String>(json['date_to']) ?? '';
    final dateFrom = parseField<String>(json['date_from']) ?? '';
    final rawEarnings = parseField<List>(json['earnings']);
    final rawDeductions = parseField<List>(json['deductions']);
    final rawHistory = parseField<List>(json['history']);

    return PayslipModel(
      id: parseField<int>(json['id']) ?? 0,
      period: parseField<String>(json['period']) ?? '',
      year: parseField<int>(json['year']) ?? _yearFrom(dateTo, dateFrom),
      dateFrom: dateFrom,
      dateTo: dateTo,
      netPay: parseField<Object>(json['net_pay']) ?? '0.00',
      state: parseField<String>(json['state']) ?? '',
      distributedDate: parseField<String>(json['payment_date']) ??
          parseField<String>(json['distributed_date']) ??
          '',
      filename: parseField<String>(json['filename']) ?? '',
      downloadUrl: parseField<String>(json['download_url']) ?? '',
      downloadRequiresAuth:
          parseField<bool>(json['download_requires_auth']) ?? false,
      earnings: rawEarnings
          ?.whereType<Map<String, dynamic>>()
          .map((x) => PayslipLineItemModel.fromJson(x))
          .toList(),
      deductions: rawDeductions
          ?.whereType<Map<String, dynamic>>()
          .map((x) => PayslipLineItemModel.fromJson(x))
          .toList(),
      history: rawHistory
          ?.whereType<Map<String, dynamic>>()
          .map((x) => PayslipModel.fromJson(x))
          .toList(),
    );
  }
}

class PayslipLineItemModel {
  final String code;
  final String name;
  final double amount;

  PayslipLineItemModel({
    required this.code,
    required this.name,
    required this.amount,
  });

  factory PayslipLineItemModel.fromJson(Map<String, dynamic> json) {
    return PayslipLineItemModel(
      code: parseField<String>(json['code']) ?? '',
      name: parseField<String>(json['name']) ?? '',
      amount: (parseField<num>(json['amount']) ?? 0.0).toDouble(),
    );
  }
}

class PayslipPaginationModel {
  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  PayslipPaginationModel({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  factory PayslipPaginationModel.fromJson(Map<String, dynamic> json) {
    return PayslipPaginationModel(
      page: parseField<int>(json['page']) ?? 1,
      pageSize: parseField<int>(json['page_size']) ?? 10,
      total: parseField<int>(json['total']) ?? 0,
      totalPages: parseField<int>(json['total_pages']) ?? 1,
    );
  }

  bool get hasNext => page < totalPages;
}

class PayslipHistoryResponseModel {
  final bool? success;
  final String? message;
  final List<PayslipModel> payslips;
  final PayslipPaginationModel pagination;

  PayslipHistoryResponseModel({
    this.success,
    this.message,
    required this.payslips,
    required this.pagination,
  });

  factory PayslipHistoryResponseModel.fromList(List<dynamic> list) {
    final parsedPayslips = list
        .whereType<Map<String, dynamic>>()
        .map((x) => PayslipModel.fromJson(x))
        .toList();
    return PayslipHistoryResponseModel(
      success: true,
      message: 'Success',
      payslips: parsedPayslips,
      pagination: PayslipPaginationModel(
        page: 1,
        pageSize: parsedPayslips.isNotEmpty ? parsedPayslips.length : 10,
        total: parsedPayslips.length,
        totalPages: 1,
      ),
    );
  }

  factory PayslipHistoryResponseModel.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> target =
        (json.containsKey('data') && json['data'] is Map<String, dynamic>)
            ? json['data'] as Map<String, dynamic>
            : json;
    final rawPayslips = parseField<List>(target['payslips']) ??
        parseField<List>(target['items']) ??
        parseField<List>(target['records']) ??
        parseField<List>(target['history']) ??
        (json.containsKey('data') && json['data'] is List
            ? json['data'] as List
            : null);

    final paginationMap =
        target['pagination'] != null &&
                target['pagination'] is Map<String, dynamic>
            ? target['pagination'] as Map<String, dynamic>
            : (json['pagination'] != null &&
                    json['pagination'] is Map<String, dynamic>
                ? json['pagination'] as Map<String, dynamic>
                : null);

    final parsedPayslips = rawPayslips != null
        ? rawPayslips
            .whereType<Map<String, dynamic>>()
            .map((i) => PayslipModel.fromJson(i))
            .toList()
        : <PayslipModel>[];

    return PayslipHistoryResponseModel(
      success: parseField<bool>(json['success']),
      message: parseField<String>(json['message']),
      payslips: parsedPayslips,
      pagination: paginationMap != null
          ? PayslipPaginationModel.fromJson(paginationMap)
          : PayslipPaginationModel(
              page: 1,
              pageSize: 10,
              total: parsedPayslips.length,
              totalPages: 1,
            ),
    );
  }
}

