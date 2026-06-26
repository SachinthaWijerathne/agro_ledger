// lib/auth/onboarding_screen.dart
import 'package:agro_ledger/screens/tab_screens/main_tab_screen.dart';
import 'package:agro_ledger/services/local_storage_service.dart';
import 'package:agro_ledger/utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Farm Details
  final _farmNameController = TextEditingController();
  final _farmLocationController = TextEditingController();
  final _farmSizeController = TextEditingController();
  
  // Crops
  final List<Map<String, dynamic>> _crops = [];
  String _selectedCrop = 'Tea';
  String _cropType = 'main';
  final _cropAreaController = TextEditingController();
  
  // Settings
  double _defaultTransportCost = 50;
  String _defaultPaymentMethod = 'per_kg';
  double _defaultPerKgRate = 5.0;
  double _defaultDailyWage = 300.0;
  
  bool _isLoading = false;
  int _currentStep = 0;

  final List<String> _cropOptions = ['Tea', 'Pepper', 'Banana', 'Rubber', 'Paddy', 'Coconut', 'Arecanut', 'Other'];
  final List<String> _cropTypeOptions = ['main', 'intercrop'];
  final List<String> _paymentMethodOptions = ['per_kg', 'per_day'];
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  @override
  void dispose() {
    _farmNameController.dispose();
    _farmLocationController.dispose();
    _farmSizeController.dispose();
    _cropAreaController.dispose();
    super.dispose();
  }

  void _addCrop() {
    if (_cropAreaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter crop area')),
      );
      return;
    }
    setState(() {
      _crops.add({
        'name': _selectedCrop,
        'type': _cropType,
        'area': double.parse(_cropAreaController.text),
      });
      _cropAreaController.clear();
      _selectedCrop = 'Tea';
      _cropType = 'intercrop';
    });
  }

  void _removeCrop(int index) {
    setState(() => _crops.removeAt(index));
  }

  Future<void> _saveAndComplete() async {
    if (_farmNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter farm name')),
      );
      return;
    }
    if (_crops.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one crop')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final localStorage = await LocalStorageService.getInstance();
      
      // Get existing farms or create new
      final farms = await localStorage.getAllFarms();
      String farmId;
      
      if (farms.isNotEmpty) {
        farmId = farms.first['farm_id'];
        // Update existing farm
        await localStorage.updateFarm(farmId, {
          'name': _farmNameController.text,
          'location': _farmLocationController.text,
          'size': double.tryParse(_farmSizeController.text) ?? 0,
          'default_transport_cost': _defaultTransportCost,
          'default_payment_method': _defaultPaymentMethod,
          'default_per_kg_rate': _defaultPerKgRate,
          'default_daily_wage': _defaultDailyWage,
        });
      } else {
        // Create new farm
        farmId = Helpers.generateId();
        final users = await localStorage.getAllUserProfiles();
        final userId = users.isNotEmpty ? users.first['user_id'] : Helpers.generateId();
        
        await localStorage.insertFarm({
          'farm_id': farmId,
          'user_id': userId,
          'name': _farmNameController.text,
          'location': _farmLocationController.text,
          'size': double.tryParse(_farmSizeController.text) ?? 0,
          'default_transport_cost': _defaultTransportCost,
          'default_payment_method': _defaultPaymentMethod,
          'default_per_kg_rate': _defaultPerKgRate,
          'default_daily_wage': _defaultDailyWage,
        });
      }

      // Save crops
      for (var crop in _crops) {
        await localStorage.insertCrop({
          'crop_id': Helpers.generateId(),
          'farm_id': farmId,
          'name': crop['name'],
          'crop_type': crop['type'],
          'variety': '',
          'plantation_size': crop['area'],
          'planting_date': DateTime.now().toIso8601String(),
          'status': 'active',
          'notes': '',
        });
      }

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainTabScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Setup Your Farm'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          if (_currentStep > 0)
            TextButton(
              onPressed: () {
                setState(() => _currentStep = 0);
              },
              child: const Text(
                'Reset',
                style: TextStyle(color: Colors.white70),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF2E7D32)),
                  SizedBox(height: 16),
                  Text('Setting up your farm...'),
                ],
              ),
            )
          : Stepper(
              type: StepperType.vertical,
              currentStep: _currentStep,
              onStepContinue: () {
                if (_currentStep < 2) {
                  setState(() => _currentStep++);
                } else {
                  _saveAndComplete();
                }
              },
              onStepCancel: () {
                if (_currentStep > 0) {
                  setState(() => _currentStep--);
                }
              },
              controlsBuilder: (context, details) {
                return Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: details.onStepContinue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2E7D32),
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 44),
                          ),
                          child: Text(_currentStep == 2 ? 'Finish Setup' : 'Continue'),
                        ),
                      ),
                      if (_currentStep > 0) const SizedBox(width: 8),
                      if (_currentStep > 0)
                        Expanded(
                          child: OutlinedButton(
                            onPressed: details.onStepCancel,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xFF2E7D32),
                              side: const BorderSide(color: Color(0xFF2E7D32)),
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            child: const Text('Back'),
                          ),
                        ),
                    ],
                  ),
                );
              },
              steps: [
                Step(
                  title: const Text('Farm Details'),
                  content: _buildFarmDetailsStep(),
                  isActive: _currentStep >= 0,
                  state: _currentStep > 0 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Add Crops'),
                  content: _buildCropsStep(),
                  isActive: _currentStep >= 1,
                  state: _currentStep > 1 ? StepState.complete : StepState.indexed,
                ),
                Step(
                  title: const Text('Settings'),
                  content: _buildSettingsStep(),
                  isActive: _currentStep >= 2,
                  state: _currentStep > 2 ? StepState.complete : StepState.indexed,
                ),
              ],
            ),
    );
  }

  // ============================================
  // FARM DETAILS STEP
  // ============================================

  Widget _buildFarmDetailsStep() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Farm Name
          const Text(
            'Farm Name *',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _farmNameController,
            decoration: const InputDecoration(
              hintText: 'e.g., Green Hills Estate',
              prefixIcon: Icon(Icons.agriculture),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            validator: (v) => v?.isEmpty == true ? 'Enter farm name' : null,
          ),
          const SizedBox(height: 16),

          // Farm Location
          const Text(
            'Farm Location',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _farmLocationController,
            decoration: const InputDecoration(
              hintText: 'e.g., Munnar, Kerala',
              prefixIcon: Icon(Icons.location_on),
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Farm Size
          const Text(
            'Farm Size (acres)',
            style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _farmSizeController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              hintText: 'e.g., 25',
              prefixIcon: Icon(Icons.straighten),
              suffixText: 'acres',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Info Box
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'You can always update these details later in Settings.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // CROPS STEP
  // ============================================

  Widget _buildCropsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Existing Crops List
        if (_crops.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.green.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green.shade200),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Your Crops',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    Text(
                      '${_crops.length} total',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ..._crops.asMap().entries.map((entry) {
                  int idx = entry.key;
                  var crop = entry.value;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            crop['type'] == 'main' ? Icons.star : Icons.grass,
                            size: 16,
                            color: crop['type'] == 'main' ? Colors.amber : Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${crop['name']} - ${crop['area']} acres (${crop['type']})',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16, color: Colors.red),
                            onPressed: () => _removeCrop(idx),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
              ],
            ),
          ),

        // Add New Crop Section
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.blue.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Add New Crop',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 12),
              
              // Crop Name & Type Row
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: DropdownButtonFormField<String>(
                      initialValue: _selectedCrop,
                      decoration: const InputDecoration(
                        labelText: 'Crop Name',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: _cropOptions.map((crop) {
                        return DropdownMenuItem(value: crop, child: Text(crop));
                      }).toList(),
                      onChanged: (v) => setState(() => _selectedCrop = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _cropType,
                      decoration: const InputDecoration(
                        labelText: 'Type',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(value: 'main', child: Text('Main Crop')),
                        DropdownMenuItem(value: 'intercrop', child: Text('Intercrop')),
                      ],
                      onChanged: (v) => setState(() => _cropType = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Area & Add Button Row
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _cropAreaController,
                      decoration: const InputDecoration(
                        labelText: 'Area (acres)',
                        suffixText: 'acres',
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _addCrop,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2E7D32),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(80, 44),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.amber.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, size: 16, color: Colors.amber.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'Tip: Add your main crop first, then intercrops.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // SETTINGS STEP
  // ============================================

  Widget _buildSettingsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.orange.shade50,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange.shade200),
          ),
          child: Column(
            children: [
              // Payment Method
              DropdownButtonFormField<String>(
                initialValue: _defaultPaymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Default Payment Method',
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'per_kg', child: Text('Per Kilogram (Rs/kg)')),
                  DropdownMenuItem(value: 'per_day', child: Text('Per Day (Rs/day)')),
                ],
                onChanged: (v) => setState(() => _defaultPaymentMethod = v!),
              ),
              const SizedBox(height: 12),

              // Rate based on payment method
              if (_defaultPaymentMethod == 'per_kg')
                TextFormField(
                  initialValue: _defaultPerKgRate.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Default Rate (Rs/kg)',
                    prefixIcon: Icon(Icons.currency_rupee, size: 20),
                    suffixText: '/kg',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _defaultPerKgRate = double.tryParse(v) ?? 0,
                )
              else
                TextFormField(
                  initialValue: _defaultDailyWage.toString(),
                  decoration: const InputDecoration(
                    labelText: 'Default Daily Wage (Rs/day)',
                    prefixIcon: Icon(Icons.currency_rupee, size: 20),
                    suffixText: '/day',
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  keyboardType: TextInputType.number,
                  onChanged: (v) => _defaultDailyWage = double.tryParse(v) ?? 0,
                ),
              const SizedBox(height: 12),

              // Transport Cost
              TextFormField(
                initialValue: _defaultTransportCost.toString(),
                decoration: const InputDecoration(
                  labelText: 'Default Transport Cost (Rs)',
                  prefixIcon: Icon(Icons.local_taxi, size: 20),
                  contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                keyboardType: TextInputType.number,
                onChanged: (v) => _defaultTransportCost = double.tryParse(v) ?? 0,
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Info Box
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green.shade700),
              const SizedBox(width: 8),
              const Expanded(
                child: Text(
                  'These settings will be used as defaults. You can change them per entry later.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Summary
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Setup Summary',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              ),
              const SizedBox(height: 8),
              _buildSummaryRow('Farm', _farmNameController.text.isNotEmpty ? _farmNameController.text : 'Not set'),
              _buildSummaryRow('Crops', _crops.isNotEmpty ? '${_crops.length} crops added' : 'No crops'),
              _buildSummaryRow('Payment', _defaultPaymentMethod == 'per_kg' ? 'Per KG (Rs$_defaultPerKgRate/kg)' : 'Per Day (Rs$_defaultDailyWage/day)'),
              _buildSummaryRow('Transport', 'Rs$_defaultTransportCost'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}