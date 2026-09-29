import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'models/models.dart';
import 'screens/home_shell.dart';
import 'sync/sync_service.dart';
import 'theme/app_theme.dart';

class StudyPlannerApp extends StatelessWidget {
  StudyPlannerApp({super.key, required this.store, SyncService? sync})
    : sync = sync ?? SyncService(store);

  final AppStore store;
  final SyncService sync;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: sync),
      ],
      child: Selector<AppStore, AppThemeMode>(
        selector: (_, s) => s.settings.themeMode,
        builder: (context, mode, _) => MaterialApp(
          title: 'منظم دراستي',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: buildTheme(Brightness.light),
          darkTheme: buildTheme(Brightness.dark),
          themeMode: switch (mode) {
            AppThemeMode.system => ThemeMode.system,
            AppThemeMode.light => ThemeMode.light,
            AppThemeMode.dark => ThemeMode.dark,
          },
          home: const HomeShell(),
        ),
      ),
    );
  }
}
