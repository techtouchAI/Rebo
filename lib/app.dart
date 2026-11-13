import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'presentation/screens/grade_picker_screen.dart';
import 'presentation/screens/landing_shell.dart';
import 'presentation/state/app_state.dart';

/// Root widget: Arabic-only, RTL by locale, with a user controlled text scale.
class MirsamApp extends StatelessWidget {
  const MirsamApp({super.key});

  @override
  Widget build(BuildContext context) {
    final state = AppScope.of(context);
    return MaterialApp(
      title: 'مِرسم',
      debugShowCheckedModeBanner: false,
      locale: const Locale('ar'),
      supportedLocales: const <Locale>[Locale('ar')],
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: state.themeMode,
      builder: (BuildContext context, Widget? child) {
        final media = MediaQuery.of(context);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(state.textScale)),
          child: child ?? const SizedBox.shrink(),
        );
      },
      home: state.hasGrade ? const LandingShell() : const GradePickerScreen(),
    );
  }
}
