import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'app/app.dart';
import 'core/observability/observability.dart';
import 'data/backend/backend_config.dart';

Future<void> main() async {
  // Everything runs inside runObserved, so errors anywhere are logged (and reported, if configured).
  await runObserved(() async {
    WidgetsFlutterBinding.ensureInitialized();
    // Inter and Krona One are bundled under /google_fonts, so never hit the network for fonts.
    GoogleFonts.config.allowRuntimeFetching = false;
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp, DeviceOrientation.portraitDown]);
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ));
    if (BackendConfig.isConfigured) {
      await Supabase.initialize(url: BackendConfig.supabaseUrl, publishableKey: BackendConfig.supabaseAnonKey);
    }
    runApp(const AdvioRoot());
  });
}
