// lib/screens/add_maintenance_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agro_ledger/utils/helpers.dart';
import 'package:agro_ledger/services/local_storage_service.dart';

class AddMaintenanceScreen extends ConsumerStatefulWidget {
  const AddMaintenanceScreen({super.key});

  @override
  ConsumerState<AddMaintenanceScreen> createState() => _AddMaintenanceScreenState();
}

class _AddMaintenanceScreenState extends ConsumerState<AddMaintenanceScreen> {
  // ============================================
  // STATE VARIABLES
  // ============================================
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Farm
  String _farmId = '';
  
  // Crops
  List<Map<String, dynamic>> _crops = [];
  String _selectedCropId = '';
  
  // Workers
  List<Map<String, dynamic>> _allWorkers = [];
  List<Map<String, dynamic>> _suggestedWorkers = [];
  
  // Maintenance Type
  String _maintenanceType = 'pruning'; // pruning, weeding, spraying, irrigation, planting, other
  String _paymentType = 'daily_wage'; // daily_wage, contract
  
  // Daily Wage Fields
  String _selectedWorkerId = '';
  final TextEditingController _workerNameController = TextEditingController();
  final TextEditingController _hoursWorkedController = TextEditingController();
  double _dailyWageRate = 300.0;
  
  // Contract Fields
  final TextEditingController _contractDescriptionController = TextEditingController();
  final TextEditingController _contractAmountController = TextEditingController();
  int _contractWorkersCount = 1;
  
  // Common Fields
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _dateController = TextEditingController();
  String _selectedStatus = 'completed'; // completed, in_progress, planned
  
  // Focus
  final FocusNode _workerNameFocus = FocusNode();
  final FocusNode _hoursFocus = FocusNode();
  final FocusNode _contractDescFocus = FocusNode();
  final FocusNode _contractAmountFocus = FocusNode();

  final List<String> _maintenanceTypes = [
    'Pruning',
    'Weeding',
    'Spraying',
    'Irrigation',
    'Planting',
    'Harvesting Support',
    'Land Preparation',
    'Other'
  ];
  
  final List<String> _paymentTypes = ['Daily Wage', 'Contract'];
  final List<String> _statusOptions = ['Completed', 'In Progress', 'Planned'];

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().substring(0, 10);
    _loadData();
  }

  @override
  void dispose() {
    _workerNameController.dispose();
    _hoursWorkedController.dispose();
    _contractDescriptionController.dispose();
    _contractAmountController.dispose();
    _notesController.dispose();
    _dateController.dispose();
    _workerNameFocus.dispose();
    _hoursFocus.dispose();
    _contractDescFocus.dispose();
    _contractAmountFocus.dispose();
    super.dispose();
  }

  // ============================================
  // DATA LOADING
  // ============================================

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    
    try {
      final localStorage = await LocalStorageService.getInstance();
      
      final farms = await localStorage.getAllFarms();
      if (farms.isNotEmpty) {
        _farmId = farms.first['farm_id'];
        _dailyWageRate = (farms.first['default_daily_wage'] as num?)?.toDouble() ?? 300.0;
      }
      
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
      
      _allWorkers = await localStorage.getWorkersByFarm(_farmId);
      _suggestedWorkers = [];
      
    } catch (e) {
      debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // ============================================
  // WORKER SUGGESTIONS
  // ============================================

  void _updateWorkerSuggestions(String query) {
    final trimmed = query.trim().toLowerCase();
    if (trimmed.isEmpty) {
      setState(() => _suggestedWorkers = []);
      return;
    }
    
    setState(() {
      _suggestedWorkers = _allWorkers.where((worker) {
        final name = (worker['name'] as String).toLowerCase();
        final nickName = (worker['nick_name'] ?? '').toLowerCase();
        return name.contains(trimmed) || nickName.contains(trimmed);
      }).toList();
    });
  }

  void _selectWorker(Map<String, dynamic> worker) {
    setState(() {
      _workerNameController.text = worker['name'];
      _selectedWorkerId = worker['worker_id'];
      _suggestedWorkers = [];
      _workerNameFocus.unfocus();
      _hoursFocus.requestFocus();
    });
  }

  // ============================================
  // SAVE MAINTENANCE
  // ============================================

  Future<void> _saveMaintenance() async {
    // Validate
    if (_selectedCropId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a crop')),
      );
      return;
    }
    
    if (_paymentType == 'daily_wage') {
      if (_selectedWorkerId.isEmpty && _workerNameController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select or enter a worker name')),
        );
        _workerNameFocus.requestFocus();
        return;
      }
      
      if (_hoursWorkedController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter hours worked')),
        );
        _hoursFocus.requestFocus();
        return;
      }
    } else {
      if (_contractDescriptionController.text.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter contract description')),
        );
        _contractDescFocus.requestFocus();
        return;
      }
      
      if (_contractAmountController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter contract amount')),
        );
        _contractAmountFocus.requestFocus();
        return;
      }
    }
    
    setState(() => _isSaving = true);
    
    try {
      final localStorage = await LocalStorageService.getInstance();
      final activityId = Helpers.generateId();
      
      // Get or create worker for daily wage
      String? workerId = _selectedWorkerId;
      if (_paymentType == 'daily_wage' && workerId.isEmpty) {
        final workerName = _workerNameController.text.trim();
        // Find existing worker
        final existing = await localStorage.findWorkerByName(_farmId, workerName);
        if (existing != null) {
          workerId = existing['worker_id'];
        } else {
          // Create new worker
          workerId = Helpers.generateId();
          await localStorage.insertWorker({
            'worker_id': workerId,
            'farm_id': _farmId,
            'name': workerName,
            'nick_name': '',
            'gender': 'other',
            'phone': '',
            'address': '',
            'join_date': DateTime.now().toIso8601String().substring(0, 10),
            'is_active': 1,
            'notes': 'Auto-created during maintenance entry',
            'created_at': DateTime.now().toIso8601String(),
            'updated_at': DateTime.now().toIso8601String(),
          });
        }
      }
      
      // Calculate amount
      double amount = 0;
      String description = '';
      
      if (_paymentType == 'daily_wage') {
        final hours = double.parse(_hoursWorkedController.text);
        amount = hours * _dailyWageRate;
        final workerName = _allWorkers.firstWhere(
          (w) => w['worker_id'] == workerId,
          orElse: () => {'name': _workerNameController.text},
        )['name'];
        description = 'Daily wage - ${_maintenanceType.replaceAll('_', ' ').toUpperCase()} - $workerName (${hours}h @ ₹$_dailyWageRate/h)';
      } else {
        amount = double.parse(_contractAmountController.text);
        description = _contractDescriptionController.text;
      }
      
      // Save to labor_activities table
      await localStorage.insertLaborActivity({
        'activity_id': activityId,
        'farm_id': _farmId,
        'worker_id': _paymentType == 'daily_wage' ? workerId : null,
        'crop_id': _selectedCropId,
        'field_id': null,
        'activity_type': _maintenanceType,
        'description': description,
        'start_time': _dateController.text,
        'end_time': _paymentType == 'daily_wage' 
            ? DateTime.now().toIso8601String() 
            : null,
        'hours_worked': _paymentType == 'daily_wage' 
            ? double.tryParse(_hoursWorkedController.text) 
            : null,
        'notes': _notesController.text,
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // If contract, also save as other_expense
      if (_paymentType == 'contract') {
        await localStorage.insertOtherExpense({
          'expense_id': Helpers.generateId(),
          'farm_id': _farmId,
          'crop_id': _selectedCropId,
          'date': _dateController.text,
          'category': 'miscellaneous',
          'amount': amount,
          'description': 'Contract: $description',
          'notes': _notesController.text,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ Maintenance recorded successfully!'),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context);
      }
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error saving: $e'), backgroundColor: Colors.red),
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
    if (_isLoading) {
      return  Scaffold(
        appBar: AppBar(title: Text('Add Maintenance')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Add Maintenance'),
        backgroundColor: const Color(0xFF1565C0),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Date
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
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(
                          controller: _dateController,
                          readOnly: true,
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            isDense: true,
                          ),
                          onTap: () async {
                            final date = await showDatePicker(
                              context: context,
                              initialDate: DateTime.now(),
                              firstDate: DateTime(2020),
                              lastDate: DateTime(2030),
                            );
                            if (date != null) {
                              setState(() {
                                _dateController.text = date.toIso8601String().substring(0, 10);
                              });
                            }
                          },
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
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade300),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                                        value: _selectedCropId.isEmpty ? null : _selectedCropId,
                                        isExpanded: true,
                                        hint: const Text('Select Crop'),
                                        items: _crops.map<DropdownMenuItem<String>>((crop) {
                                          return DropdownMenuItem<String>(
                                            value: crop['crop_id'] as String,
                                            child: Text(crop['name'] as String),
                                          );
                                        }).toList(),
                                        onChanged: (value) {
                                          setState(() => _selectedCropId = value!);
                                        },
                                      ),
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Maintenance Type
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
                        'Maintenance Type',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _maintenanceTypes.map((type) {
                          final value = type.toLowerCase().replaceAll(' ', '_');
                          return FilterChip(
                            label: Text(type),
                            selected: _maintenanceType == value,
                            onSelected: (selected) {
                              setState(() {
                                _maintenanceType = value;
                              });
                            },
                            selectedColor: Colors.blue.shade100,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Payment Type
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
                        'Payment Type',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _paymentTypes.map((type) {
                          final value = type.toLowerCase().replaceAll(' ', '_');
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(type),
                                selected: _paymentType == value,
                                onSelected: (selected) {
                                  setState(() {
                                    _paymentType = value;
                                  });
                                },
                                selectedColor: Colors.orange.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Payment Details
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
                      if (_paymentType == 'daily_wage') ...[
                        const Text(
                          'Daily Wage Details',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        
                        // Worker Name with Suggestions
                        const Text(
                          'Worker Name',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Stack(
                          children: [
                            TextField(
                              controller: _workerNameController,
                              focusNode: _workerNameFocus,
                              onChanged: _updateWorkerSuggestions,
                              decoration: InputDecoration(
                                hintText: 'Type worker name',
                                prefixIcon: const Icon(Icons.person_outline, size: 18),
                                suffixIcon: _workerNameController.text.isNotEmpty
                                    ? IconButton(
                                        icon: const Icon(Icons.close, size: 16),
                                        onPressed: () {
                                          setState(() {
                                            _workerNameController.clear();
                                            _suggestedWorkers = [];
                                            _selectedWorkerId = '';
                                          });
                                        },
                                      )
                                    : null,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 10,
                                ),
                              ),
                              textInputAction: TextInputAction.next,
                              onSubmitted: (_) => _hoursFocus.requestFocus(),
                            ),
                            if (_suggestedWorkers.isNotEmpty)
                              Positioned(
                                top: 46,
                                left: 0,
                                right: 0,
                                child: Container(
                                  constraints: const BoxConstraints(maxHeight: 150),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(8),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 10,
                                      ),
                                    ],
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
                                          backgroundColor: const Color(0xFF1565C0).withOpacity(0.1),
                                          child: Text(
                                            (worker['name'] as String).substring(0, 1).toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Color(0xFF1565C0),
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          worker['name'],
                                          style: const TextStyle(fontSize: 13),
                                        ),
                                        onTap: () => _selectWorker(worker),
                                      );
                                    },
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Hours Worked
                        const Text(
                          'Hours Worked',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _hoursWorkedController,
                          focusNode: _hoursFocus,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 4',
                            suffixText: 'hours',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Rate Display
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade50,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Rate per hour:'),
                              Text(
                                '₹$_dailyWageRate',
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        
                      ] else ...[
                        // Contract Details
                        const Text(
                          'Contract Details',
                          style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
                        ),
                        const SizedBox(height: 12),
                        
                        const Text(
                          'Work Description',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _contractDescriptionController,
                          focusNode: _contractDescFocus,
                          maxLines: 3,
                          decoration: InputDecoration(
                            hintText: 'Describe the contract work...',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        
                        // Number of Workers
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Number of Workers',
                                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove, size: 18),
                                    onPressed: () {
                                      if (_contractWorkersCount > 1) {
                                        setState(() => _contractWorkersCount--);
                                      }
                                    },
                                  ),
                                  SizedBox(
                                    width: 30,
                                    child: Text(
                                      _contractWorkersCount.toString(),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add, size: 18),
                                    onPressed: () {
                                      setState(() => _contractWorkersCount++);
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        
                        // Contract Amount
                        const Text(
                          'Contract Amount (₹)',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        TextField(
                          controller: _contractAmountController,
                          focusNode: _contractAmountFocus,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            hintText: 'e.g., 5000',
                            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 10,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Status
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
                        'Status',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: _statusOptions.map((status) {
                          final value = status.toLowerCase().replaceAll(' ', '_');
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 4),
                              child: FilterChip(
                                label: Text(status),
                                selected: _selectedStatus == value,
                                onSelected: (selected) {
                                  setState(() {
                                    _selectedStatus = value;
                                  });
                                },
                                selectedColor: _selectedStatus == 'completed'
                                    ? Colors.green.shade100
                                    : _selectedStatus == 'in_progress'
                                    ? Colors.orange.shade100
                                    : Colors.blue.shade100,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(20),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Notes
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
                        'Notes (Optional)',
                        style: TextStyle(fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _notesController,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Additional notes...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 10,
                          ),
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
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          Column(
                            children: [
                              const Text(
                                'Type',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                _maintenanceType.replaceAll('_', ' ').toUpperCase(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1565C0),
                                ),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: Colors.grey.shade300),
                          Column(
                            children: [
                              const Text(
                                'Payment',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Text(
                                _paymentType == 'daily_wage' ? 'Daily Wage' : 'Contract',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFF57C00),
                                ),
                              ),
                            ],
                          ),
                          Container(width: 1, height: 30, color: Colors.grey.shade300),
                          Column(
                            children: [
                              const Text(
                                'Status',
                                style: TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: _selectedStatus == 'completed'
                                      ? Colors.green.shade100
                                      : _selectedStatus == 'in_progress'
                                      ? Colors.orange.shade100
                                      : Colors.blue.shade100,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _selectedStatus.replaceAll('_', ' ').toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: _selectedStatus == 'completed'
                                        ? Colors.green.shade700
                                        : _selectedStatus == 'in_progress'
                                        ? Colors.orange.shade700
                                        : Colors.blue.shade700,
                                  ),
                                ),
                              ),
                            ],
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
                    onPressed: _isSaving ? null : _saveMaintenance,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1565C0),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _isSaving
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            '✅ Record Maintenance',
                            style: TextStyle(fontSize: 16),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}