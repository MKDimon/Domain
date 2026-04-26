import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/auth/oauth_handler.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'core/update/update_gate.dart';
import 'l10n/app_localizations.dart';

class DomainApp extends ConsumerWidget {
  const DomainApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(oauthHandlerProvider);
    final themeMode = ref.watch(themeProvider);

    return UpdateGate(
      child: MaterialApp.router(
        title: 'Domain',
        debugShowCheckedModeBanner: false,
        themeMode: themeMode,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        routerConfig: appRouter,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    );
  }
}
