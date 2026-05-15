/// Path constants. Keep them grouped by feature so feature deletion is a
/// single import to remove.
class Routes {
  Routes._();

  static const String root = '/';

  // Onboarding (S01–S04)
  static const String onboardingEmpty = '/onboarding/empty';
  static const String onboardingWifi = '/onboarding/wifi';
  static const String onboardingDiscovery = '/onboarding/discovery';
  static const String onboardingNamePlace = '/onboarding/name-place';

  // Dashboard
  static const String dashboard = '/dashboard';
}
