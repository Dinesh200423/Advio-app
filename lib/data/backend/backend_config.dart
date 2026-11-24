/// Where the app finds its backend. The values are supplied at build time, never written in code:
///
///   flutter run --dart-define-from-file=env.json
///
/// See env.example.json. With no values the app runs on built-in sample data.
abstract final class BackendConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');

  /// The anon ("publishable") key. It is safe in the app because Row Level Security decides what it can read.
  /// Never put the service_role key here.
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  static bool get isConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;
}
