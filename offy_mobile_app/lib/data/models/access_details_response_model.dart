import '../../core/utils/api_parser_utils.dart';

class AccessDetailsResponseModel {
  final UserModel? user;
  final CompanyModel? company;
  final ConfigModel? config;
  final List<FeatureModel>? features;

  AccessDetailsResponseModel({
    this.user,
    this.company,
    this.config,
    this.features,
  });

  factory AccessDetailsResponseModel.fromJson(Map<String, dynamic> json) {
    return AccessDetailsResponseModel(
      user: json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['user'])
          : null,
      company: json['company'] is Map<String, dynamic>
          ? CompanyModel.fromJson(json['company'])
          : null,
      config: json['config'] is Map<String, dynamic>
          ? ConfigModel.fromJson(json['config'])
          : null,
      features: json['features'] is List
          ? List<FeatureModel>.from(
              (json['features'] as List).map((x) => FeatureModel.fromJson(
                  x is Map<String, dynamic> ? x : {})))
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    if (user != null) 'user': user!.toJson(),
    if (company != null) 'company': company!.toJson(),
    if (config != null) 'config': config!.toJson(),
    if (features != null)
      'features': features!.map((x) => x.toJson()).toList(),
  };
}

class UserModel {
  final int id;
  final String name;
  final String login;
  final bool active;
  final bool mobileUser;

  UserModel({
    required this.id,
    required this.name,
    required this.login,
    required this.active,
    required this.mobileUser,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      login: parseField<String>(json['login']) ?? '',
      active: parseField<bool>(json['active']) ?? false,
      mobileUser: parseField<bool>(json['mobile_user']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'login': login,
    'active': active,
    'mobile_user': mobileUser,
  };
}

class CompanyModel {
  final int defaultCompanyId;
  final CurrencyModel? defaultCompanyCurrency;

  CompanyModel({
    required this.defaultCompanyId,
    this.defaultCompanyCurrency,
  });

  factory CompanyModel.fromJson(Map<String, dynamic> json) {
    return CompanyModel(
      defaultCompanyId: parseField<int>(json['default_company_id']) ?? 0,
      defaultCompanyCurrency: json['default_company_currency'] is Map<String, dynamic>
          ? CurrencyModel.fromJson(json['default_company_currency'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'default_company_id': defaultCompanyId,
    if (defaultCompanyCurrency != null)
      'default_company_currency': defaultCompanyCurrency!.toJson(),
  };
}

class CurrencyModel {
  final int id;
  final String name;
  final String symbol;

  CurrencyModel({
    required this.id,
    required this.name,
    required this.symbol,
  });

  factory CurrencyModel.fromJson(Map<String, dynamic> json) {
    return CurrencyModel(
      id: parseField<int>(json['id']) ?? 0,
      name: parseField<String>(json['name']) ?? '',
      symbol: parseField<String>(json['symbol']) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'symbol': symbol,
  };
}

class ConfigModel {
  final bool loginEnabled;
  final bool maintenanceMode;
  final int maxDevices;
  final bool pushNotificationsEnabled;

  ConfigModel({
    required this.loginEnabled,
    required this.maintenanceMode,
    required this.maxDevices,
    required this.pushNotificationsEnabled,
  });

  factory ConfigModel.fromJson(Map<String, dynamic> json) {
    return ConfigModel(
      loginEnabled: parseField<bool>(json['login_enabled']) ?? false,
      maintenanceMode: parseField<bool>(json['maintenance_mode']) ?? false,
      maxDevices: parseField<int>(json['max_devices']) ?? 0,
      pushNotificationsEnabled:
          parseField<bool>(json['push_notifications_enabled']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
    'login_enabled': loginEnabled,
    'maintenance_mode': maintenanceMode,
    'max_devices': maxDevices,
    'push_notifications_enabled': pushNotificationsEnabled,
  };
}

class FeatureModel {
  final String code;
  final String name;
  final bool active;
  final GpsModel? gps;

  FeatureModel({
    required this.code,
    required this.name,
    required this.active,
    this.gps,
  });

  factory FeatureModel.fromJson(Map<String, dynamic> json) {
    return FeatureModel(
      code: parseField<String>(json['code']) ?? '',
      name: parseField<String>(json['name']) ?? '',
      active: parseField<bool>(json['active']) ?? false,
      gps: json['gps'] is Map<String, dynamic>
          ? GpsModel.fromJson(json['gps'])
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'name': name,
    'active': active,
    if (gps != null) 'gps': gps!.toJson(),
  };
}

class GpsModel {
  final bool enabled;
  final bool checkinRequired;
  final bool checkoutRequired;
  final double companyLatitude;
  final double companyLongitude;
  final int boundaryMeters;

  GpsModel({
    required this.enabled,
    required this.checkinRequired,
    required this.checkoutRequired,
    required this.companyLatitude,
    required this.companyLongitude,
    required this.boundaryMeters,
  });

  factory GpsModel.fromJson(Map<String, dynamic> json) {
    return GpsModel(
      enabled: parseField<bool>(json['enabled']) ?? false,
      checkinRequired: parseField<bool>(json['checkin_required']) ?? false,
      checkoutRequired: parseField<bool>(json['checkout_required']) ?? false,
      companyLatitude: parseField<double>(json['company_latitude']) ?? 0.0,
      companyLongitude: parseField<double>(json['company_longitude']) ?? 0.0,
      boundaryMeters: parseField<int>(json['boundary_meters']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'checkin_required': checkinRequired,
    'checkout_required': checkoutRequired,
    'company_latitude': companyLatitude,
    'company_longitude': companyLongitude,
    'boundary_meters': boundaryMeters,
  };
}
