import 'dart:async';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'internet_state.dart';

class InternetNotifier extends Notifier<InternetState>
    with WidgetsBindingObserver {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription? _connectivitySubscription;
  Timer? _pollTimer;
  Timer? _debounceTimer;

  bool _isAppInForeground = true;
  int _consecutiveOfflineChecks = 0;

  static const _onlinePollInterval = Duration(seconds: 20);

  // Kept short even at max backoff — recovery speed matters more than
  // saving a few DNS lookups here.
  static const _offlinePollBase = Duration(seconds: 2);
  static const _offlinePollMax = Duration(seconds: 6);

  // Short debounce — just enough to coalesce rapid-fire stream events,
  // not enough to feel like a delay.
  static const _debounceDelay = Duration(milliseconds: 300);

  /// Plain field (not part of state) — mirrors old cubit behavior.
  bool isInternetScreenShown = false;

  @override
  InternetState build() {
    WidgetsBinding.instance.addObserver(this);

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen(
          (_) => _debouncedCheck(),
    );

    checkInternet(); // initial check, also schedules the next poll

    ref.onDispose(() {
      WidgetsBinding.instance.removeObserver(this);
      _connectivitySubscription?.cancel();
      _pollTimer?.cancel();
      _debounceTimer?.cancel();
    });

    return const InternetState(isConnected: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Renamed param (was `state`) — it was shadowing the Notifier's own
    // `state` field (InternetState), which is a landmine for future edits
    // even though nothing here referenced it yet.
    _isAppInForeground = state == AppLifecycleState.resumed;

    if (_isAppInForeground) {
      // Coming back to foreground — state may be stale, check right away
      // and resume polling.
      checkInternet();
    } else {
      // No point polling while backgrounded — saves battery/data.
      // Also cancel any pending debounced check: if a connectivity event
      // fired right as we backgrounded, we don't want it sneaking a
      // check through 300ms later while paused.
      _pollTimer?.cancel();
      _debounceTimer?.cancel();
    }
  }

  void _debouncedCheck() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(_debounceDelay, checkInternet);
  }

  Future<void> checkInternet() async {
    final hasInternet = await _hasInternetAccess();

    _consecutiveOfflineChecks = hasInternet ? 0 : _consecutiveOfflineChecks + 1;

    if (state.isConnected != hasInternet) {
      state = InternetState(isConnected: hasInternet);
    }

    _scheduleNextPoll(hasInternet);
  }

  void _scheduleNextPoll(bool isConnected) {
    if (!_isAppInForeground) return;

    _pollTimer?.cancel();
    final interval =
    isConnected ? _onlinePollInterval : _offlineBackoffInterval();
    _pollTimer = Timer(interval, checkInternet);
  }

  Duration _offlineBackoffInterval() {
    final seconds = (_offlinePollBase.inSeconds * _consecutiveOfflineChecks)
        .clamp(_offlinePollBase.inSeconds, _offlinePollMax.inSeconds);
    return Duration(seconds: seconds);
  }

  Future<bool> _hasInternetAccess() async {
    const hosts = ['google.com', 'cloudflare.com'];
    for (final host in hosts) {
      try {
        final result = await InternetAddress.lookup(
          host,
        ).timeout(const Duration(seconds: 2));
        if (result.isNotEmpty && result.first.rawAddress.isNotEmpty) {
          return true;
        }
      } catch (_) {
        // try next host
      }
    }
    return false;
  }

  Future<void> retry() async {
    _consecutiveOfflineChecks = 0; // manual retry resets backoff
    await checkInternet();
  }
}

final internetProvider =
NotifierProvider<InternetNotifier, InternetState>(InternetNotifier.new);