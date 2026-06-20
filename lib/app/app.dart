import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme.dart';
import 'routes.dart';
import 'package:agro_ledger/utils/constants.dart';

class AgroLedgerApp extends ConsumerStatefulWidget {
  const AgroLedgerApp({super.key});

  @override
  ConsumerState<AgroLedgerApp> createState() => _AgroLedgerAppState();
}

class _AgroLedgerAppState extends ConsumerState<AgroLedgerApp> {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRoutes.generateRoute,
      initialRoute: AppConstants.routeSplash,
      navigatorKey: AppRoutes.navigatorKey,
    );
  }
}