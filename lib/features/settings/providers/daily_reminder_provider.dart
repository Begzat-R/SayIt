import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/motivation_service.dart';

class DailyReminderState {
  final bool loading;
  final bool enabled;
  final TimeOfDay time;
  final String? permissionDeniedMessage;

  const DailyReminderState({
    this.loading = true,
    this.enabled = false,
    this.time = MotivationService.defaultTime,
    this.permissionDeniedMessage,
  });

  DailyReminderState copyWith({
    bool? loading,
    bool? enabled,
    TimeOfDay? time,
    Object? permissionDeniedMessage = _unset,
  }) {
    return DailyReminderState(
      loading: loading ?? this.loading,
      enabled: enabled ?? this.enabled,
      time: time ?? this.time,
      permissionDeniedMessage: identical(permissionDeniedMessage, _unset)
          ? this.permissionDeniedMessage
          : permissionDeniedMessage as String?,
    );
  }
}

const _unset = Object();

class DailyReminderNotifier extends StateNotifier<DailyReminderState> {
  DailyReminderNotifier() : super(const DailyReminderState()) {
    _load();
  }

  Future<void> _load() async {
    final enabled = await MotivationService.isEnabled();
    final time = await MotivationService.loadTime();
    state = state.copyWith(loading: false, enabled: enabled, time: time);
  }

  Future<void> setEnabled(bool value) async {
    final previous = state;
    try {
      if (value) {
        final granted = await MotivationService.requestPermission();
        if (!granted) {
          state = state.copyWith(
            enabled: false,
            permissionDeniedMessage:
                "Notifications are turned off for Cadence, so the daily reminder can't fire. Enable them in system settings.",
          );
          return;
        }
        await MotivationService.scheduleDaily(state.time);
      } else {
        await MotivationService.cancelDaily();
      }
      state = state.copyWith(enabled: value, permissionDeniedMessage: null);
    } catch (e, stackTrace) {
      // Whatever failed (native plugin error, scheduling error, etc.), land
      // on a known state instead of leaving the toggle silently inert — a
      // bare `onChanged: (v) => notifier.setEnabled(v)` doesn't await this
      // future, so an uncaught exception here would otherwise vanish as an
      // unhandled Future rejection and never touch `state` again.
      debugPrint('[DailyReminderNotifier] setEnabled($value) failed: $e\n$stackTrace');
      state = previous.copyWith(
        permissionDeniedMessage:
            "Couldn't ${value ? 'turn on' : 'turn off'} the daily reminder. Please try again.",
      );
    }
  }

  Future<void> setTime(TimeOfDay time) async {
    state = state.copyWith(time: time);
    if (state.enabled) {
      await MotivationService.scheduleDaily(time);
    }
  }

  void dismissPermissionMessage() =>
      state = state.copyWith(permissionDeniedMessage: null);
}

final dailyReminderProvider =
    StateNotifierProvider<DailyReminderNotifier, DailyReminderState>(
  (ref) => DailyReminderNotifier(),
);
