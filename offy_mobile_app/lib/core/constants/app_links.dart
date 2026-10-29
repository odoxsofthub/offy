/// External web links the app opens in the device browser.
class AppLinks {
  AppLinks._(); // Private constructor to prevent instantiation

  /// Where to download the OFFY Connector Odoo module, opened by "Install now"
  /// on the last onboarding step and on the login page.
  static final Uri odooModuleInstall = Uri.parse(
    'https://github.com/odoxsofthub/offy/tree/offy-odoo-19-enterprise',
  );

  /// App update feed (Sparkle appcast), set at build time with `APPCAST_URL`.
  /// Null when unset or not an http(s) URL: the update check is then disabled.
  static final Uri? appcast = parseAppcastUrl(
    const String.fromEnvironment('APPCAST_URL'),
  );

  /// Returns [raw] as an absolute http(s) URI, or null.
  static Uri? parseAppcastUrl(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasAuthority) return null;
    return uri.isScheme('https') || uri.isScheme('http') ? uri : null;
  }
}
