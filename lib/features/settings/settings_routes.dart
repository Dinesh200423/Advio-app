import 'package:go_router/go_router.dart';

import '../../app/router/navigator_keys.dart';
import '../../app/router/routes.dart';
import 'preference_screens.dart';
import 'profile_forms.dart';
import 'settings_screen.dart';

final settingsRoutes = <RouteBase>[
  GoRoute(
    path: Routes.settings,
    builder: (_, _) => const SettingsScreen(),
    routes: [
      GoRoute(path: 'profile', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const ProfileFormScreen()),
      GoRoute(path: 'business', parentNavigatorKey: rootNavigatorKey, builder: (_, _) => const BusinessFormScreen()),
      GoRoute(path: 'currency', builder: (_, _) => const CurrencyScreen()),
      GoRoute(path: 'notifications', builder: (_, _) => const NotificationSettingsScreen()),
      GoRoute(path: 'appearance', builder: (_, _) => const AppearanceScreen()),
      GoRoute(path: 'about', builder: (_, _) => const AboutScreen()),
    ],
  ),
];
