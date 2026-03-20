import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/app_theme.dart';
import 'core/supabase_config.dart';
import 'core/theme_provider.dart';
import 'core/providers/profile_providers.dart';
import 'router.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Resample touch events to align with frame timing — reduces input jank
  GestureBinding.instance.resamplingEnabled = true;

  await Supabase.initialize(
    url: SupabaseConfig.url,
    anonKey: SupabaseConfig.anonKey,
  );

  runApp(const ProviderScope(child: LikewiseApp()));
}

class LikewiseApp extends ConsumerWidget {
  const LikewiseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = ref.watch(appColorSchemeProvider);
    final router = ref.watch(routerProvider);

    // Restore the user's saved theme preference whenever their profile loads.
    // This fires whenever fullProfileProvider transitions from loading → data,
    // which covers both fresh launches and post-login profile fetches.
    ref.listen(fullProfileProvider, (_, next) {
      next.whenData((profile) {
        if (profile == null) return;
        final saved = AppColorScheme.presets.firstWhere(
          (s) => s.name == profile.themePreference,
          orElse: () => AppColorScheme.presets[0],
        );
        if (ref.read(appColorSchemeProvider).name != saved.name) {
          ref.read(appColorSchemeProvider.notifier).setScheme(saved);
        }
      });
    });

    return MaterialApp.router(
      title: 'Likewise',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(colors.primary),
      darkTheme: AppTheme.darkTheme(colors.primary),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
