import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class TaskManagerConnectivityListener {
  final StreamController<bool> _onConnectivityChanged;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;
  late bool _isConnected;

  TaskManagerConnectivityListener()
      : _onConnectivityChanged = StreamController<bool>.broadcast() {
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((ConnectivityResult event) {
      _isConnected = event.connected;
      _onConnectivityChanged.add(_isConnected);
    });
  }

  bool get isConnectionAvailable {
    try {
      return _isConnected;
    } catch (err) {
      return false;
    }
  }

  Stream<bool> get onConnectivityChanged => _onConnectivityChanged.stream;

  void dispose() {
    _onConnectivityChanged.close();
    _connectivitySubscription.cancel();
  }
}

extension _ConnectivityExtension on ConnectivityResult {
  bool get connected => <ConnectivityResult>[
        ConnectivityResult.ethernet,
        ConnectivityResult.mobile,
        ConnectivityResult.wifi,
      ].contains(this);
}
