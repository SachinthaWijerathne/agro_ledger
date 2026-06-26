// lib/database/local_storage_service.dart
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/foundation.dart';
import '../utils/constants.dart';

class LocalStorageService {
  static LocalStorageService? _instance;
  static Database? _database;

  LocalStorageService._internal();

  static Future<LocalStorageService> getInstance() async {
    if (_instance == null) {
      _instance = LocalStorageService._internal();
      await _instance!._initDatabase();
    }
    return _instance!;
  }

  Future<Database> get database async {
    if (_database == null) {
      await _initDatabase();
    }
    return _database!;
  }

  Future<void> _initDatabase() async {
    String path = join(await getDatabasesPath(), AppConstants.dbName);
    debugPrint('📁 Database path: $path');

    _database = await openDatabase(
      path,
      version: AppConstants.dbVersion,
      onCreate: _onCreate,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
    );
    debugPrint('✅ Database initialized');
  }

  // ============================================
  // DATABASE SCHEMA
  // ============================================

  Future<void> _onCreate(Database db, int version) async {
    debugPrint('📦 Creating Database with version: $version');

    // 1. USER PROFILE
    await db.execute('''
      CREATE TABLE user_profile (
        user_id TEXT PRIMARY KEY NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT NOT NULL,
        address TEXT,
        profile_picture TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL
      )
    ''');
    debugPrint('✅ user_profile table created');

    // 2. FARMS
    await db.execute('''
      CREATE TABLE farms (
        farm_id TEXT PRIMARY KEY NOT NULL,
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        location TEXT,
        size REAL,
        default_transport_cost REAL DEFAULT 0,
        default_payment_method TEXT DEFAULT 'per_kg',
        default_per_kg_rate REAL DEFAULT 5.0,
        default_daily_wage REAL DEFAULT 300.0,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (user_id) REFERENCES user_profile(user_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ farms table created');

    // 3. CROPS
    await db.execute('''
      CREATE TABLE crops (
        crop_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        name TEXT NOT NULL,
        crop_type TEXT NOT NULL CHECK(crop_type IN ('main', 'intercrop')),
        variety TEXT,
        planting_date TEXT,
        plantation_size REAL,
        expected_harvest_date TEXT,
        status TEXT DEFAULT 'active' CHECK(status IN ('active', 'harvested', 'fallow')),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ crops table created');

    // 4. FIELDS
    await db.execute('''
      CREATE TABLE fields (
        field_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        crop_id TEXT,
        name TEXT NOT NULL,
        area REAL,
        soil_type TEXT,
        location TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE SET NULL
      )
    ''');
    debugPrint('✅ fields table created');

    // 5. WORKERS
    await db.execute('''
      CREATE TABLE workers (
  worker_id TEXT PRIMARY KEY NOT NULL,
  farm_id TEXT NOT NULL,
  name TEXT NOT NULL,
  nick_name TEXT NOT NULL,
  gender TEXT CHECK(gender IN ('male', 'female', 'other')),
  phone TEXT,
  address TEXT,
  join_date TEXT,
  is_active INTEGER DEFAULT 1,
  notes TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE
)
    ''');
    debugPrint('✅ workers table created');

    // 6. WORKER PAYMENT SETTINGS
    await db.execute('''
      CREATE TABLE worker_payment_settings (
        setting_id TEXT PRIMARY KEY NOT NULL,
        worker_id TEXT NOT NULL,
        crop_id TEXT,
        payment_method TEXT NOT NULL CHECK(payment_method IN ('per_kg', 'per_day')),
        rate REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE,
        UNIQUE(worker_id, crop_id)
      )
    ''');
    debugPrint('✅ worker_payment_settings table created');

    // 7. LABOR ACTIVITIES
    await db.execute('''
      CREATE TABLE labor_activities (
        activity_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        worker_id TEXT NOT NULL,
        crop_id TEXT NOT NULL,
        field_id TEXT,
        activity_type TEXT NOT NULL CHECK(activity_type IN ('harvesting', 'pruning', 'spraying', 'weeding', 'planting', 'irrigation', 'other')),
        description TEXT,
        start_time TEXT NOT NULL,
        end_time TEXT,
        hours_worked REAL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE,
        FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE,
        FOREIGN KEY (field_id) REFERENCES fields(field_id) ON DELETE SET NULL
      )
    ''');
    debugPrint('✅ labor_activities table created');

    // 8. HARVESTS
    await db.execute('''
      CREATE TABLE harvests (
        harvest_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        crop_id TEXT NOT NULL,
        field_id TEXT,
        date TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT DEFAULT 'kg',
        quality_grade TEXT CHECK(quality_grade IN ('A', 'B', 'C', 'premium', 'standard')),
        harvester_type TEXT CHECK(harvester_type IN ('hired', 'owner', 'family', 'unpaid')),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE,
        FOREIGN KEY (field_id) REFERENCES fields(field_id) ON DELETE SET NULL
      )
    ''');
    debugPrint('✅ harvests table created');

    // 9. HARVEST WORKERS
    await db.execute('''
      CREATE TABLE harvest_workers (
  id TEXT PRIMARY KEY NOT NULL,
  harvest_id TEXT NOT NULL,
  worker_id TEXT NOT NULL,
  quantity_harvested REAL,
  earnings REAL,
  payment_method TEXT CHECK(payment_method IN ('per_kg', 'per_day')),
  rate REAL,
  transport_cost REAL DEFAULT 0,
  is_paid INTEGER DEFAULT 0,
  paid_date TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  FOREIGN KEY (harvest_id) REFERENCES harvests(harvest_id) ON DELETE CASCADE,
  FOREIGN KEY (worker_id) REFERENCES workers(worker_id) ON DELETE CASCADE,
  UNIQUE(harvest_id, worker_id)
)
    ''');
    debugPrint('✅ harvest_workers table created');

    // 10. DEALERS
    await db.execute('''
      CREATE TABLE dealers (
        dealer_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        name TEXT NOT NULL,
        email TEXT,
        phone TEXT NOT NULL,
        address TEXT,
        contact_person TEXT,
        payment_terms TEXT,
        is_active INTEGER DEFAULT 1,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ dealers table created');

    // 11. SALES
    await db.execute('''
      CREATE TABLE sales (
        sale_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        dealer_id TEXT NOT NULL,
        sale_date TEXT NOT NULL,
        invoice_number TEXT,
        total_amount REAL NOT NULL,
        payment_status TEXT CHECK(payment_status IN ('paid', 'pending', 'partial')) DEFAULT 'pending',
        paid_amount REAL DEFAULT 0,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE,
        FOREIGN KEY (dealer_id) REFERENCES dealers(dealer_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ sales table created');

    // 12. SALE ITEMS
    await db.execute('''
      CREATE TABLE sale_items (
        item_id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        crop_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        unit TEXT DEFAULT 'kg',
        price_per_unit REAL NOT NULL,
        total REAL NOT NULL,
        quality_grade TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(sale_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ sale_items table created');

    // 13. PAYMENTS
    await db.execute('''
      CREATE TABLE payments (
        payment_id TEXT PRIMARY KEY NOT NULL,
        sale_id TEXT NOT NULL,
        amount REAL NOT NULL,
        payment_date TEXT NOT NULL,
        payment_method TEXT CHECK(payment_method IN ('cash', 'bank_transfer', 'cheque', 'upi')) NOT NULL,
        reference_number TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES sales(sale_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ payments table created');

    // 14. INVENTORY
    await db.execute('''
      CREATE TABLE inventory (
        item_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT CHECK(category IN ('fertilizer', 'pesticide', 'seed', 'fuel', 'tool')) NOT NULL,
        subcategory TEXT,
        unit TEXT NOT NULL CHECK(unit IN ('bag', 'kg', 'liter', 'piece', 'unit')),
        quantity REAL NOT NULL,
        min_stock_alert REAL DEFAULT 0,
        expiry_date TEXT,
        location TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ inventory table created');

    // 15. INVENTORY CROP ASSIGNMENTS
    await db.execute('''
      CREATE TABLE inventory_crop_assignments (
        id TEXT PRIMARY KEY NOT NULL,
        item_id TEXT NOT NULL,
        crop_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES inventory(item_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE,
        UNIQUE(item_id, crop_id)
      )
    ''');
    debugPrint('✅ inventory_crop_assignments table created');

    // 16. INVENTORY USAGE
    await db.execute('''
      CREATE TABLE inventory_usage (
        usage_id TEXT PRIMARY KEY NOT NULL,
        item_id TEXT NOT NULL,
        crop_id TEXT NOT NULL,
        field_id TEXT,
        quantity_used REAL NOT NULL,
        date_used TEXT NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (item_id) REFERENCES inventory(item_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE,
        FOREIGN KEY (field_id) REFERENCES fields(field_id) ON DELETE SET NULL
      )
    ''');
    debugPrint('✅ inventory_usage table created');

    // 17. PURCHASES
    await db.execute('''
      CREATE TABLE purchases (
        purchase_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        date TEXT NOT NULL,
        supplier_name TEXT,
        total_amount REAL NOT NULL,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ purchases table created');

    // 18. PURCHASE ITEMS
    await db.execute('''
      CREATE TABLE purchase_items (
        id TEXT PRIMARY KEY NOT NULL,
        purchase_id TEXT NOT NULL,
        item_id TEXT NOT NULL,
        quantity REAL NOT NULL,
        cost_per_unit REAL NOT NULL,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (purchase_id) REFERENCES purchases(purchase_id) ON DELETE CASCADE,
        FOREIGN KEY (item_id) REFERENCES inventory(item_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ purchase_items table created');

    // 19. TOOLS
    await db.execute('''
      CREATE TABLE tools (
        tool_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        name TEXT NOT NULL,
        category TEXT CHECK(category IN ('harvesting', 'pruning', 'spraying', 'general')) NOT NULL,
        quantity_owned REAL NOT NULL,
        quantity_functioning REAL,
        status TEXT CHECK(status IN ('available', 'broken', 'repairshop', 'rented', 'borrowed', 'lent')) DEFAULT 'available',
        acquisition_phase TEXT CHECK(acquisition_phase IN ('purchased', 'borrowed', 'rented', 'inherited', 'gift')),
        purchase_cost REAL,
        rental_cost_per_day REAL,
        borrowed_from TEXT,
        lent_to TEXT,
        borrowed_date TEXT,
        expected_return_date TEXT,
        location TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ tools table created');

    // 20. TOOL CROP ASSIGNMENTS
    await db.execute('''
      CREATE TABLE tool_crop_assignments (
        id TEXT PRIMARY KEY NOT NULL,
        tool_id TEXT NOT NULL,
        crop_id TEXT NOT NULL,
        created_at TEXT NOT NULL,
        FOREIGN KEY (tool_id) REFERENCES tools(tool_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE CASCADE,
        UNIQUE(tool_id, crop_id)
      )
    ''');
    debugPrint('✅ tool_crop_assignments table created');

    // 21. TOOL MAINTENANCE
    await db.execute('''
      CREATE TABLE tool_maintenance (
        maintenance_id TEXT PRIMARY KEY NOT NULL,
        tool_id TEXT NOT NULL,
        date TEXT NOT NULL,
        type TEXT CHECK(type IN ('sharpening', 'cleaning', 'repair', 'parts_replacement')) NOT NULL,
        cost REAL,
        performed_by TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (tool_id) REFERENCES tools(tool_id) ON DELETE CASCADE
      )
    ''');
    debugPrint('✅ tool_maintenance table created');

    // 22. TRANSPORT ENTRIES
    await db.execute('''
      CREATE TABLE transport_entries (
        id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        harvest_id TEXT,
        date TEXT NOT NULL,
        vehicle_type TEXT CHECK(vehicle_type IN ('auto', 'tractor', 'bus', 'shared_auto', 'own_vehicle')) NOT NULL,
        total_cost REAL NOT NULL,
        workers_count INTEGER,
        cost_per_worker REAL,
        paid_by TEXT CHECK(paid_by IN ('farmer', 'worker_deducted', 'shared')),
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE,
        FOREIGN KEY (harvest_id) REFERENCES harvests(harvest_id) ON DELETE SET NULL
      )
    ''');
    debugPrint('✅ transport_entries table created');

    // 23. OTHER EXPENSES
    await db.execute('''
      CREATE TABLE other_expenses (
        expense_id TEXT PRIMARY KEY NOT NULL,
        farm_id TEXT NOT NULL,
        crop_id TEXT,
        date TEXT NOT NULL,
        category TEXT CHECK(category IN ('transport', 'water', 'electricity', 'rent', 'miscellaneous')) NOT NULL,
        amount REAL NOT NULL,
        description TEXT,
        receipt_url TEXT,
        notes TEXT,
        created_at TEXT NOT NULL,
        updated_at TEXT NOT NULL,
        FOREIGN KEY (farm_id) REFERENCES farms(farm_id) ON DELETE CASCADE,
        FOREIGN KEY (crop_id) REFERENCES crops(crop_id) ON DELETE SET NULL
      )
    ''');
    debugPrint('✅ other_expenses table created');

    // ============================================
    // CREATE INDEXES
    // ============================================

    await db.execute('CREATE INDEX idx_farms_user ON farms(user_id)');
    await db.execute('CREATE INDEX idx_crops_farm ON crops(farm_id)');
    await db.execute('CREATE INDEX idx_crops_status ON crops(status)');
    await db.execute('CREATE INDEX idx_workers_farm ON workers(farm_id)');
    await db.execute('CREATE INDEX idx_workers_active ON workers(is_active)');
    await db.execute('CREATE INDEX idx_harvests_date ON harvests(date)');
    await db.execute('CREATE INDEX idx_harvests_crop ON harvests(crop_id)');
    await db.execute(
      'CREATE INDEX idx_harvest_workers_harvest ON harvest_workers(harvest_id)',
    );
    await db.execute(
      'CREATE INDEX idx_harvest_workers_worker ON harvest_workers(worker_id)',
    );
    await db.execute('CREATE INDEX idx_sales_date ON sales(sale_date)');
    await db.execute('CREATE INDEX idx_sales_dealer ON sales(dealer_id)');
    await db.execute('CREATE INDEX idx_sales_status ON sales(payment_status)');
    await db.execute('CREATE INDEX idx_sale_items_sale ON sale_items(sale_id)');
    await db.execute('CREATE INDEX idx_sale_items_crop ON sale_items(crop_id)');
    await db.execute('CREATE INDEX idx_inventory_farm ON inventory(farm_id)');
    await db.execute(
      'CREATE INDEX idx_inventory_category ON inventory(category)',
    );
    await db.execute('CREATE INDEX idx_tools_farm ON tools(farm_id)');
    await db.execute('CREATE INDEX idx_tools_status ON tools(status)');
    await db.execute(
      'CREATE INDEX idx_transport_date ON transport_entries(date)',
    );
    await db.execute('CREATE INDEX idx_expenses_date ON other_expenses(date)');
    await db.execute(
      'CREATE INDEX idx_expenses_crop ON other_expenses(crop_id)',
    );

    debugPrint('✅ All tables and indexes created successfully');
  }

  // ============================================
  // USER PROFILE CRUD
  // ============================================

  Future<void> insertUserProfile(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'user_profile',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getUserProfile(String userId) async {
    final db = await database;
    final result = await db.query(
      'user_profile',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getAllUserProfiles() async {
    final db = await database;
    return await db.query('user_profile');
  }

  Future<void> updateUserProfile(
    String userId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'user_profile',
      data,
      where: 'user_id = ?',
      whereArgs: [userId],
    );
  }

  Future<void> deleteUserProfile(String userId) async {
    final db = await database;
    await db.delete('user_profile', where: 'user_id = ?', whereArgs: [userId]);
  }

  // ============================================
  // FARM CRUD
  // ============================================

  Future<void> insertFarm(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'farms',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getFarm(String farmId) async {
    final db = await database;
    final result = await db.query(
      'farms',
      where: 'farm_id = ?',
      whereArgs: [farmId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<Map<String, dynamic>?> getFarmByUserId(String userId) async {
    final db = await database;
    final result = await db.query(
      'farms',
      where: 'user_id = ?',
      whereArgs: [userId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getAllFarms() async {
    final db = await database;
    return await db.query('farms');
  }

  Future<void> updateFarm(String farmId, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update('farms', data, where: 'farm_id = ?', whereArgs: [farmId]);
  }

  Future<void> deleteFarm(String farmId) async {
    final db = await database;
    await db.delete('farms', where: 'farm_id = ?', whereArgs: [farmId]);
  }

  // ============================================
  // FARM SETTINGS (Helper methods)
  // ============================================

  Future<Map<String, dynamic>?> getFarmSettings() async {
    final db = await database;
    final farms = await db.query('farms', limit: 1);
    if (farms.isEmpty) return null;
    final farm = farms.first;
    return {
      'farm_id': farm['farm_id'],
      'name': farm['name'] ?? 'My Farm',
      'location': farm['location'] ?? '',
      'default_transport_cost': farm['default_transport_cost'] ?? 0,
      'default_payment_method': farm['default_payment_method'] ?? 'per_kg',
      'default_per_kg_rate': farm['default_per_kg_rate'] ?? 5.0,
      'default_daily_wage': farm['default_daily_wage'] ?? 300.0,
    };
  }

  Future<void> updateFarmSettings(
    Map<String, dynamic> settings,
    String farmId,
  ) async {
    final db = await database;
    settings['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'farms',
      settings,
      where: 'farm_id = ?',
      whereArgs: [farmId],
    );
  }

  // ============================================
  // CROP CRUD
  // ============================================

  Future<void> insertCrop(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'crops',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getCrop(String cropId) async {
    final db = await database;
    final result = await db.query(
      'crops',
      where: 'crop_id = ?',
      whereArgs: [cropId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getCropsByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'crops',
      where: 'farm_id = ? AND status = ?',
      whereArgs: [farmId, 'active'],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getAllCrops(String farmId) async {
    final db = await database;
    return await db.query(
      'crops',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'name ASC',
    );
  }

  Future<void> updateCrop(String cropId, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update('crops', data, where: 'crop_id = ?', whereArgs: [cropId]);
  }

  Future<void> deleteCrop(String cropId) async {
    final db = await database;
    await db.delete('crops', where: 'crop_id = ?', whereArgs: [cropId]);
  }

  // ============================================
  // FIELD CRUD
  // ============================================

  Future<void> insertField(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'fields',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getField(String fieldId) async {
    final db = await database;
    final result = await db.query(
      'fields',
      where: 'field_id = ?',
      whereArgs: [fieldId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getFieldsByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'fields',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getFieldsByCrop(String cropId) async {
    final db = await database;
    return await db.query(
      'fields',
      where: 'crop_id = ?',
      whereArgs: [cropId],
      orderBy: 'name ASC',
    );
  }

  Future<void> updateField(String fieldId, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'fields',
      data,
      where: 'field_id = ?',
      whereArgs: [fieldId],
    );
  }

  Future<void> deleteField(String fieldId) async {
    final db = await database;
    await db.delete('fields', where: 'field_id = ?', whereArgs: [fieldId]);
  }

  // ============================================
  // WORKER CRUD (Fixed)
  // ============================================

  Future<void> insertWorker(Map<String, dynamic> data) async {
    try {
      final db = await database;
      // Ensure all required fields exist
      if (!data.containsKey('created_at')) {
        data['created_at'] = DateTime.now().toIso8601String();
      }
      if (!data.containsKey('updated_at')) {
        data['updated_at'] = DateTime.now().toIso8601String();
      }
      if (!data.containsKey('is_active')) {
        data['is_active'] = 1;
      }

      await db.insert(
        'workers',
        data,
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      debugPrint('✅ Worker inserted: ${data['name']}');
    } catch (e) {
      debugPrint('❌ insertWorker error: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>?> getWorker(String workerId) async {
    try {
      final db = await database;
      final result = await db.query(
        'workers',
        where: 'worker_id = ?',
        whereArgs: [workerId],
      );
      return result.isEmpty ? null : result.first;
    } catch (e) {
      debugPrint('❌ getWorker error: $e');
      return null;
    }
  }

  Future<List<Map<String, dynamic>>> getWorkersByFarm(
    String farmId, {
    bool onlyActive = true,
  }) async {
    try {
      final db = await database;
      final where = onlyActive
          ? 'farm_id = ? AND is_active = 1'
          : 'farm_id = ?';
      return await db.query(
        'workers',
        where: where,
        whereArgs: [farmId],
        orderBy: 'name ASC',
      );
    } catch (e) {
      debugPrint('❌ getWorkersByFarm error: $e');
      return [];
    }
  }

  Future<void> updateWorker(String workerId, Map<String, dynamic> data) async {
    try {
      final db = await database;
      data['updated_at'] = DateTime.now().toIso8601String();
      await db.update(
        'workers',
        data,
        where: 'worker_id = ?',
        whereArgs: [workerId],
      );
    } catch (e) {
      debugPrint('❌ updateWorker error: $e');
      rethrow;
    }
  }

  Future<void> deleteWorker(String workerId) async {
    try {
      final db = await database;
      await db.delete('workers', where: 'worker_id = ?', whereArgs: [workerId]);
    } catch (e) {
      debugPrint('❌ deleteWorker error: $e');
      rethrow;
    }
  }

  // Check if worker exists by name
  Future<Map<String, dynamic>?> findWorkerByName(
    String farmId,
    String name,
  ) async {
    try {
      final db = await database;
      final result = await db.query(
        'workers',
        where: 'farm_id = ? AND name = ? AND is_active = 1',
        whereArgs: [farmId, name.trim()],
      );
      return result.isEmpty ? null : result.first;
    } catch (e) {
      debugPrint('❌ findWorkerByName error: $e');
      return null;
    }
  }

  // Search workers by name (for suggestions)
  Future<List<Map<String, dynamic>>> searchWorkers(
    String farmId,
    String query,
  ) async {
    try {
      final db = await database;
      if (query.isEmpty) {
        return await getWorkersByFarm(farmId);
      }
      return await db.rawQuery(
        '''
      SELECT * FROM workers 
      WHERE farm_id = ? 
      AND is_active = 1 
      AND (name LIKE ? OR nick_name LIKE ?)
      ORDER BY name ASC
      LIMIT 10
    ''',
        [farmId, '%$query%', '%$query%'],
      );
    } catch (e) {
      debugPrint('❌ searchWorkers error: $e');
      return [];
    }
  }

  // ============================================
  // WORKER PAYMENT SETTINGS CRUD
  // ============================================

  Future<void> insertWorkerPaymentSetting(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'worker_payment_settings',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getWorkerPaymentSetting(
    String settingId,
  ) async {
    final db = await database;
    final result = await db.query(
      'worker_payment_settings',
      where: 'setting_id = ?',
      whereArgs: [settingId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getWorkerPaymentSettingsByWorker(
    String workerId,
  ) async {
    final db = await database;
    return await db.query(
      'worker_payment_settings',
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );
  }

  Future<void> updateWorkerPaymentSetting(
    String settingId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'worker_payment_settings',
      data,
      where: 'setting_id = ?',
      whereArgs: [settingId],
    );
  }

  Future<void> deleteWorkerPaymentSetting(String settingId) async {
    final db = await database;
    await db.delete(
      'worker_payment_settings',
      where: 'setting_id = ?',
      whereArgs: [settingId],
    );
  }

  // ============================================
  // LABOR ACTIVITIES CRUD
  // ============================================

  Future<void> insertLaborActivity(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'labor_activities',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getLaborActivity(String activityId) async {
    final db = await database;
    final result = await db.query(
      'labor_activities',
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getLaborActivitiesByFarm(
    String farmId,
  ) async {
    final db = await database;
    return await db.query(
      'labor_activities',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'start_time DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getLaborActivitiesByWorker(
    String workerId,
  ) async {
    final db = await database;
    return await db.query(
      'labor_activities',
      where: 'worker_id = ?',
      whereArgs: [workerId],
      orderBy: 'start_time DESC',
    );
  }

  Future<void> updateLaborActivity(
    String activityId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'labor_activities',
      data,
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
  }

  Future<void> deleteLaborActivity(String activityId) async {
    final db = await database;
    await db.delete(
      'labor_activities',
      where: 'activity_id = ?',
      whereArgs: [activityId],
    );
  }

  // ============================================
  // HARVEST CRUD
  // ============================================

  Future<void> insertHarvest(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'harvests',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getHarvest(String harvestId) async {
    final db = await database;
    final result = await db.query(
      'harvests',
      where: 'harvest_id = ?',
      whereArgs: [harvestId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getHarvestsByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'harvests',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getHarvestsByCrop(String cropId) async {
    final db = await database;
    return await db.query(
      'harvests',
      where: 'crop_id = ?',
      whereArgs: [cropId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getHarvestsByDateRange(
    String farmId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      'harvests',
      where: 'farm_id = ? AND date BETWEEN ? AND ?',
      whereArgs: [farmId, startDate, endDate],
      orderBy: 'date DESC',
    );
  }

  Future<void> updateHarvest(
    String harvestId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'harvests',
      data,
      where: 'harvest_id = ?',
      whereArgs: [harvestId],
    );
  }

  Future<void> deleteHarvest(String harvestId) async {
    final db = await database;
    await db.delete(
      'harvests',
      where: 'harvest_id = ?',
      whereArgs: [harvestId],
    );
  }

  // ============================================
  // HARVEST WORKERS CRUD
  // ============================================

  Future<void> insertHarvestWorker(Map<String, dynamic> data) async {
  final db = await database;
  // Ensure is_paid exists
  if (!data.containsKey('is_paid')) {
    data['is_paid'] = 0;
  }
  if (!data.containsKey('created_at')) {
    data['created_at'] = DateTime.now().toIso8601String();
  }
  if (!data.containsKey('updated_at')) {
    data['updated_at'] = DateTime.now().toIso8601String();
  }
  await db.insert('harvest_workers', data, conflictAlgorithm: ConflictAlgorithm.replace);
}

  Future<List<Map<String, dynamic>>> getHarvestWorkersByHarvest(
    String harvestId,
  ) async {
    final db = await database;
    return await db.query(
      'harvest_workers',
      where: 'harvest_id = ?',
      whereArgs: [harvestId],
    );
  }

  Future<List<Map<String, dynamic>>> getHarvestWorkersByWorker(
    String workerId,
  ) async {
    final db = await database;
    return await db.query(
      'harvest_workers',
      where: 'worker_id = ?',
      whereArgs: [workerId],
    );
  }

  Future<void> updateHarvestWorker(String id, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update('harvest_workers', data, where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteHarvestWorker(String id) async {
    final db = await database;
    await db.delete('harvest_workers', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deleteHarvestWorkersByHarvest(String harvestId) async {
    final db = await database;
    await db.delete(
      'harvest_workers',
      where: 'harvest_id = ?',
      whereArgs: [harvestId],
    );
  }

  // ============================================
  // DEALER CRUD
  // ============================================

  Future<void> insertDealer(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'dealers',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getDealer(String dealerId) async {
    final db = await database;
    final result = await db.query(
      'dealers',
      where: 'dealer_id = ?',
      whereArgs: [dealerId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getDealersByFarm(
    String farmId, {
    bool onlyActive = true,
  }) async {
    final db = await database;
    final where = onlyActive ? 'farm_id = ? AND is_active = 1' : 'farm_id = ?';
    return await db.query(
      'dealers',
      where: where,
      whereArgs: [farmId],
      orderBy: 'name ASC',
    );
  }

  Future<void> updateDealer(String dealerId, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'dealers',
      data,
      where: 'dealer_id = ?',
      whereArgs: [dealerId],
    );
  }

  Future<void> deleteDealer(String dealerId) async {
    final db = await database;
    await db.delete('dealers', where: 'dealer_id = ?', whereArgs: [dealerId]);
  }

  // ============================================
  // SALE CRUD
  // ============================================

  Future<void> insertSale(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'sales',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getSale(String saleId) async {
    final db = await database;
    final result = await db.query(
      'sales',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getSalesByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'sale_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getSalesByDateRange(
    String farmId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'farm_id = ? AND sale_date BETWEEN ? AND ?',
      whereArgs: [farmId, startDate, endDate],
      orderBy: 'sale_date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getPendingSales(String farmId) async {
    final db = await database;
    return await db.query(
      'sales',
      where: 'farm_id = ? AND payment_status != ?',
      whereArgs: [farmId, 'paid'],
      orderBy: 'sale_date ASC',
    );
  }

  Future<void> updateSale(String saleId, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update('sales', data, where: 'sale_id = ?', whereArgs: [saleId]);
  }

  Future<void> deleteSale(String saleId) async {
    final db = await database;
    await db.delete('sales', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  // ============================================
  // SALE ITEMS CRUD
  // ============================================

  Future<void> insertSaleItem(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'sale_items',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getSaleItemsBySale(String saleId) async {
    final db = await database;
    return await db.query(
      'sale_items',
      where: 'sale_id = ?',
      whereArgs: [saleId],
    );
  }

  Future<void> updateSaleItem(String itemId, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'sale_items',
      data,
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteSaleItem(String itemId) async {
    final db = await database;
    await db.delete('sale_items', where: 'item_id = ?', whereArgs: [itemId]);
  }

  Future<void> deleteSaleItemsBySale(String saleId) async {
    final db = await database;
    await db.delete('sale_items', where: 'sale_id = ?', whereArgs: [saleId]);
  }

  // ============================================
  // PAYMENT CRUD
  // ============================================

  Future<void> insertPayment(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'payments',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getPaymentsBySale(String saleId) async {
    final db = await database;
    return await db.query(
      'payments',
      where: 'sale_id = ?',
      whereArgs: [saleId],
      orderBy: 'payment_date DESC',
    );
  }

  Future<double> getTotalPaidBySale(String saleId) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM payments WHERE sale_id = ?',
      [saleId],
    );
    return result.first['total'] as double? ?? 0;
  }

  Future<void> updatePayment(
    String paymentId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'payments',
      data,
      where: 'payment_id = ?',
      whereArgs: [paymentId],
    );
  }

  Future<void> deletePayment(String paymentId) async {
    final db = await database;
    await db.delete(
      'payments',
      where: 'payment_id = ?',
      whereArgs: [paymentId],
    );
  }

  // ============================================
  // INVENTORY CRUD
  // ============================================

  Future<void> insertInventoryItem(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'inventory',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getInventoryItem(String itemId) async {
    final db = await database;
    final result = await db.query(
      'inventory',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getInventoryByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'inventory',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getInventoryByCategory(
    String farmId,
    String category,
  ) async {
    final db = await database;
    return await db.query(
      'inventory',
      where: 'farm_id = ? AND category = ?',
      whereArgs: [farmId, category],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getLowStockItems(String farmId) async {
    final db = await database;
    return await db.query(
      'inventory',
      where:
          'farm_id = ? AND quantity <= min_stock_alert AND min_stock_alert > 0',
      whereArgs: [farmId],
      orderBy: 'quantity ASC',
    );
  }

  Future<void> updateInventoryItem(
    String itemId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'inventory',
      data,
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteInventoryItem(String itemId) async {
    final db = await database;
    await db.delete('inventory', where: 'item_id = ?', whereArgs: [itemId]);
  }

  Future<void> updateInventoryStock(
    String itemId,
    double quantityChange,
  ) async {
    final db = await database;
    final item = await getInventoryItem(itemId);
    if (item != null) {
      final newQuantity = (item['quantity'] as num).toDouble() + quantityChange;
      await db.update(
        'inventory',
        {
          'quantity': newQuantity,
          'updated_at': DateTime.now().toIso8601String(),
        },
        where: 'item_id = ?',
        whereArgs: [itemId],
      );
    }
  }

  // ============================================
  // INVENTORY CROP ASSIGNMENT CRUD
  // ============================================

  Future<void> insertInventoryCropAssignment(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'inventory_crop_assignments',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getCropAssignmentsByItem(
    String itemId,
  ) async {
    final db = await database;
    return await db.query(
      'inventory_crop_assignments',
      where: 'item_id = ?',
      whereArgs: [itemId],
    );
  }

  Future<void> deleteCropAssignment(String id) async {
    final db = await database;
    await db.delete(
      'inventory_crop_assignments',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // ============================================
  // INVENTORY USAGE CRUD
  // ============================================

  Future<void> insertInventoryUsage(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'inventory_usage',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update stock
    final itemId = data['item_id'] as String;
    final quantityUsed = (data['quantity_used'] as num).toDouble();
    await updateInventoryStock(itemId, -quantityUsed);
  }

  Future<List<Map<String, dynamic>>> getInventoryUsageByItem(
    String itemId,
  ) async {
    final db = await database;
    return await db.query(
      'inventory_usage',
      where: 'item_id = ?',
      whereArgs: [itemId],
      orderBy: 'date_used DESC',
    );
  }

  Future<void> deleteInventoryUsage(String usageId) async {
    final db = await database;
    await db.delete(
      'inventory_usage',
      where: 'usage_id = ?',
      whereArgs: [usageId],
    );
  }

  // ============================================
  // PURCHASE CRUD
  // ============================================

  Future<void> insertPurchase(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'purchases',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getPurchase(String purchaseId) async {
    final db = await database;
    final result = await db.query(
      'purchases',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getPurchasesByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'purchases',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'date DESC',
    );
  }

  Future<void> updatePurchase(
    String purchaseId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'purchases',
      data,
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  Future<void> deletePurchase(String purchaseId) async {
    final db = await database;
    await db.delete(
      'purchases',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  // ============================================
  // PURCHASE ITEMS CRUD
  // ============================================

  Future<void> insertPurchaseItem(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'purchase_items',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    // Update inventory stock
    final itemId = data['item_id'] as String;
    final quantity = (data['quantity'] as num).toDouble();
    await updateInventoryStock(itemId, quantity);
  }

  Future<List<Map<String, dynamic>>> getPurchaseItemsByPurchase(
    String purchaseId,
  ) async {
    final db = await database;
    return await db.query(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  Future<void> deletePurchaseItem(String id) async {
    final db = await database;
    await db.delete('purchase_items', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> deletePurchaseItemsByPurchase(String purchaseId) async {
    final db = await database;
    await db.delete(
      'purchase_items',
      where: 'purchase_id = ?',
      whereArgs: [purchaseId],
    );
  }

  // ============================================
  // TOOL CRUD
  // ============================================

  Future<void> insertTool(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'tools',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<Map<String, dynamic>?> getTool(String toolId) async {
    final db = await database;
    final result = await db.query(
      'tools',
      where: 'tool_id = ?',
      whereArgs: [toolId],
    );
    return result.isEmpty ? null : result.first;
  }

  Future<List<Map<String, dynamic>>> getToolsByFarm(String farmId) async {
    final db = await database;
    return await db.query(
      'tools',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'name ASC',
    );
  }

  Future<List<Map<String, dynamic>>> getToolsByStatus(
    String farmId,
    String status,
  ) async {
    final db = await database;
    return await db.query(
      'tools',
      where: 'farm_id = ? AND status = ?',
      whereArgs: [farmId, status],
      orderBy: 'name ASC',
    );
  }

  Future<void> updateTool(String toolId, Map<String, dynamic> data) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update('tools', data, where: 'tool_id = ?', whereArgs: [toolId]);
  }

  Future<void> deleteTool(String toolId) async {
    final db = await database;
    await db.delete('tools', where: 'tool_id = ?', whereArgs: [toolId]);
  }

  // ============================================
  // TOOL CROP ASSIGNMENT CRUD
  // ============================================

  Future<void> insertToolCropAssignment(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'tool_crop_assignments',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getToolCropAssignmentsByTool(
    String toolId,
  ) async {
    final db = await database;
    return await db.query(
      'tool_crop_assignments',
      where: 'tool_id = ?',
      whereArgs: [toolId],
    );
  }

  Future<void> deleteToolCropAssignment(String id) async {
    final db = await database;
    await db.delete('tool_crop_assignments', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================
  // TOOL MAINTENANCE CRUD
  // ============================================

  Future<void> insertToolMaintenance(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'tool_maintenance',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getToolMaintenanceByTool(
    String toolId,
  ) async {
    final db = await database;
    return await db.query(
      'tool_maintenance',
      where: 'tool_id = ?',
      whereArgs: [toolId],
      orderBy: 'date DESC',
    );
  }

  Future<void> updateToolMaintenance(
    String maintenanceId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'tool_maintenance',
      data,
      where: 'maintenance_id = ?',
      whereArgs: [maintenanceId],
    );
  }

  Future<void> deleteToolMaintenance(String maintenanceId) async {
    final db = await database;
    await db.delete(
      'tool_maintenance',
      where: 'maintenance_id = ?',
      whereArgs: [maintenanceId],
    );
  }

  // ============================================
  // TRANSPORT ENTRIES CRUD
  // ============================================

  Future<void> insertTransportEntry(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'transport_entries',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getTransportEntriesByFarm(
    String farmId,
  ) async {
    final db = await database;
    return await db.query(
      'transport_entries',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'date DESC',
    );
  }

  Future<double> getTotalTransportCost(
    String farmId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(total_cost) as total FROM transport_entries WHERE farm_id = ? AND date BETWEEN ? AND ?',
      [farmId, startDate, endDate],
    );
    return result.first['total'] as double? ?? 0;
  }

  Future<void> updateTransportEntry(
    String id,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'transport_entries',
      data,
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> deleteTransportEntry(String id) async {
    final db = await database;
    await db.delete('transport_entries', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================
  // OTHER EXPENSES CRUD
  // ============================================

  Future<void> insertOtherExpense(Map<String, dynamic> data) async {
    final db = await database;
    data['created_at'] = DateTime.now().toIso8601String();
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.insert(
      'other_expenses',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Map<String, dynamic>>> getOtherExpensesByFarm(
    String farmId,
  ) async {
    final db = await database;
    return await db.query(
      'other_expenses',
      where: 'farm_id = ?',
      whereArgs: [farmId],
      orderBy: 'date DESC',
    );
  }

  Future<List<Map<String, dynamic>>> getOtherExpensesByCrop(
    String cropId,
  ) async {
    final db = await database;
    return await db.query(
      'other_expenses',
      where: 'crop_id = ?',
      whereArgs: [cropId],
      orderBy: 'date DESC',
    );
  }

  Future<double> getTotalOtherExpenses(
    String farmId,
    String startDate,
    String endDate,
  ) async {
    final db = await database;
    final result = await db.rawQuery(
      'SELECT SUM(amount) as total FROM other_expenses WHERE farm_id = ? AND date BETWEEN ? AND ?',
      [farmId, startDate, endDate],
    );
    return result.first['total'] as double? ?? 0;
  }

  Future<void> updateOtherExpense(
    String expenseId,
    Map<String, dynamic> data,
  ) async {
    final db = await database;
    data['updated_at'] = DateTime.now().toIso8601String();
    await db.update(
      'other_expenses',
      data,
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }

  Future<void> deleteOtherExpense(String expenseId) async {
    final db = await database;
    await db.delete(
      'other_expenses',
      where: 'expense_id = ?',
      whereArgs: [expenseId],
    );
  }

  // ============================================
  // GENERIC HELPER METHODS
  // ============================================

  Future<List<Map<String, dynamic>>> query(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
    String? orderBy,
    int? limit,
  }) async {
    final db = await database;
    return await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      orderBy: orderBy,
      limit: limit,
    );
  }

  Future<Map<String, dynamic>?> queryFirst(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final results = await query(
      table,
      where: where,
      whereArgs: whereArgs,
      limit: 1,
    );
    return results.isEmpty ? null : results.first;
  }

  Future<int> count(
    String table, {
    String? where,
    List<dynamic>? whereArgs,
  }) async {
    final db = await database;
    final result = await db.query(
      table,
      where: where,
      whereArgs: whereArgs,
      columns: ['COUNT(*) as count'],
    );
    return result.first['count'] as int? ?? 0;
  }

  Future<void> delete(
    String table, {
    required String where,
    required List<dynamic> whereArgs,
  }) async {
    final db = await database;
    await db.delete(table, where: where, whereArgs: whereArgs);
  }

  Future<void> clearAllData() async {
    final db = await database;
    final tables = [
      'user_profile',
      'farms',
      'crops',
      'fields',
      'workers',
      'worker_payment_settings',
      'labor_activities',
      'harvests',
      'harvest_workers',
      'dealers',
      'sales',
      'sale_items',
      'payments',
      'inventory',
      'inventory_crop_assignments',
      'inventory_usage',
      'purchases',
      'purchase_items',
      'tools',
      'tool_crop_assignments',
      'tool_maintenance',
      'transport_entries',
      'other_expenses',
    ];
    for (final table in tables) {
      await db.delete(table);
    }
    debugPrint('🗑️ All data cleared');
  }
}
