// lib/settings/settings_screen.dart
import 'package:agro_ledger/services/local_storage_service.dart';
import 'package:agro_ledger/services/pin_service.dart';
import 'package:agro_ledger/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  final PinService _pinService = PinService();
  bool _isLoading = true;
  Map<String, dynamic>? _farmSettings;
  Map<String, dynamic>? _userProfile;
  
  // Farm Settings
  String _farmName = '';
  String _farmLocation = '';
  String _farmSize = '';
  
  // Labor Settings
  String _paymentMethod = 'per_kg';
  double _perKgRate = 5.0;
  double _dailyWage = 300.0;
  double _transportCost = 50.0;
  
  // Security Settings
  bool _pinEnabled = false;
  
  // Display Settings
  double _fontScale = 1.0;
  String _selectedTheme = 'light';
  
  // Notification Settings
  bool _notificationsEnabled = true;
  bool _autoBackupEnabled = false;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    setState(() => _isLoading = true);
    try {
      final localStorage = await LocalStorageService.getInstance();
      
      // Load farm settings
      final farms = await localStorage.getAllFarms();
      if (farms.isNotEmpty) {
        final farm = farms.first;
        _farmSettings = farm;
        _farmName = farm['name'] ?? '';
        _farmLocation = farm['location'] ?? '';
        _farmSize = farm['size']?.toString() ?? '';
        _paymentMethod = farm['default_payment_method'] ?? 'per_kg';
        _perKgRate = (farm['default_per_kg_rate'] as num?)?.toDouble() ?? 5.0;
        _dailyWage = (farm['default_daily_wage'] as num?)?.toDouble() ?? 300.0;
        _transportCost = (farm['default_transport_cost'] as num?)?.toDouble() ?? 50.0;
      }
      
      // Load user profile
      final users = await localStorage.getAllUserProfiles();
      if (users.isNotEmpty) {
        _userProfile = users.first;
      }
      
      // Load PIN status
      _pinEnabled = await _pinService.isPinSetup();
      
      // Load display settings from shared preferences (simplified)
      // In production, use SharedPreferences
      
    } catch (e) {
      debugPrint('Error loading settings: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);
    try {
      final localStorage = await LocalStorageService.getInstance();
      
      final farms = await localStorage.getAllFarms();
      if (farms.isNotEmpty) {
        final farmId = farms.first['farm_id'];
        await localStorage.updateFarm(farmId, {
          'name': _farmName,
          'location': _farmLocation,
          'size': double.tryParse(_farmSize) ?? 0,
          'default_payment_method': _paymentMethod,
          'default_per_kg_rate': _perKgRate,
          'default_daily_wage': _dailyWage,
          'default_transport_cost': _transportCost,
        });
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Settings saved successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _showPinSetupDialog() async {
    final pinController = TextEditingController();
    final confirmController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Set Up PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Enter a 4-digit PIN to secure your app'),
            const SizedBox(height: 16),
            TextField(
              controller: pinController,
              decoration: const InputDecoration(
                labelText: 'New PIN (4 digits)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Confirm PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (pinController.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 4 digits')),
                );
                return;
              }
              if (pinController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }
              await _pinService.setupPin(pinController.text);
              setState(() => _pinEnabled = true);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN enabled successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Enable'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePinDialog() async {
    final oldPinController = TextEditingController();
    final newPinController = TextEditingController();
    final confirmController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Change PIN'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: oldPinController,
              decoration: const InputDecoration(
                labelText: 'Current PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPinController,
              decoration: const InputDecoration(
                labelText: 'New PIN (4 digits)',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              decoration: const InputDecoration(
                labelText: 'Confirm New PIN',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              keyboardType: TextInputType.number,
              maxLength: 4,
              obscureText: true,
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              if (!await _pinService.verifyPin(oldPinController.text)) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Current PIN is incorrect')),
                );
                return;
              }
              if (newPinController.text.length != 4) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PIN must be 4 digits')),
                );
                return;
              }
              if (newPinController.text != confirmController.text) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PINs do not match')),
                );
                return;
              }
              await _pinService.setupPin(newPinController.text);
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('PIN changed successfully!'),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            },
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear All Data'),
        content: const Text(
          'Are you sure? This will delete all your farm data, harvests, sales, inventory, and cannot be undone.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final localStorage = await LocalStorageService.getInstance();
              await localStorage.clearAllData();
              if (mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('All data cleared!'),
                    backgroundColor: Colors.green,
                  ),
                );
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppConstants.routeSplash,
                  (route) => false,
                );
              }
            },
            child: const Text('Clear', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: Text('Settings')),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveSettings,
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ============================================
            // USER PROFILE SECTION
            // ============================================
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.green.shade50,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: const Color(0xFF2E7D32),
                    child: Text(
                      _userProfile?['name']?.substring(0, 1)?.toUpperCase() ?? '?',
                      style: const TextStyle(fontSize: 24, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _userProfile?['name'] ?? 'Farmer',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _userProfile?['email'] ?? 'No email set',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Navigate to edit profile
                    },
                    child: const Text('Edit'),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ============================================
            // FARM INFORMATION
            // ============================================
            _buildSectionHeader('Farm Information', Icons.agriculture),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    _buildTextField(
                      label: 'Farm Name',
                      value: _farmName,
                      icon: Icons.agriculture,
                      onChanged: (v) => setState(() => _farmName = v),
                    ),
                    const Divider(),
                    _buildTextField(
                      label: 'Location',
                      value: _farmLocation,
                      icon: Icons.location_on,
                      onChanged: (v) => setState(() => _farmLocation = v),
                    ),
                    const Divider(),
                    _buildTextField(
                      label: 'Farm Size (acres)',
                      value: _farmSize,
                      icon: Icons.straighten,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => setState(() => _farmSize = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ============================================
            // LABOR SETTINGS
            // ============================================
            _buildSectionHeader('Labor Settings', Icons.people),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Payment Method
                    Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text('Payment Method', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _paymentMethod,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'per_kg', child: Text('Per KG')),
                                  DropdownMenuItem(value: 'per_day', child: Text('Per Day')),
                                ],
                                onChanged: (v) => setState(() => _paymentMethod = v!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Rate based on payment method
                    if (_paymentMethod == 'per_kg')
                      _buildTextField(
                        label: 'Default Rate (Rs/kg)',
                        value: _perKgRate.toString(),
                        keyboardType: TextInputType.number,
                        suffix: '/kg',
                        onChanged: (v) => _perKgRate = double.tryParse(v) ?? 0,
                      )
                    else
                      _buildTextField(
                        label: 'Default Daily Wage (Rs/day)',
                        value: _dailyWage.toString(),
                        keyboardType: TextInputType.number,
                        suffix: '/day',
                        onChanged: (v) => _dailyWage = double.tryParse(v) ?? 0,
                      ),
                    const SizedBox(height: 12),

                    // Transport Cost
                    _buildTextField(
                      label: 'Default Transport Cost (Rs)',
                      value: _transportCost.toString(),
                      icon: Icons.local_taxi,
                      keyboardType: TextInputType.number,
                      onChanged: (v) => _transportCost = double.tryParse(v) ?? 0,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ============================================
            // SECURITY SECTION
            // ============================================
            _buildSectionHeader('Security', Icons.security),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Enable PIN Lock'),
                      subtitle: const Text('Secure your app with a 4-digit PIN'),
                      value: _pinEnabled,
                      onChanged: (v) async {
                        if (v) {
                          _showPinSetupDialog();
                        } else {
                          await _pinService.clearPin();
                          setState(() => _pinEnabled = false);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PIN disabled')),
                          );
                        }
                      },
                      activeColor: const Color(0xFF2E7D32),
                    ),
                    if (_pinEnabled)
                      ListTile(
                        leading: const Icon(Icons.lock_outline, color: Color(0xFF2E7D32)),
                        title: const Text('Change PIN'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _showChangePinDialog,
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ============================================
            // DISPLAY SETTINGS
            // ============================================
            _buildSectionHeader('Display Settings', Icons.format_size),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Font Size
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Font Size'),
                        Row(
                          children: [
                            IconButton(
                              icon: const Icon(Icons.remove),
                              onPressed: () {
                                setState(() {
                                  _fontScale = (_fontScale - 0.1).clamp(0.8, 1.5);
                                });
                              },
                            ),
                            Text('${(_fontScale * 100).toInt()}%'),
                            IconButton(
                              icon: const Icon(Icons.add),
                              onPressed: () {
                                setState(() {
                                  _fontScale = (_fontScale + 0.1).clamp(0.8, 1.5);
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                    Slider(
                      value: _fontScale,
                      min: 0.8,
                      max: 1.5,
                      divisions: 7,
                      label: '${(_fontScale * 100).toInt()}%',
                      onChanged: (v) => setState(() => _fontScale = v),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Preview Text',
                      style: TextStyle(fontSize: 14 * _fontScale),
                    ),
                    const Divider(),
                    
                    // Theme
                    Row(
                      children: [
                        const Expanded(
                          flex: 2,
                          child: Text('Theme Mode', style: TextStyle(fontWeight: FontWeight.w500)),
                        ),
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8),
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.grey.shade300),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: _selectedTheme,
                                isExpanded: true,
                                items: const [
                                  DropdownMenuItem(value: 'light', child: Text('Light')),
                                  DropdownMenuItem(value: 'dark', child: Text('Dark')),
                                  DropdownMenuItem(value: 'system', child: Text('System')),
                                ],
                                onChanged: (v) => setState(() => _selectedTheme = v!),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 8),

            // ============================================
            // DATA MANAGEMENT
            // ============================================
            _buildSectionHeader('Data Management', Icons.data_usage),
            Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    SwitchListTile(
                      title: const Text('Auto Backup'),
                      subtitle: const Text('Automatically backup data locally'),
                      value: _autoBackupEnabled,
                      onChanged: (v) => setState(() => _autoBackupEnabled = v),
                      activeColor: const Color(0xFF2E7D32),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.delete_forever, color: Colors.red),
                      title: const Text('Clear All Data', style: TextStyle(color: Colors.red)),
                      subtitle: const Text('Delete all farm records permanently'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _clearAllData,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ============================================
            // APP INFO
            // ============================================
            Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    const Text(
                      'Agro Ledger',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Version ${AppConstants.appVersion}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Farm Management Simplified',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.check_circle, size: 14, color: Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text(
                            'All data stored locally',
                            style: TextStyle(fontSize: 11, color: Colors.green.shade700),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  // ============================================
  // HELPER WIDGETS
  // ============================================

  Widget _buildSectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2E7D32)),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Color(0xFF2E7D32),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required String value,
    IconData? icon,
    required Function(String) onChanged,
    TextInputType? keyboardType,
    String? suffix,
  }) {
    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13)),
        ),
        Expanded(
          flex: 2,
          child: TextFormField(
            initialValue: value,
            keyboardType: keyboardType,
            decoration: InputDecoration(
              prefixIcon: Icon(icon, size: 18, color: Colors.grey),
              suffixText: suffix,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              isDense: true,
            ),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}