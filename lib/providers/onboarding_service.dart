import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be provided in main().');
});

final onboardingServiceProvider = Provider<OnboardingService>((ref) {
  return OnboardingService(ref.watch(sharedPreferencesProvider));
});

class OnboardingService {
  OnboardingService(this._preferences);

  static const _completedKey = 'onboarding_completed';
  final SharedPreferences _preferences;

  bool get isCompleted => _preferences.getBool(_completedKey) ?? false;

  Future<void> complete() async {
    await _preferences.setBool(_completedKey, true);
  }
}
