import 'package:flutter/material.dart';
import '../../../data/models/notification_model.dart';
import '../../../domain/usecases/get_notifications_usecase.dart';
import '../../../domain/usecases/dismiss_notification_usecase.dart';

class NotificationProvider extends ChangeNotifier {
  final GetNotificationsUseCase getNotificationsUseCase;
  final DismissNotificationUseCase dismissNotificationUseCase;

  NotificationProvider({
    required this.getNotificationsUseCase,
    required this.dismissNotificationUseCase,
  });

  List<NotificationItem> _notifications = [];
  List<NotificationItem> get notifications => _notifications;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isLoadingMore = false;
  bool get isLoadingMore => _isLoadingMore;

  bool _hasNextPage = true;
  bool get hasNextPage => _hasNextPage;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  int _currentPage = 1;

  Future<void> fetchNotifications({bool refresh = false}) async {
    if (refresh) {
      if (_isLoading) return;
      _currentPage = 1;
      _hasNextPage = true;
      _notifications.clear();
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
    } else {
      if (_isLoading || _isLoadingMore || !_hasNextPage) return;
      if (_notifications.isEmpty) {
        _isLoading = true;
      } else {
        _isLoadingMore = true;
      }
      _errorMessage = null;
      notifyListeners();
    }

    try {
      final response = await getNotificationsUseCase(
        page: _currentPage,
        limit: 20,
      );

      if (refresh) {
        _notifications = response.notifications;
      } else {
        final existingIds = _notifications.map((n) => n.id).toSet();
        final newNotifications = response.notifications
            .where((n) => !existingIds.contains(n.id))
            .toList();
        _notifications.addAll(newNotifications);
      }

      _hasNextPage = response.pagination.hasNext;
      if (_hasNextPage) {
        _currentPage++;
      }
    } catch (e) {
      debugPrint('Error fetching notifications: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      _isLoadingMore = false;
      notifyListeners();
    }
  }

  Future<void> dismissNotification(int id) async {
    final index = _notifications.indexWhere((item) => item.id == id);
    if (index == -1) return;

    final removedItem = _notifications.removeAt(index);
    notifyListeners();

    try {
      await dismissNotificationUseCase(id);
    } catch (e) {
      debugPrint('Error dismissing notification: $e');
      // Rollback on error
      if (index <= _notifications.length) {
        _notifications.insert(index, removedItem);
      } else {
        _notifications.add(removedItem);
      }
      notifyListeners();
    }
  }

  Map<String, List<NotificationItem>> get groupedNotifications {
    final Map<String, List<NotificationItem>> grouped = {};

    // 1. Group unread notifications under 'NEW' at the top
    final unread = _notifications.where((n) => !n.isRead).toList();
    if (unread.isNotEmpty) {
      grouped['NEW'] = unread;
    }

    // 2. Group read notifications by date category
    final readNotifications = _notifications.where((n) => n.isRead);
    for (var item in readNotifications) {
      final header = _getDateHeader(item.date);
      if (!grouped.containsKey(header)) {
        grouped[header] = [];
      }
      grouped[header]!.add(item);
    }
    return grouped;
  }

  String _getDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final twoDaysAgo = today.subtract(const Duration(days: 2));

    final itemDate = DateTime(date.year, date.month, date.day);

    if (itemDate == today) {
      return 'TODAY';
    } else if (itemDate == yesterday) {
      return 'YESTERDAY';
    } else if (itemDate == twoDaysAgo) {
      return '2 DAYS AGO';
    } else {
      final months = [
        'JAN',
        'FEB',
        'MAR',
        'APR',
        'MAY',
        'JUN',
        'JUL',
        'AUG',
        'SEP',
        'OCT',
        'NOV',
        'DEC',
      ];
      return '${date.day} ${months[date.month - 1]} ${date.year}';
    }
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }
}
