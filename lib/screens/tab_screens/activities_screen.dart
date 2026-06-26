// lib/screens/tab_screens/harvest_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:agro_ledger/services/local_storage_service.dart';
import 'package:agro_ledger/utils/helpers.dart';
import 'package:agro_ledger/widgets/pending_payments_sheet.dart';

class ActivitiesScreen extends ConsumerStatefulWidget {
  const ActivitiesScreen({super.key});

  @override
  ConsumerState<ActivitiesScreen> createState() => _ActivitiesScreenState();
}

class _ActivitiesScreenState extends ConsumerState<ActivitiesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _harvests = [];
  List<Map<String, dynamic>> _crops = [];
  List<Map<String, dynamic>> _workers = [];
  Map<String, dynamic>? _farmSettings;
  bool _showAddForm = false;

  final _dateController = TextEditingController();
  final _quantityController = TextEditingController();
  String _selectedCropId = '';
  String _selectedWorkerId = '';
  String _harvesterType = 'hired';
  String _paymentMethod = 'per_kg';
  double _ratePerKg = 10.0;
  double _dailyWage = 1000.0;
  double _transportCost = 0;

  @override
  void initState() {
    super.initState();
    _dateController.text = DateTime.now().toIso8601String().substring(0, 10);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final localStorage = await LocalStorageService.getInstance();
      
      // Load harvests
      _harvests = await localStorage.query('harvests', orderBy: 'date DESC');
      
      // Load crops
      _crops = await localStorage.query('crops');//, where: 'is_active = 1', whereArgs: [1]);
      
      // Load workers
      _workers = await localStorage.query('workers');//, where: 'is_active = 1', whereArgs: [1]);
      
      // Load farm settings
      _farmSettings = await localStorage.getFarmSettings();
      _paymentMethod = _farmSettings?['default_payment_method'] ?? 'per_kg';
      _ratePerKg = (_farmSettings?['default_per_kg_rate'] as num?)?.toDouble() ?? 10.0;
      _dailyWage = (_farmSettings?['default_daily_wage'] as num?)?.toDouble() ?? 1000.0;
      _transportCost = (_farmSettings?['default_transport_cost'] as num?)?.toDouble() ?? 100.0;
      
      
    } catch (e) {
      debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

    Future<void> _saveHarvest() async {
    if (_selectedCropId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a crop')),
      );
      return;
    }
    
    if (_quantityController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter quantity')),
      );
      return;
    }

    final quantity = double.parse(_quantityController.text);
    double earnings = 0;

    if (_harvesterType == 'hired') {
      if (_paymentMethod == 'per_kg') {
        earnings = quantity * _ratePerKg;
      } else {
        earnings = _dailyWage;
      }
    }

    try {
      final localStorage = await LocalStorageService.getInstance();
      
      // Get farm_id
      final farms = await localStorage.getAllFarms();
      String farmId = '';
      if (farms.isNotEmpty) {
        farmId = farms.first['farm_id'];
      }
      
      // Create harvest
      final harvestId = Helpers.generateId();
      await localStorage.insertHarvest({
        'harvest_id': harvestId,
        'farm_id': farmId,
        'crop_id': _selectedCropId,
        'date': _dateController.text,
        'quantity': quantity,
        'unit': 'kg',
        'harvester_type': _harvesterType,
        'notes': '',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });

      // Add harvest worker
      if (_harvesterType == 'hired' && _selectedWorkerId.isNotEmpty) {
        await localStorage.insertHarvestWorker({
          'id': Helpers.generateId(),
          'harvest_id': harvestId,
          'worker_id': _selectedWorkerId,
          'quantity_harvested': quantity,
          'earnings': earnings,
          'payment_method': _paymentMethod,
          'rate': _paymentMethod == 'per_kg' ? _ratePerKg : _dailyWage,
          'transport_cost': _transportCost,
          'is_paid': 0,
          'created_at': DateTime.now().toIso8601String(),
          'updated_at': DateTime.now().toIso8601String(),
        });
      }

      _quantityController.clear();
      _selectedCropId = '';
      _selectedWorkerId = '';
      setState(() => _showAddForm = false);
      await _loadData();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Harvest saved!'), backgroundColor: Colors.green),
      );
      
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
      );
    }
  }

  String _getCropName(String? cropId) {
    if (cropId == null) return 'Unknown';
    final crop = _crops.firstWhere(
      (c) => c['crop_id'] == cropId,
      orElse: () => {'name': 'Unknown'},
    );
    return crop['name'];
  }

  String _getWorkerName(String? workerId) {
    if (workerId == null) return '';
    final worker = _workers.firstWhere(
      (w) => w['worker_id'] == workerId,
      orElse: () => {'name': 'Unknown'},
    );
    return worker['name'];
  }

  String _getHarvesterTypeLabel(String? type) {
    switch (type) {
      case 'owner': return 'Owner';
      case 'family': return 'Family';
      case 'unpaid': return 'Unpaid';
      default: return 'Hired';
    }
  }  

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Column(
        children: [

          // Harvest List
          Expanded(
            child: _harvests.isEmpty
                ? EmptyHarvestState(
                    onPressed: () => setState(() => _showAddForm = true),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _harvests.length,
                    itemBuilder: (context, index) {
                      final h = _harvests[index];
                      final isHired = h['harvester_type'] == 'hired';
                      
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ExpansionTile(
                          leading: CircleAvatar(
                            backgroundColor: isHired 
                                ? Colors.green.shade100 
                                : Colors.orange.shade100,
                            child: Icon(
                              isHired ? Icons.person : Icons.person_outline,
                              color: isHired ? Colors.green.shade700 : Colors.orange.shade700,
                              size: 20,
                            ),
                          ),
                          title: Text(
                            _getCropName(h['crop_id']),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          subtitle: Text(
                            '${h['quantity']} kg • ${_formatDate(h['date'])}',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (h['harvester_type'] == 'hired')
                                Text(
                                  _getHarvesterTypeLabel(h['harvester_type']),
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.green.shade700,
                                  ),
                                ),
                              const SizedBox(width: 8),
                              Icon(
                                isHired ? Icons.arrow_forward_ios : Icons.arrow_forward_ios,
                                size: 14,
                                color: Colors.grey.shade400,
                              ),
                            ],
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Harvest Details
                                  _buildDetailRow('Date', _formatDate(h['date'])),
                                  _buildDetailRow('Crop', _getCropName(h['crop_id'])),
                                  _buildDetailRow('Quantity', '${h['quantity']} kg'),
                                  if (h['quality_grade'] != null && h['quality_grade']!.isNotEmpty)
                                    _buildDetailRow('Quality', h['quality_grade']),
                                  _buildDetailRow('Harvester', _getHarvesterTypeLabel(h['harvester_type'])),
                                  if (isHired) ...[
                                    const Divider(),
                                    const Text(
                                      'Workers',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w500,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    _buildWorkersList(h['harvest_id']),
                                  ],
                                  if (h['notes'] != null && h['notes']!.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 8),
                                      child: Text(
                                        'Notes: ${h['notes']}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                          fontStyle: FontStyle.italic,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      );
  }

  // ============================================
  // HELPER WIDGETS
  // ============================================

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey.shade700,
              fontSize: 13,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkersList(String harvestId) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _getHarvestWorkers(harvestId),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Text(
            'No workers recorded',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          );
        }
        return Column(
          children: snapshot.data!.map((worker) {
            final isPaid = (worker['is_paid'] ?? 0) == 1;
            return Container(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    isPaid ? Icons.check_circle : Icons.pending,
                    size: 16,
                    color: isPaid ? Colors.green : Colors.orange,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _getWorkerName(worker['worker_id']),
                      style: const TextStyle(fontSize: 13),
                    ),
                  ),
                  Text(
                    '${worker['quantity_harvested']} kg',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    // Helpers.formatCurrency((worker['earnings'] ?? 0)),
                    'Rs. ${worker['earnings'] ?? 0}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isPaid ? Colors.green : Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _getHarvestWorkers(String harvestId) async {
    try {
      final localStorage = await LocalStorageService.getInstance();
      return await localStorage.getHarvestWorkersByHarvest(harvestId);
    } catch (e) {
      return [];
    }
  }

  String _formatDate(String? date) {
    if (date == null) return '';
    return Helpers.formatDisplayDate(date);
  }
}

// ============================================
// EMPTY STATE
// ============================================

class EmptyHarvestState extends StatelessWidget {
  final VoidCallback onPressed;

  const EmptyHarvestState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                borderRadius: BorderRadius.circular(40),
              ),
              child: Icon(
                Icons.agriculture,
                size: 40,
                color: Colors.green.shade700,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No Harvest Records',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            const Text(
              'Add your first harvest to start tracking your farm production.',
              style: TextStyle(color: Colors.grey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: const Icon(Icons.add),
              label: const Text('Add Harvest'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}