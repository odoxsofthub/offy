import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/services/realtime_sync_service.dart';
import '../../../data/models/realtime_models.dart';
import '../../viewmodels/attendance/attendance_provider.dart';
import '../../viewmodels/home/home_provider.dart';
import '../../viewmodels/user/access_provider.dart';

/// Connects the realtime socket to the providers for as long as its subtree
/// is mounted.
class RealtimeSyncBinder extends StatefulWidget {
  const RealtimeSyncBinder({
    super.key,
    required this.service,
    required this.child,
  });

  final RealtimeSyncService service;
  final Widget child;

  @override
  State<RealtimeSyncBinder> createState() => _RealtimeSyncBinderState();
}

class _RealtimeSyncBinderState extends State<RealtimeSyncBinder>
    with WidgetsBindingObserver {
  StreamSubscription<List<String>>? _sectionsSub;
  StreamSubscription<RealtimeMessage>? _accessSub;
  Timer? _debounce;

  final Set<String> _pending = {};

  static const Set<String> _homeCardSections = {
    'attendance', 'time_off', 'expense', 'payslip', 'calendar',
    // Bell dot: refetch /home for `has_unread_notifications`.
    'notifications',
  };

  static const Duration _coalesceWindow = Duration(milliseconds: 400);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sectionsSub = widget.service.staleSections.listen(_onSections);
    _accessSub = widget.service.accessUpdates.listen(_onAccess);
    unawaited(widget.service.start());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _sectionsSub?.cancel();
    _accessSub?.cancel();
    unawaited(widget.service.stop());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(widget.service.syncOnResume());
    }
  }

  void _onSections(List<String> sections) {
    _pending.addAll(sections);
    _debounce?.cancel();
    _debounce = Timer(_coalesceWindow, _flush);
  }

  void _flush() {
    if (!mounted) return;
    final sections = Set<String>.from(_pending);
    _pending.clear();

    if (sections.intersection(_homeCardSections).isNotEmpty) {
      context.read<HomeProvider>().fetchHomeData(
            context.read<AttendanceProvider>(),
            silent: true,
          );
    }
  }

  void _onAccess(RealtimeMessage message) {
    if (!mounted) return;
    final access = message.access;
    if (access == null) return;
    context.read<AccessProvider>().applyAccessDetails(access);

    _pending.addAll(_homeCardSections);
    _debounce?.cancel();
    _debounce = Timer(_coalesceWindow, _flush);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
