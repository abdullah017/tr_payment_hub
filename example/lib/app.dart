import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/providers/app_state.dart';
import 'core/theme/app_theme.dart';
import 'features/home/home_screen.dart';

/// Main application widget with Provider setup and theming.
class TRPaymentHubExampleApp extends StatelessWidget {
  const TRPaymentHubExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppState()..initialize(),
      child: Consumer<AppState>(
        builder: (context, state, _) {
          return MaterialApp(
            title: 'TR Payment Hub Example',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: state.themeMode,
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
