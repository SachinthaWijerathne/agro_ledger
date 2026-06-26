// lib/screens/tab_screens/home_screen.dart
import 'package:agro_ledger/screens/misc/add_entry_screen.dart';
import 'package:agro_ledger/services/local_storage_service.dart';
import 'package:agro_ledger/widgets/empty_state_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../utils/helpers.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _farmData;
  Map<String, dynamic>? _userData;
  List<Map<String, dynamic>> _recentHarvests = [];
  List<Map<String, dynamic>> _lowStockItems = [];
  List<Map<String, dynamic>> _pendingSales = [];

  double _todayHarvest = 0;
  double _totalPendingPayments = 0;
  double _totalStockValue = 0;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final localStorage = await LocalStorageService.getInstance();

      // Get farm data
      final farms = await localStorage.getAllFarms();
      if (farms.isNotEmpty) {
        _farmData = farms.first;

        // Get user data
        final user = await localStorage.getUserProfile(_farmData!['user_id']);
        _userData = user;

        // Get today's harvest
        final today = DateTime.now().toIso8601String().substring(0, 10);
        final harvests = await localStorage.query(
          'harvests',
          where: 'farm_id = ? AND date = ?',
          whereArgs: [_farmData!['farm_id'], today],
        );
        _todayHarvest = harvests.fold(
          0,
          (sum, h) => sum + ((h['quantity'] as num?)?.toDouble() ?? 0),
        );
        _recentHarvests = await localStorage.query(
          'harvests',
          where: 'farm_id = ?',
          whereArgs: [_farmData!['farm_id']],
          orderBy: 'date DESC',
          limit: 5,
        );

        // Get pending payments
        _pendingSales = await localStorage.query(
          'sales',
          where: 'farm_id = ? AND payment_status != ?',
          whereArgs: [_farmData!['farm_id'], 'paid'],
        );
        _totalPendingPayments = _pendingSales.fold(
          0,
          (sum, s) => sum + ((s['total_amount'] as num?)?.toDouble() ?? 0),
        );

        // Get low stock items
        _lowStockItems = await localStorage.getLowStockItems(
          _farmData!['farm_id'],
        );

        // Calculate inventory value (simplified)
        final inventory = await localStorage.getInventoryByFarm(
          _farmData!['farm_id'],
        );
        _totalStockValue = inventory.fold(
          0,
          (sum, item) =>
              sum +
              ((item['quantity'] as num?)?.toDouble() ?? 0) *
                  100, // Simplified value
        );
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<String> _getCropName(String? cropId) async {
    if (cropId == null) return 'Unknown';
    final localStorage = await LocalStorageService.getInstance();
    final crop = await localStorage.getCrop(cropId);
    return crop?['name'] ?? 'Unknown';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final hasData =
        _todayHarvest > 0 ||
        _totalPendingPayments > 0 ||
        _recentHarvests.isNotEmpty ||
        _lowStockItems.isNotEmpty;

    if (!hasData) {
      return Scaffold(
        body: EmptyStateWidget(
          title: 'Welcome ${_userData?['name'] ?? 'Farmer'}',
          message:
              'Start by adding your first harvest or sale to see insights here.',
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const AddEntryScreen()),
            );
          },
          backgroundColor: const Color(0xFF2E7D32),
          foregroundColor: Colors.white,
          icon: const Icon(Icons.add),
          label: const Text('Add'),
          elevation: 6,
        ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: RefreshIndicator(
        onRefresh: _loadData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // User Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hello, ${_userData?['name'] ?? 'Farmer'}',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _farmData?['name'] ?? 'My Farm',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 14,
                          color: Colors.green.shade700,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          Helpers.formatDisplayDate(
                            DateTime.now().toIso8601String().substring(0, 10),
                          ),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Summary Cards
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Today\'s Harvest',
                      value: '${_todayHarvest.toStringAsFixed(1)} kg',
                      icon: Icons.agriculture,
                      color: const Color(0xFF2E7D32),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Pending Payments',
                      value: 'Rs${_totalPendingPayments.toStringAsFixed(0)}',
                      icon: Icons.payment,
                      color: _totalPendingPayments > 0
                          ? Colors.red
                          : Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Low Stock Items',
                      value: _lowStockItems.length.toString(),
                      icon: Icons.warning_amber,
                      color: _lowStockItems.isNotEmpty
                          ? Colors.orange
                          : Colors.green,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildSummaryCard(
                      title: 'Total Value',
                      value: 'Rs${_totalStockValue.toStringAsFixed(0)}',
                      icon: Icons.attach_money,
                      color: const Color(0xFF1565C0),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Low Stock Alerts
              if (_lowStockItems.isNotEmpty) ...[
                const Text(
                  '⚠️ Low Stock Alerts',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._lowStockItems.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildAlertCard(
                      title: item['name'],
                      message:
                          '${item['quantity']} ${item['unit']} left (Min: ${item['min_stock_alert']})',
                      icon: Icons.warning_amber,
                      color: Colors.orange,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Pending Payments
              if (_pendingSales.isNotEmpty) ...[
                const Text(
                  '💰 Pending Payments',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                ..._pendingSales.map(
                  (sale) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _buildAlertCard(
                      title: sale['dealer_name'] ?? 'Dealer',
                      message:
                          'Rs${(sale['total_amount'] as num?)?.toDouble() ?? 0} due',
                      icon: Icons.payment,
                      color: Colors.red,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Recent Harvests
              if (_recentHarvests.isNotEmpty) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      '📋 Recent Harvests',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(onPressed: () {}, child: const Text('View All')),
                  ],
                ),
                const SizedBox(height: 8),
                ..._recentHarvests.map((h) => _buildHarvestCard(h)),
              ],
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const AddEntryScreen()),
          );
        },
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Add'),
        elevation: 6,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(title, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildAlertCard({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Text(message, style: TextStyle(fontSize: 12, color: color)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHarvestCard(Map<String, dynamic> harvest) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 5),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF2E7D32),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${harvest['quantity']} ${harvest['unit'] ?? 'kg'}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                Text(
                  '${harvest['date']?.substring(0, 10) ?? ''}',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: harvest['harvester_type'] == 'owner'
                  ? Colors.orange.shade100
                  : Colors.green.shade100,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              harvest['harvester_type'] ?? 'hired',
              style: TextStyle(
                fontSize: 10,
                color: harvest['harvester_type'] == 'owner'
                    ? Colors.orange.shade700
                    : Colors.green.shade700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
