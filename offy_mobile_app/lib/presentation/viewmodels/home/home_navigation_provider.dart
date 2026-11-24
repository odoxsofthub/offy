import 'package:flutter/foundation.dart';

enum HomeTab { home, attendance, expense, profile }

class HomeNavigationProvider extends ChangeNotifier {
  HomeTab _currentTab = HomeTab.home;
  HomeTab _previousTab = HomeTab.home;
  int _currentIndex = 0;
  int _previousIndex = 0;
  bool _suppressNextTabFetch = false;

  HomeTab get currentTab => _currentTab;
  HomeTab get previousTab => _previousTab;
  int get currentIndex => _currentIndex;
  int get previousIndex => _previousIndex;
  bool get suppressNextTabFetch => _suppressNextTabFetch;

  void changeTab(HomeTab tab, int index) {
    if (_currentTab != tab || _currentIndex != index) {
      _suppressNextTabFetch = false;
      _previousTab = _currentTab;
      _previousIndex = _currentIndex;
      _currentTab = tab;
      _currentIndex = index;
      notifyListeners();
    }
  }

  void switchToTab(HomeTab tab) {
    if (_currentTab != tab) {
      _suppressNextTabFetch = false;
      _previousTab = _currentTab;
      _previousIndex = _currentIndex;
      _currentTab = tab;
      notifyListeners();
    }
  }

  void resetToHome() {
    changeTab(HomeTab.home, 0);
  }

  void changeIndex(int index) {
    if (_currentIndex != index) {
      _suppressNextTabFetch = false;
      _previousIndex = _currentIndex;
      _currentIndex = index;
      notifyListeners();
    }
  }

  void goBackToPreviousTab() {
    _suppressNextTabFetch = true;
    _currentTab = _previousTab;
    _currentIndex = _previousIndex;
    notifyListeners();
  }

  /// Consumes the suppress flag. Returns true once if returning from an error screen,
  /// then resets to false immediately so subsequent fetches work normally.
  bool consumeSuppressNextTabFetch() {
    final val = _suppressNextTabFetch;
    _suppressNextTabFetch = false;
    return val;
  }
}

