// lib/widgets/pending_payments_sheet.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/local_storage_service.dart';
import '../utils/helpers.dart';

class PendingPaymentsSheet extends ConsumerStatefulWidget {
  const PendingPaymentsSheet({super.key});

  @override
  ConsumerState<PendingPaymentsSheet> createState() => _PendingPaymentsSheetState();
}

class _PendingPaymentsSheetState extends ConsumerState<PendingPaymentsSheet> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _pendingPayments = [];
  double _totalPending = 0;
  String _farmId = '';
  String _selectedDate = '';

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now().toIso8601String().substring(0, 10);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final localStorage = await LocalStorageService.getInstance();
      
      final farms = await localStorage.getAllFarms();
      if (farms.isNotEmpty) {
        _farmId = farms.first['farm_id'];
      }
      
      // Get today's harvest workers with pending payments
      final harvests = await localStorage.query(
        'harvests',
        where: 'farm_id = ? AND date = ?',
        whereArgs: [_farmId, _selectedDate],
      );
      
      _pendingPayments = [];
      _totalPending = 0;
      
      for (var harvest in harvests) {
        final workers = await localStorage.getHarvestWorkersByHarvest(harvest['harvest_id']);
        for (var worker in workers) {
          // Get worker name
          final workerName = await _getWorkerName(worker['worker_id']);
          final isPaid = worker['is_paid'] == 1;
          
          if (!isPaid && (worker['earnings'] ?? 0) > 0) {
            _pendingPayments.add({
              'id': worker['id'],
              'harvest_id': harvest['harvest_id'],
              'worker_id': worker['worker_id'],
              'worker_name': workerName,
              'quantity': worker['quantity_harvested'] ?? 0,
              'earnings': worker['earnings'] ?? 0,
              'payment_method': worker['payment_method'] ?? 'per_kg',
              'is_paid': 0,
            });
            _totalPending += (worker['earnings'] ?? 0);
          }
        }
      }
      
      // Sort by worker name
      _pendingPayments.sort((a, b) => (a['worker_name'] as String).compareTo(b['worker_name'] as String));
      
    } catch (e) {
      debugPrint('Error loading pending payments: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<String> _getWorkerName(String workerId) async {
    try {
      final localStorage = await LocalStorageService.getInstance();
      final worker = await localStorage.getWorker(workerId);
      if (worker != null) {
        return worker['name'] ?? worker['nick_name'] ?? 'Unknown';
      }
    } catch (e) {
      debugPrint('Error getting worker name: $e');
    }
    return 'Unknown';
  }

  Future<void> _markAsPaid(String paymentId) async {
    setState(() => _isLoading = true);
    try {
      final localStorage = await LocalStorageService.getInstance();
      
      // Update harvest_workers table to mark as paid
      await localStorage.updateHarvestWorker(paymentId, {
        'is_paid': 1,
        'paid_date': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // Find the payment data
      final payment = _pendingPayments.firstWhere((p) => p['id'] == paymentId);
      
      // Also record in payments table
      await localStorage.insertPayment({
        'payment_id': Helpers.generateId(),
        'sale_id': payment['harvest_id'], // Using harvest_id as reference
        'amount': payment['earnings'],
        'payment_date': DateTime.now().toIso8601String(),
        'payment_method': 'cash',
        'notes': 'Worker payment for harvest - ${payment['worker_name']}',
        'created_at': DateTime.now().toIso8601String(),
        'updated_at': DateTime.now().toIso8601String(),
      });
      
      // Remove from pending list
      setState(() {
        _pendingPayments.removeWhere((p) => p['id'] == paymentId);
        _totalPending = _pendingPayments.fold(0, (sum, p) => sum + (p['earnings'] as double));
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('✅ Payment marked as paid!'),
            backgroundColor: Colors.green,
          ),
        );
      }
      
    } catch (e) {
      debugPrint('Error marking payment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _markAllAsPaid() async {
    if (_pendingPayments.isEmpty) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Pay All Workers'),
        content: Text(
          'Mark all ${_pendingPayments.length} workers as paid?\n'
          'Total amount: Rs. ${_totalPending.toStringAsFixed(0)}'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              setState(() => _isLoading = true);
              try {
                final List<String> paymentIds = _pendingPayments.map((p) => p['id'] as String).toList();
                for (var paymentId in paymentIds) {
                  await _markAsPaid(paymentId);
                }
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ All payments marked as paid!'),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } catch (e) {
                debugPrint('Error marking all paid: $e');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
                  );
                }
              } finally {
                if (mounted) {
                  setState(() => _isLoading = false);
                }
              }
            },
            child: const Text('Pay All', style: TextStyle(color: Colors.green)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Pending Payments',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              
              // Date & Summary
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '📅 ${_formatDisplayDate(_selectedDate)}',
                          style: const TextStyle(fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_pendingPayments.length} workers pending',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text(
                          'Total Pending',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        Text(
                          'Rs. ${_totalPending.toStringAsFixed(0)}',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: _totalPending > 0 ? Colors.red.shade700 : Colors.green,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              
              // Mark All Paid Button
              if (_pendingPayments.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _markAllAsPaid,
                      icon: const Icon(Icons.payments),
                      label: Text('Pay All (Rs. ${_totalPending.toStringAsFixed(0)})'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    ),
                  ),
                ),
              
              // Payment List
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _pendingPayments.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  size: 64,
                                  color: Colors.green.shade400,
                                ),
                                const SizedBox(height: 16),
                                const Text(
                                  'No pending payments today!',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'All workers have been paid ✅',
                                  style: TextStyle(color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _pendingPayments.length,
                            itemBuilder: (context, index) {
                              final payment = _pendingPayments[index];
                              return _buildPaymentCard(payment);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPaymentCard(Map<String, dynamic> payment) {
    final isContract = payment['payment_method'] == 'contract';
    final workerName = payment['worker_name'] ?? 'Unknown';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 5,
          ),
        ],
      ),
      child: Row(
        children: [
          // Worker Avatar
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFF2E7D32).withOpacity(0.1),
            child: Text(
              workerName.isNotEmpty ? workerName.substring(0, 1).toUpperCase() : '?',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2E7D32),
              ),
            ),
          ),
          const SizedBox(width: 12),
          
          // Worker Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  workerName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text(
                      isContract 
                          ? 'Contract' 
                          : '${payment['quantity']} kg',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        payment['payment_method'] ?? 'per_kg',
                        style: TextStyle(
                          fontSize: 9,
                          color: Colors.green.shade700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          // Amount & Pay Button
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs. ${(payment['earnings'] as double).toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFF57C00),
                ),
              ),
              const SizedBox(height: 4),
              ElevatedButton(
                onPressed: _isLoading ? null : () => _markAsPaid(payment['id']),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  minimumSize: const Size(60, 28),
                ),
                child: const Text(
                  'Pay Now',
                  style: TextStyle(fontSize: 11),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDisplayDate(String date) {
    if (date.isEmpty) return '';
    final parts = date.split('-');
    if (parts.length == 3) {
      const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
      final month = months[int.parse(parts[1]) - 1];
      return '$month ${int.parse(parts[2])}, ${parts[0]}';
    }
    return date;
  }
}