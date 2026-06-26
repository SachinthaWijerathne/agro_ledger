import 'package:agro_ledger/screens/misc/settings_screen.dart';
import 'package:agro_ledger/screens/tab_screens/activities_screen.dart';
import 'package:agro_ledger/services/local_storage_service.dart';
import 'package:agro_ledger/utils/constants.dart';
import 'package:agro_ledger/widgets/pending_payments_sheet.dart';
import 'package:flutter/material.dart';
import 'package:agro_ledger/screens/tab_screens/home_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  _MainTabScreenState createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex=0;
  bool _isLoading = true;
  int _pendingCount = 0;

  late List<Widget> _screens;

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final localStorage = await LocalStorageService.getInstance();
      
      // Load harvests
       await localStorage.query('harvests', orderBy: 'date DESC');
      
      // Load crops
      await localStorage.query('crops');//, where: 'is_active = 1', whereArgs: [1]);
      
      // Load workers
       await localStorage.query('workers');//, where: 'is_active = 1', whereArgs: [1]);
      
      // Load farm settings
       await localStorage.getFarmSettings();

      // Count pending payments
       await _countPendingPayments(localStorage);
      
    } catch (e) {
      debugPrint('Error loading data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading data: $e'), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _countPendingPayments(LocalStorageService localStorage) async {
    try {
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final farms = await localStorage.getAllFarms();
      if (farms.isNotEmpty) {
        final farmId = farms.first['farm_id'];
        final harvests = await localStorage.query(
          'harvests',
          where: 'farm_id = ? AND date = ?',
          whereArgs: [farmId, today],
        );
        
        _pendingCount = 0;
        for (var harvest in harvests) {
          final workers = await localStorage.getHarvestWorkersByHarvest(harvest['harvest_id']);
          for (var worker in workers) {
            if ((worker['is_paid'] ?? 0) == 0 && (worker['earnings'] ?? 0) > 0) {
              _pendingCount++;
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error counting pending: $e');
    }
  }

  void _showPendingPayments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => const PendingPaymentsSheet(),
    ).then((_) => _loadData()); // Refresh on close
  }

  @override
  void initState(){
    super.initState();
    _loadData();
    _screens = [
      const HomeScreen(),
      const ActivitiesScreen(),
      Center(child: Text('Profile Screen')),
      Center(child: Text('Inventory Screen')),
      Center(child: Text('Reports Screen')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Agro Ledger'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.settings),
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const SettingsScreen()),
            );
          },
        ),
        actions: [          
          IconButton(
            icon: Badge.count(count: _pendingCount, child: Icon(Icons.payments)),
            onPressed: _showPendingPayments,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        selectedItemColor: const Color(0xFF2E7D32),
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home_outlined), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.agriculture_outlined), label: 'Activities'),
          BottomNavigationBarItem(icon: Icon(Icons.sell_outlined), label: 'Sales'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
        ],
      ),
    );
  }
}