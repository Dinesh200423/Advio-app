import 'package:flutter/widgets.dart';

/// Root navigator: used for full-screen flows (forms, auth) that hide the bottom navigation.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Shell navigator: screens that keep the bottom navigation visible.
final GlobalKey<NavigatorState> shellNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'shell');
