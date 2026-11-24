import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:internet_connection_checker/internet_connection_checker.dart';

import '../../data/models/log_note_model.dart';
import '../../l10n/app_localizations.dart';
import '../../presentation/widgets/common/custom_snackbar.dart';
import '../navigation/app_router.dart';

/// What a lost-reply check found.
enum LostSubmissionResult { saved, notSaved, unconfirmed }

/// After a lost reply: waits for the connection, checks [isSaved], refreshes and tells
/// the user. Never resends, so it cannot create a duplicate.
class LostSubmissionChecker {
  LostSubmissionChecker._();

  /// How long to wait for the connection before giving up.
  static const Duration connectionWait = Duration(minutes: 2);

  /// Time for the server to commit a request still running when the connection dropped.
  static const Duration settleDelay = Duration(seconds: 2);

  /// Runs in the background. [isSaved] is true when the record exists;
  /// [label] names it in the message ("expense", "time off request").
  static void start({
    required String Function(AppLocalizations? l10n) label,
    required Future<bool> Function() isSaved,
    Future<void> Function()? refresh,
  }) {
    unawaited(_run(label: label, isSaved: isSaved, refresh: refresh));
  }

  /// [start] for a chat message: saved when the refetched thread has a new
  /// message of the user's (not in [before]) with the same text.
  static void startLogNote({
    required List<LogNoteModel> before,
    required String text,
    required Future<List<LogNoteModel>> Function() fetch,
    required Future<void> Function() refresh,
  }) {
    String normalize(String? value) =>
        (value ?? '').replaceAll(RegExp(r'\s+'), ' ').trim();
    final knownIds = before.map((note) => note.id).toSet();
    final wanted = normalize(text);
    start(
      label: (l10n) => l10n?.lostSubmissionMessage ?? 'message',
      refresh: refresh,
      isSaved: () async => (await fetch()).any(
        (note) =>
            note.isUser == true &&
            !knownIds.contains(note.id) &&
            normalize(note.message).contains(wanted),
      ),
    );
  }

  static Future<LostSubmissionResult> _run({
    required String Function(AppLocalizations? l10n) label,
    required Future<bool> Function() isSaved,
    Future<void> Function()? refresh,
  }) async {
    var result = LostSubmissionResult.unconfirmed;
    if (await _waitForConnection()) {
      await Future<void>.delayed(settleDelay);
      try {
        result = await isSaved()
            ? LostSubmissionResult.saved
            : LostSubmissionResult.notSaved;
      } catch (e) {
        debugPrint('[LostSubmissionChecker] check failed: $e');
      }
      // Whatever the check said, the screens show the server's current data.
      try {
        if (refresh != null) await refresh();
      } catch (e) {
        debugPrint('[LostSubmissionChecker] refresh failed: $e');
      }
    }
    _notify(result, label);
    return result;
  }

  static Future<bool> _waitForConnection() async {
    final deadline = DateTime.now().add(connectionWait);
    while (DateTime.now().isBefore(deadline)) {
      final online = await InternetConnectionChecker.instance.hasConnection
          .timeout(const Duration(seconds: 5), onTimeout: () => false);
      if (online) return true;
      await Future<void>.delayed(const Duration(seconds: 3));
    }
    return false;
  }

  static void _notify(
    LostSubmissionResult result,
    String Function(AppLocalizations? l10n) label,
  ) {
    final context = AppRouter.navigatorKey.currentContext;
    if (context == null || !context.mounted) return;
    final l10n = AppLocalizations.of(context);
    final item = label(l10n);
    switch (result) {
      case LostSubmissionResult.saved:
        CustomSnackbar.show(
          context,
          message:
              l10n?.lostSubmissionSaved(item) ??
              'Connection was lost, but your $item was saved.',
          isSuccess: true,
          duration: const Duration(seconds: 4),
        );
      case LostSubmissionResult.notSaved:
        CustomSnackbar.show(
          context,
          message:
              l10n?.lostSubmissionNotSaved(item) ??
              'Connection was lost and your $item was not saved. '
                  'Please submit it again.',
          isError: true,
          duration: const Duration(seconds: 5),
        );
      case LostSubmissionResult.unconfirmed:
        CustomSnackbar.show(
          context,
          message:
              l10n?.lostSubmissionUnconfirmed(item) ??
              'Connection was lost. Refresh to check whether your $item '
                  'was saved before submitting it again.',
          isError: true,
          duration: const Duration(seconds: 5),
        );
    }
  }
}
