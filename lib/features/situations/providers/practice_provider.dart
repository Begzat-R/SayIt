import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PracticeSession {
  final String scenarioId;
  final bool feltGood;
  final DateTime timestamp;

  const PracticeSession({
    required this.scenarioId,
    required this.feltGood,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'scenarioId': scenarioId,
        'feltGood': feltGood,
        'timestamp': timestamp.millisecondsSinceEpoch,
      };

  factory PracticeSession.fromJson(Map<String, dynamic> json) => PracticeSession(
        scenarioId: json['scenarioId'] as String,
        feltGood: json['feltGood'] as bool,
        timestamp:
            DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      );
}

class PracticeSessionsNotifier extends StateNotifier<List<PracticeSession>> {
  PracticeSessionsNotifier() : super([]) {
    _load();
  }

  static const _key = 'practice_sessions_v1';

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null) return;
    try {
      final list = (jsonDecode(raw) as List)
          .map((e) => PracticeSession.fromJson(e as Map<String, dynamic>))
          .toList();
      state = list;
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      jsonEncode(state.map((s) => s.toJson()).toList()),
    );
  }

  void addSession(String scenarioId, bool feltGood) {
    state = [
      ...state,
      PracticeSession(
        scenarioId: scenarioId,
        feltGood: feltGood,
        timestamp: DateTime.now(),
      ),
    ];
    _save();
  }
}

final practiceSessionsProvider =
    StateNotifierProvider<PracticeSessionsNotifier, List<PracticeSession>>((ref) {
  return PracticeSessionsNotifier();
});

final thisWeekSessionCountProvider = Provider<int>((ref) {
  final sessions = ref.watch(practiceSessionsProvider);
  final now = DateTime.now();
  final weekStart = now.subtract(Duration(days: now.weekday - 1));
  final weekStartDay =
      DateTime(weekStart.year, weekStart.month, weekStart.day);
  return sessions.where((s) => s.timestamp.isAfter(weekStartDay)).length;
});
