import 'package:agro_ledger/screens/misc/settings_screen.dart';
import 'package:agro_ledger/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:agro_ledger/screens/tab_screens/home_screen.dart';

class MainTabScreen extends StatefulWidget {
  const MainTabScreen({super.key});

  @override
  _MainTabScreenState createState() => _MainTabScreenState();
}

class _MainTabScreenState extends State<MainTabScreen> {
  int _currentIndex=0;
  late List<Widget> _screens;

  @override
  void initState(){
    super.initState();
    _screens = [
      const HomeScreen(),
      Center(child: Text('Transactions Screen')),
      Center(child: Text('Profile Screen')),
      Center(child: Text('Inventory Screen')),
      Center(child: Text('Reports Screen')),
    ];
  }

  Future<void> _logout() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // await PinService().clearPin();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppConstants.routeSplash,
                  (route) => false,
                );
              }
            },
            child: const Text('Logout', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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
            icon: const Icon(Icons.logout),
            onPressed: _logout,
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
          BottomNavigationBarItem(icon: Icon(Icons.agriculture_outlined), label: 'Harvest'),
          BottomNavigationBarItem(icon: Icon(Icons.sell_outlined), label: 'Sales'),
          BottomNavigationBarItem(icon: Icon(Icons.inventory_2_outlined), label: 'Stock'),
          BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), label: 'Reports'),
        ],
      ),
    );
  }
}