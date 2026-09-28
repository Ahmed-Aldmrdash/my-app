import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'data/app_store.dart';
import 'models/models.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

class StudyPlannerApp extends StatelessWidget {
  const StudyPlannerApp({super.key, required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: store,
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
