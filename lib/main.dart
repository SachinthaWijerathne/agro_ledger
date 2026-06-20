import 'package:agro_ledger/services/local_storage_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agro_ledger/app/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Local Database
  try {
    final localStorage = await LocalStorageService.getInstance();
    // await localStorage.clearAllData();
    debugPrint('✅ Database initialized successfully');
  } catch (e) {
    debugPrint('❌ Database initialization error: $e');
  }
  runApp(const ProviderScope(child: AgroLedgerApp()));
}
