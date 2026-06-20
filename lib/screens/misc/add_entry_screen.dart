// lib/screens/add_entry_screen.dart
import 'package:agro_ledger/screens/misc/add_maintenance_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'add_harvest_screen.dart';

class AddEntryScreen extends StatelessWidget {
  const AddEntryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Add Record'),
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Harvest Option
              _buildOptionCard(
                context,
                icon: Icons.agriculture,
                title: 'Add Harvest',
                subtitle: 'Record today\'s harvest with workers',
                color: const Color(0xFF2E7D32),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const AddHarvestScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Maintenance Option (Future)
              _buildOptionCard(
  context,
  icon: Icons.build,
  title: 'Add Maintenance',
  subtitle: 'Daily wage or contract work',
  color: const Color(0xFF1565C0),
  onTap: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const AddMaintenanceScreen(),
      ),
    );
  },
),
              const SizedBox(height: 16),
              
              // Other Option (Future)
              _buildOptionCard(
                context,
                icon: Icons.add_circle_outline,
                title: 'Add Other',
                subtitle: 'Record expenses or other activities',
                color: const Color(0xFFF57C00),
                onTap: () {
                  // Future implementation
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Other feature coming soon!'),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey.shade400),
            ],
          ),
        ),
      ),
    );
  }
}