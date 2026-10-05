import 'package:flutter/foundation.dart';

/// Lightweight service monitoring local-first status and offline availability
abstract class ConnectivityService {
  ValueListenable<bool> get isOnline;
  bool get currentStatus;
  void setOnlineStatus(bool online);
}

class ConnectivityServiceImpl implements ConnectivityService {
  final ValueNotifier<bool> _isOnline = ValueNotifier<bool>(true);

  @override
  ValueListenable<bool> get isOnline => _isOnline;

  @override
  bool get currentStatus => _isOnline.value;

  @override
  void setOnlineStatus(bool online) {
    if (_isOnline.value != online) {
      _isOnline.value = online;
    }
  }
}
