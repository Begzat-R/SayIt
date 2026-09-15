import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingState {
  final Set<String> selectedGoals;
  final String name;

  const OnboardingState({
    this.selectedGoals = const {},
    this.name = '',
  });

  OnboardingState copyWith({
    Set<String>? selectedGoals,
    String? name,
  }) {
    return OnboardingState(
      selectedGoals: selectedGoals ?? this.selectedGoals,
      name: name ?? this.name,
    );
  }
}

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void toggleGoal(String goal) {
    final current = Set<String>.from(state.selectedGoals);
    if (current.contains(goal)) {
      current.remove(goal);
    } else {
      current.add(goal);
    }
    state = state.copyWith(selectedGoals: current);
  }

  void setName(String name) {
    state = state.copyWith(name: name);
  }

  Future<void> complete() async {
    final prefs = await SharedPreferences.getInstance();
    if (state.name.isNotEmpty) {
      await prefs.setString('user_name', state.name);
    }
    await prefs.setBool('onboarding_complete', true);
  }
}

final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
  return OnboardingNotifier();
});
