import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';

class LocalStorageService {
  static LocalStorageService? _instance;
  static Database? _database;

  LocalStorageService._internal();

  static Future<LocalStorageService> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorageService._internal();
      await _instance!._init();
    }
    return _instance!;
  }

  Future<void> _init() async {
    try {
      final databasesPath = await getDatabasesPath();
      final path = join(databasesPath, 'agro_ledger.db');

      // Open the database
      _database = await openDatabase(
        path,
        version: 1,
        onCreate: (db, version) async {

          // ===========================================
          // DATABASE SCHEMA
          // ===========================================
          
          //Users who managing and working on the farm
          await db.execute('''
            CREATE TABLE IF NOT EXISTS users (
              id TEXT PRIMARY KEY,
              name TEXT,
              email TEXT,
              phone TEXT,
              role TEXT,
              created_at TEXT,
              updated_at TEXT
            )
          ''');
          debugPrint('✅ Users table created successfully');
          
          //Farms owned by user who owns the farm and managing it
          await db.execute('''
            CREATE TABLE IF NOT EXISTS farms (
              id TEXT PRIMARY KEY,
              user_id TEXT,
              name TEXT,
              location TEXT,
              size REAL,
              created_at TEXT,
              updated_at TEXT,
              FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
            )
          ''');
          debugPrint('✅ Farms table created successfully');

          //Crops grown on the farm
          await db.execute('''
            CREATE TABLE IF NOT EXISTS crops (
              id TEXT PRIMARY KEY,
              farm_id TEXT,
              name TEXT,
              crop_type TEXT,
              created_at TEXT,
              updated_at TEXT,
              FOREIGN KEY (farm_id) REFERENCES farms (id) ON DELETE CASCADE
            )
          ''');
          debugPrint('✅ Crops table created successfully');

          //Harvests from the farm
          await db.execute('''
            CREATE TABLE IF NOT EXISTS harvests (
              id TEXT PRIMARY KEY,
              crop_id TEXT,
              farm_id TEXT,
              quantity REAL,
              worker_count INTEGER,
              transport_cost REAL,
              total_payments REAL,
              harvested_at TEXT,
              created_at TEXT,
              updated_at TEXT,
              FOREIGN KEY (crop_id) REFERENCES crops (id) ON DELETE CASCADE,
              FOREIGN KEY (farm_id) REFERENCES farms (id) ON DELETE CASCADE
            )
          ''');
          debugPrint('✅ Harvests table created successfully');
        },
      );
      debugPrint('✅ Database initialized successfully');
    } catch (e) {
      debugPrint('❌ Database initialization error: $e');
    }
  }
}