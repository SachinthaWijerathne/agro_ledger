// lib/screens/add_harvest_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agro_ledger/utils/helpers.dart';
import 'package:agro_ledger/services/local_storage_service.dart';

class AddHarvestScreen extends ConsumerStatefulWidget {
  const AddHarvestScreen({super.key});

  @override
  ConsumerState<AddHarvestScreen> createState() => _AddHarvestScreenState();
}

class _AddHarvestScreenState extends ConsumerState<AddHarvestScreen> {
  // ============================================
  // STATE VARIABLES
  // ============================================
OverlayEntry? _suggestionsOverlay;

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isAddingWorker = false;

  // Farm Settings
  Map<String, dynamic>? _farmSettings;
  String _farmId = '';

  // Crop Data
  List<Map<String, dynamic>> _crops = [];
  String _selectedCropId = '';

  // Workers Data
  List<Map<String, dynamic>> _allWorkers = [];
  List<Map<String, dynamic>> _suggestedWorkers = [];

  // Harvest Record
  String _harvestDate = '';
  String _harvestId = '';
  bool _isEditingExisting = false;
  Map<String, dynamic>? _existingHarvest;

  // Harvest Workers (Temporary list)
  List<Map<String, dynamic>> _tempHarvestWorkers = [];

  // Current entry being added
  String _workerNameInput = '';
  String _selectedWorkerId = '';
  double _workerQuantity = 0.0;
  String _selectedPaymentMethod = 'per_kg';
  double _ratePerKg = 5.0;
  double _dailyWage = 300.0;
  double _transportCost = 0.0;

  // Total harvest
  double _totalHarvestWeight = 0.0;
  double _totalLaborCost = 0.0;

  // Focus nodes
  final FocusNode _workerNameFocus = FocusNode();
  final FocusNode _quantityFocus = FocusNode();

  // Controllers
  final TextEditingController _workerNameController = TextEditingController();
  final TextEditingController _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _harvestDate = DateTime.now().toIso8601String().substring(0, 10);
    _loadData();
  }

  @override
  void dispose() {
    _hideSuggestionsOverlay();
    _workerNameController.dispose();
    _quantityController.dispose();
    _workerNameFocus.dispose();
    _quantityFocus.dispose();
    super.dispose();
  }

  // ============================================
  // DATA LOADING
  // ============================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final localStorage = await LocalStorageService.getInstance();

      // Get farm
      final farms = await localStorage.getAllFarms();
      if (farms.isNotEmpty) {
        _farmId = farms.first['farm_id'];
        _farmSettings = farms.first;

        // Load settings
        _ratePerKg =
            (_farmSettings?['default_per_kg_rate'] as num?)?.toDouble() ?? 5.0;
        _dailyWage =
            (_farmSettings?['default_daily_wage'] as num?)?.toDouble() ?? 300.0;
        _transportCost =
            (_farmSettings?['default_transport_cost'] as num?)?.toDouble() ??
            0.0;
        _selectedPaymentMethod =
            _farmSettings?['default_payment_method'] ?? 'per_kg';
      }

      // Load crops
      _crops = await localStorage.getCropsByFarm(_farmId);
      if (_crops.isNotEmpty) {
        // Find main crop first
        final mainCrop = Helpers.findMainCrop(_crops);
        if (mainCrop != null) {
          _selectedCropId = mainCrop['crop_id'];
          debugPrint('✅ Main crop selected: ${mainCrop['name']}');
        } else {
          _selectedCropId = _crops.first['crop_id'];
        }
      }

      // Load workers
      _allWorkers = await localStorage.getWorkersByFarm(_farmId);
      _suggestedWorkers = [];

      // Check if today has a harvest entry
      await _checkTodayHarvest(localStorage);
    } catch (e) {
      debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _checkTodayHarvest(LocalStorageService localStorage) async {
    final existingHarvests = await localStorage.query(
      'harvests',
      where: 'farm_id = ? AND date = ?',
      whereArgs: [_farmId, _harvestDate],
    );

    if (existingHarvests.isNotEmpty) {
      _existingHarvest = existingHarvests.first;
      _harvestId = _existingHarvest!['harvest_id'];
      _isEditingExisting = true;

      // Load existing harvest workers
      final workers = await localStorage.getHarvestWorkersByHarvest(_harvestId);
      _tempHarvestWorkers = workers.map((w) {
        final workerName = _getWorkerName(w['worker_id']);
        return {
          'id': w['id'],
          'worker_id': w['worker_id'],
          'name': workerName,
          'quantity': w['quantity_harvested'] ?? 0.0,
          'earnings': w['earnings'] ?? 0.0,
          'payment_method': w['payment_method'] ?? _selectedPaymentMethod,
          'rate':
              w['rate'] ??
              (_selectedPaymentMethod == 'per_kg' ? _ratePerKg : _dailyWage),
          'transport_cost': w['transport_cost'] ?? 0.0,
        };
      }).toList();

      _updateTotals();
    } else {
      _isEditingExisting = false;
      _harvestId = '';
      _tempHarvestWorkers = [];
      _updateTotals();
    }
  }

  String _getWorkerName(String workerId) {
    final worker = _allWorkers.firstWhere(
      (w) => w['worker_id'] == workerId,
      orElse: () => {'name': 'Unknown'},
    );
    return worker['name'];
  }


  // ============================================
  // OVERLAY FOR SUGGESTIONS
  // ============================================
void _showSuggestionsOverlay() {
  // Remove existing overlay first
  _hideSuggestionsOverlay();
  
  if (_suggestedWorkers.isEmpty) return;
  
  // Get the position of the text field
  final RenderBox renderBox = _workerNameFocus.context!.findRenderObject() as RenderBox;
  final Offset offset = renderBox.localToGlobal(Offset.zero);
  final Size size = renderBox.size;
  
  _suggestionsOverlay = OverlayEntry(
    builder: (context) => Positioned(
      left: offset.dx,
      top: offset.dy + size.height + 4,
      width: size.width,
      child: Material(
        elevation: 8,
        borderRadius: BorderRadius.circular(8),
        color: Colors.white,
        child: Container(
          constraints: const BoxConstraints(maxHeight: 150),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: _suggestedWorkers.length,
            itemBuilder: (context, index) {
              final worker = _suggestedWorkers[index];
              return ListTile(
                dense: true,
                leading: CircleAvatar(
                  radius: 14,
                  backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
                  child: Text(
                    (worker['name'] as String).substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ),
                title: Text(
                  worker['name'],
                  style: const TextStyle(fontSize: 13),
                ),
                subtitle: worker['nick_name'] != null && (worker['nick_name'] as String).isNotEmpty
                    ? Text(worker['nick_name'], style: const TextStyle(fontSize: 11))
                    : null,
                onTap: () {
                  _selectSuggestion(worker);
                  _hideSuggestionsOverlay();
                },
              );
            },
          ),
        ),
      ),
    ),
  );
  
  Overlay.of(context).insert(_suggestionsOverlay!);
}

void _hideSuggestionsOverlay() {
  _suggestionsOverlay?.remove();
  _suggestionsOverlay = null;
}

// Update _updateSuggestions method
void _updateSuggestions(String query) {
  final trimmed = query.trim().toLowerCase();
  if (trimmed.isEmpty) {
    setState(() {
      _suggestedWorkers = [];
    });
    _hideSuggestionsOverlay();
    return;
  }
  
  setState(() {
    _suggestedWorkers = _allWorkers.where((worker) {
      final name = (worker['name'] as String).toLowerCase();
      final nickName = (worker['nick_name'] ?? '').toLowerCase();
      return name.contains(trimmed) || nickName.contains(trimmed);
    }).toList();
  });
  
  // Show overlay after state update
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (_suggestedWorkers.isNotEmpty && mounted) {
      _showSuggestionsOverlay();
    } else {
      _hideSuggestionsOverlay();
    }
  });
}

// Update _selectSuggestion method
void _selectSuggestion(Map<String, dynamic> worker) {
  setState(() {
    _workerNameController.text = worker['name'];
    _selectedWorkerId = worker['worker_id'];
    _suggestedWorkers = [];
  });
  _hideSuggestionsOverlay();
  _workerNameFocus.unfocus();
  _quantityFocus.requestFocus();
}
  // ============================================
  // WORKER LOGIC - FIND OR CREATE
  // ============================================

  Map<String, dynamic>? _findWorkerByName(String name) {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) return null;

    // Try exact match first
    for (var worker in _allWorkers) {
      if ((worker['name'] as String).toLowerCase() ==
          trimmedName.toLowerCase()) {
        return worker;
      }
    }

    // Try partial match
    for (var worker in _allWorkers) {
      if ((worker['name'] as String).toLowerCase().contains(
            trimmedName.toLowerCase(),
          ) ||
          ((worker['nick_name'] ?? '').toString().toLowerCase().contains(
            trimmedName.toLowerCase(),
          ))) {
        return worker;
      }
    }

    return null;
  }

  Future<String> _createWorker(String name) async {
    try {
      final localStorage = await LocalStorageService.getInstance();
      final workerId = Helpers.generateId();

      // Check if worker already exists (double-check)
      final existing = await localStorage.findWorkerByName(_farmId, name);
      if (existing != null) {
        debugPrint('✅ Worker already exists: ${existing['name']}');
        return existing['worker_id'];
      }

      final workerData = {
        'worker_id': workerId,
        'farm_id': _farmId,
        'name': name.trim(),
        'nick_name': '',
        'gender': 'other',
        'phone': '',
        'address': '',
        'join_date': DateTime.now().toIso8601String().substring(0, 10),
        'is_active': 1,
        'notes': 'Auto-created during harvest entry',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      };

      debugPrint('📝 Creating worker with data: $workerData');
      await localStorage.insertWorker(workerData);

      // Reload workers list
      _allWorkers = await localStorage.getWorkersByFarm(_farmId);
      _suggestedWorkers = [];

      debugPrint('✅ New worker created: $name (ID: $workerId)');
      return workerId;
    } catch (e) {
      debugPrint('❌ Error creating worker: $e');
      // Try alternative method - direct insert
      try {
        final localStorage = await LocalStorageService.getInstance();
        final workerId = Helpers.generateId();

        // Direct insert using raw query
        final db = await localStorage.database;
        await db.rawInsert(
          '''
        INSERT OR REPLACE INTO workers (
          worker_id, farm_id, name, nick_name, gender, phone, address, 
          join_date, is_active, notes, created_at, updated_at
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
          [
            workerId,
            _farmId,
            name.trim(),
            '',
            'other',
            '',
            '',
            DateTime.now().toIso8601String().substring(0, 10),
            1,
            'Auto-created during harvest entry',
            DateTime.now().toIso8601String(),
            DateTime.now().toIso8601String(),
          ],
        );

        // Reload workers list
        _allWorkers = await localStorage.getWorkersByFarm(_farmId);
        _suggestedWorkers = [];

        debugPrint('✅ New worker created via raw insert: $name');
        return workerId;
      } catch (e2) {
        debugPrint('❌ Raw insert also failed: $e2');
        rethrow;
      }
    }
  }

  // ============================================
  // SUGGEST WORKERS (Auto-complete)
  // ============================================

  // void _updateSuggestions(String query) {
  //   final trimmed = query.trim().toLowerCase();
  //   if (trimmed.isEmpty) {
  //     setState(() {
  //       _suggestedWorkers = [];
  //     });
  //     return;
  //   }

  //   setState(() {
  //     _suggestedWorkers = _allWorkers.where((worker) {
  //       final name = (worker['name'] as String).toLowerCase();
  //       final nickName = (worker['nick_name'] ?? '').toLowerCase();
  //       return name.contains(trimmed) || nickName.contains(trimmed);
  //     }).toList();
  //   });
  // }

  // void _selectSuggestion(Map<String, dynamic> worker) {
  //   setState(() {
  //     _workerNameController.text = worker['name'];
  //     _selectedWorkerId = worker['worker_id'];
  //     _suggestedWorkers = [];
  //     _workerNameFocus.unfocus();
  //     _quantityFocus.requestFocus();
  //   });
  // }

  // ============================================
  // ADD WORKER TO HARVEST
  // ============================================

  Future<void> _addWorkerToHarvest() async {
    final workerName = _workerNameController.text.trim();
    if (workerName.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter worker name')));
      _workerNameFocus.requestFocus();
      return;
    }

    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter harvest quantity')),
      );
      _quantityFocus.requestFocus();
      return;
    }

    final quantity = double.tryParse(_quantityController.text) ?? 0;
    if (quantity <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Quantity must be greater than 0')),
      );
      _quantityFocus.requestFocus();
      return;
    }

    setState(() => _isAddingWorker = true);

    try {
      final localStorage = await LocalStorageService.getInstance();

      // 1. Find or create worker
      String workerId;
      String displayName;

      // Check if worker exists by name
      final existingWorker = await localStorage.findWorkerByName(
        _farmId,
        workerName,
      );

      if (existingWorker != null) {
        workerId = existingWorker['worker_id'];
        displayName = existingWorker['name'];
        debugPrint('✅ Found existing worker: $displayName');
      } else {
        // Create new worker
        workerId = await _createWorker(workerName);
        displayName = workerName.trim();
        debugPrint('✅ Created new worker: $displayName');

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('New worker "$displayName" added!'),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 1),
          ),
        );
      }

      // 2. Calculate earnings
      double earnings = 0;
      if (_selectedPaymentMethod == 'per_kg') {
        earnings = quantity * _ratePerKg;
      } else {
        earnings = _dailyWage;
      }

      // 3. Check if worker already added today
      final existingIndex = _tempHarvestWorkers.indexWhere(
        (w) => w['worker_id'] == workerId,
      );

      if (existingIndex != -1) {
        // Update existing worker entry
        setState(() {
          final current = _tempHarvestWorkers[existingIndex];
          final newQuantity = (current['quantity'] as double) + quantity;
          current['quantity'] = newQuantity;
          if (_selectedPaymentMethod == 'per_kg') {
            current['earnings'] = newQuantity * _ratePerKg;
          } else {
            current['earnings'] = _dailyWage;
          }
          current['rate'] = _selectedPaymentMethod == 'per_kg'
              ? _ratePerKg
              : _dailyWage;
          current['payment_method'] = _selectedPaymentMethod;
        });
        debugPrint('✅ Updated existing worker: $displayName (+${quantity}kg)');
      } else {
        // Add new worker
        setState(() {
          _tempHarvestWorkers.add({
            'id': 'temp_${DateTime.now().millisecondsSinceEpoch}',
            'worker_id': workerId,
            'name': displayName,
            'quantity': quantity,
            'earnings': earnings,
            'payment_method': _selectedPaymentMethod,
            'rate': _selectedPaymentMethod == 'per_kg'
                ? _ratePerKg
                : _dailyWage,
            'transport_cost': _transportCost,
          });
        });
        debugPrint(
          '✅ Added new worker to harvest: $displayName (${quantity}kg)',
        );
      }

      // 4. Clear inputs and update totals
      _workerNameController.clear();
      _quantityController.clear();
      setState(() {
        _suggestedWorkers = [];
        _selectedWorkerId = '';
      });
      _updateTotals();

      // 5. Focus back to worker name
      _workerNameFocus.requestFocus();
    } catch (e) {
      debugPrint('❌ Error adding worker: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error adding worker: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    } finally {
      setState(() => _isAddingWorker = false);
    }
  }

  void _removeWorkerFromHarvest(int index) {
    setState(() {
      _tempHarvestWorkers.removeAt(index);
      _updateTotals();
    });
  }

  void _updateTotals() {
    _totalHarvestWeight = _tempHarvestWorkers.fold(
      0.0,
      (sum, w) => sum + (w['quantity'] as double),
    );
    _totalLaborCost = _tempHarvestWorkers.fold(
      0.0,
      (sum, w) => sum + (w['earnings'] as double),
    );
  }

  // ============================================
  // SAVE HARVEST
  // ============================================

  Future<void> _saveHarvest() async {
    if (_selectedCropId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a crop')));
      return;
    }

    if (_tempHarvestWorkers.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one worker')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final localStorage = await LocalStorageService.getInstance();

      // Save or Update Harvest
      if (_isEditingExisting && _harvestId.isNotEmpty) {
        await localStorage.updateHarvest(_harvestId, {
          'quantity': _totalHarvestWeight,
          'updated_at': DateTime.now().toIso8601String(),
        });

        await localStorage.deleteHarvestWorkersByHarvest(_harvestId);
      } else {
        _harvestId = Helpers.generateId();
        await localStorage.insertHarvest({
          'harvest_id': _harvestId,
          'farm_id': _farmId,
          'crop_id': _selectedCropId,
          'date': _harvestDate,
          'quantity': _totalHarvestWeight,
          'unit': 'kg',
          'harvester_type': 'hired',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Save all harvest workers
      for (var worker in _tempHarvestWorkers) {
        await localStorage.insertHarvestWorker({
          'id': Helpers.generateId(),
          'harvest_id': _harvestId,
          'worker_id': worker['worker_id'],
          'quantity_harvested': worker['quantity'],
          'earnings': worker['earnings'],
          'payment_method': worker['payment_method'],
          'rate': worker['rate'],
          'transport_cost': worker['transport_cost'] ?? 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      // Save transport entry if cost > 0
      if (_transportCost > 0 && _tempHarvestWorkers.isNotEmpty) {
        await localStorage.insertTransportEntry({
          'id': Helpers.generateId(),
          'farm_id': _farmId,
          'harvest_id': _harvestId,
          'date': _harvestDate,
          'vehicle_type': 'auto',
          'total_cost': _transportCost * _tempHarvestWorkers.length,
          'workers_count': _tempHarvestWorkers.length,
          'cost_per_worker': _transportCost,
          'paid_by': 'farmer',
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isEditingExisting
                  ? '✅ Harvest updated! (${_totalHarvestWeight.toStringAsFixed(1)} kg)'
                  : '✅ Harvest saved! (${_totalHarvestWeight.toStringAsFixed(1)} kg)',
            ),
            backgroundColor: Colors.green,
          ),
        );

        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isSaving = false);
    }
  }

  // ============================================
  // BUILD UI
  // ============================================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: Text(
          _isEditingExisting ? 'Update Today\'s Harvest' : 'Add Harvest',
          style: const TextStyle(fontSize: 18),
        ),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isEditingExisting)
            TextButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Reset Harvest'),
                    content: const Text(
                      'This will clear all workers added today. Continue?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(context);
                          setState(() {
                            _isEditingExisting = false;
                            _harvestId = '';
                            _tempHarvestWorkers = [];
                            _updateTotals();
                          });
                        },
                        child: const Text(
                          'Reset',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                );
              },
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SafeArea(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Header Info
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        '📅 ${_formatDisplayDate(_harvestDate)}',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (_isEditingExisting)
                                        Text(
                                          '✏️ Updating today\'s record',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: Colors.blue.shade700,
                                          ),
                                        ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      '${_tempHarvestWorkers.length} workers',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.green.shade700,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Crop Selection
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Select Crop',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey.shade300,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: DropdownButtonHideUnderline(
                                      child: DropdownButton<String>(
                                        value: _selectedCropId.isEmpty
                                            ? null
                                            : _selectedCropId,
                                        isExpanded: true,
                                        hint: const Text('Select Crop'),
                                        items: _crops
                                            .map<DropdownMenuItem<String>>((
                                              crop,
                                            ) {
                                              return DropdownMenuItem<String>(
                                                value:
                                                    crop['crop_id'] as String,
                                                child: Text(
                                                  crop['name'] as String,
                                                ),
                                              );
                                            })
                                            .toList(),
                                        onChanged: (value) {
                                          setState(
                                            () => _selectedCropId = value!,
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Workers Section
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 5,
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Workers & Harvest',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w500,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Total: ${_totalHarvestWeight.toStringAsFixed(1)} kg',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Worker List
                                  if (_tempHarvestWorkers.isNotEmpty) ...[
                                    Container(
                                      constraints: const BoxConstraints(
                                        maxHeight: 200,
                                      ),
                                      child: ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const AlwaysScrollableScrollPhysics(),
                                        itemCount: _tempHarvestWorkers.length,
                                        itemBuilder: (context, index) {
                                          final worker =
                                              _tempHarvestWorkers[index];
                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 4,
                                            ),
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.green.shade50,
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              border: Border.all(
                                                color: Colors.green.shade200,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                CircleAvatar(
                                                  radius: 14,
                                                  backgroundColor: const Color(
                                                    0xFF2E7D32,
                                                  ),
                                                  child: Text(
                                                    (worker['name'] as String)
                                                        .substring(0, 1)
                                                        .toUpperCase(),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 8),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        worker['name'],
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.w500,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                      Text(
                                                        '${worker['quantity']} kg • ₹${worker['earnings']}',
                                                        style: const TextStyle(
                                                          fontSize: 11,
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons.remove_circle_outline,
                                                    color: Colors.red,
                                                    size: 20,
                                                  ),
                                                  onPressed: () =>
                                                      _removeWorkerFromHarvest(
                                                        index,
                                                      ),
                                                  padding: EdgeInsets.zero,
                                                  constraints:
                                                      const BoxConstraints(),
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    const Divider(),
                                    const SizedBox(height: 8),
                                  ],

                                  // Add Worker Section
                                  const Text(
                                    'Add Worker to Harvest',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w500,
                                      fontSize: 14,
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Worker Name & Quantity Row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Worker Name',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            // Use Overlay for suggestions to show above everything
                                            Stack(
                                              clipBehavior: Clip.none,
                                              children: [
                                                TextField(
                                                  controller:
                                                      _workerNameController,
                                                  focusNode: _workerNameFocus,
                                                  onChanged: _updateSuggestions,
                                                  decoration: InputDecoration(
                                                    hintText:
                                                        'Type name (e.g., Nimal)',
                                                    prefixIcon: const Icon(
                                                      Icons.person_outline,
                                                      size: 18,
                                                    ),
                                                    suffixIcon:
                                                        _workerNameController
                                                            .text
                                                            .isNotEmpty
                                                        ? IconButton(
                                                            icon: const Icon(
                                                              Icons.close,
                                                              size: 16,
                                                            ),
                                                            onPressed: () {
                                                              setState(() {
                                                                _workerNameController
                                                                    .clear();
                                                                _suggestedWorkers =
                                                                    [];
                                                              });
                                                            },
                                                          )
                                                        : null,
                                                    border: OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    contentPadding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 10,
                                                        ),
                                                  ),
                                                  textInputAction:
                                                      TextInputAction.next,
                                                  onSubmitted: (_) {
                                                    _quantityFocus
                                                        .requestFocus();
                                                  },
                                                ),
                                                // Suggestions Dropdown - Positioned with high z-index using Overlay
                                                if (_suggestedWorkers
                                                    .isNotEmpty)
                                                  Positioned(
                                                    top: 40,
                                                    left: 0,
                                                    right: 0,
                                                    child: Container(
                                                      constraints:
                                                          const BoxConstraints(
                                                            maxHeight: 150,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: Colors.white,
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                        boxShadow: [
                                                          BoxShadow(
                                                            color: Colors.black
                                                                .withOpacity(
                                                                  0.2,
                                                                ),
                                                            blurRadius: 15,
                                                            offset:
                                                                const Offset(
                                                                  0,
                                                                  5,
                                                                ),
                                                          ),
                                                        ],
                                                        border: Border.all(
                                                          color: Colors
                                                              .grey
                                                              .shade300,
                                                        ),
                                                      ),
                                                      child: ListView.builder(
                                                        shrinkWrap: true,
                                                        itemCount:
                                                            _suggestedWorkers
                                                                .length,
                                                        itemBuilder: (context, index) {
                                                          final worker =
                                                              _suggestedWorkers[index];
                                                          return ListTile(
                                                            
                                                            dense: true,
                                                            leading: CircleAvatar(
                                                              radius: 14,
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xFF2E7D32,
                                                                  ).withOpacity(
                                                                    0.1,
                                                                  ),
                                                              child: Text(
                                                                (worker['name']
                                                                        as String)
                                                                    .substring(
                                                                      0,
                                                                      1,
                                                                    )
                                                                    .toUpperCase(),
                                                                style: const TextStyle(
                                                                  fontSize: 12,
                                                                  color: Color(
                                                                    0xFF2E7D32,
                                                                  ),
                                                                ),
                                                              ),
                                                            ),
                                                            title: Text(
                                                              worker['name'],
                                                              style:
                                                                  const TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                  ),
                                                            ),
                                                            subtitle:
                                                                worker['nick_name'] !=
                                                                        null &&
                                                                    (worker['nick_name']
                                                                            as String)
                                                                        .isNotEmpty
                                                                ? Text(
                                                                    worker['nick_name'],
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                    ),
                                                                  )
                                                                : null,
                                                            onTap: () =>
                                                                _selectSuggestion(
                                                                  worker,
                                                                ),
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        flex: 2,
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Weight (kg)',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            TextField(
                                              controller: _quantityController,
                                              focusNode: _quantityFocus,
                                              keyboardType:
                                                  TextInputType.number,
                                              decoration: InputDecoration(
                                                hintText: '0.0',
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 10,
                                                    ),
                                              ),
                                              onSubmitted: (_) =>
                                                  _addWorkerToHarvest(),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Payment Method & Transport Row
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              _selectedPaymentMethod == 'per_kg'
                                              ? Colors.green.shade100
                                              : Colors.orange.shade100,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                        child: Text(
                                          _selectedPaymentMethod == 'per_kg'
                                              ? '₹$_ratePerKg/kg'
                                              : '₹$_dailyWage/day',
                                          style: TextStyle(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w500,
                                            color:
                                                _selectedPaymentMethod ==
                                                    'per_kg'
                                                ? Colors.green.shade700
                                                : Colors.orange.shade700,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      GestureDetector(
                                        onTap: () {
                                          setState(() {
                                            _selectedPaymentMethod =
                                                _selectedPaymentMethod ==
                                                    'per_kg'
                                                ? 'per_day'
                                                : 'per_kg';
                                          });
                                        },
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 6,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            border: Border.all(
                                              color: Colors.grey.shade300,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            _selectedPaymentMethod == 'per_kg'
                                                ? 'Switch to Day'
                                                : 'Switch to KG',
                                            style: const TextStyle(
                                              fontSize: 10,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const Spacer(),
                                      Container(
                                        width: 100,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 4,
                                        ),
                                        child: TextField(
                                          decoration: const InputDecoration(
                                            labelText: 'Transport',
                                            hintText: '₹',
                                            border: OutlineInputBorder(),
                                            contentPadding:
                                                EdgeInsets.symmetric(
                                                  horizontal: 4,
                                                  vertical: 6,
                                                ),
                                            isDense: true,
                                          ),
                                          keyboardType: TextInputType.number,
                                          onChanged: (v) {
                                            _transportCost =
                                                double.tryParse(v) ?? 0;
                                          },
                                        ),
                                      ),
                                    ],
                                  ),

                                  const SizedBox(height: 8),

                                  // Add Worker Button
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton.icon(
                                      onPressed: _isAddingWorker
                                          ? null
                                          : _addWorkerToHarvest,
                                      icon: _isAddingWorker
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(Icons.add),
                                      label: Text(
                                        _isAddingWorker
                                            ? 'Adding...'
                                            : 'Add Worker to Harvest',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(
                                          0xFF2E7D32,
                                        ),
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 12,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),

                                  const SizedBox(height: 4),
                                  const Text(
                                    '💡 Type worker name → suggestions appear → tap or press Add',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Summary Card
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  Column(
                                    children: [
                                      const Text(
                                        'Total Harvest',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${_totalHarvestWeight.toStringAsFixed(1)} kg',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2E7D32),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    color: Colors.grey.shade300,
                                  ),
                                  Column(
                                    children: [
                                      const Text(
                                        'Total Labor',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '₹${_totalLaborCost.toStringAsFixed(0)}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFFF57C00),
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    width: 1,
                                    height: 30,
                                    color: Colors.grey.shade300,
                                  ),
                                  Column(
                                    children: [
                                      const Text(
                                        'Workers',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: Colors.grey,
                                        ),
                                      ),
                                      Text(
                                        '${_tempHarvestWorkers.length}',
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1565C0),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 16),

                            // Save Button
                            SizedBox(
                              width: double.infinity,
                              height: 54,
                              child: ElevatedButton(
                                onPressed: _isSaving ? null : _saveHarvest,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2E7D32),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: _isSaving
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        _isEditingExisting
                                            ? '✏️ Update Today\'s Harvest'
                                            : '✅ Save Harvest',
                                        style: const TextStyle(fontSize: 16),
                                      ),
                              ),
                            ),

                            const SizedBox(height: 8),

                            if (_isEditingExisting)
                              const Text(
                                '✏️ Editing today\'s harvest - new weights will be added to existing records',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.blue,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  String _formatDisplayDate(String date) {
    if (date.isEmpty) return '';
    final parts = date.split('-');
    if (parts.length == 3) {
      const months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec',
      ];
      final month = months[int.parse(parts[1]) - 1];
      return '$month ${int.parse(parts[2])}, ${parts[0]}';
    }
    return date;
  }
}
