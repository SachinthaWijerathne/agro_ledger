// lib/widgets/empty_state_widget.dart
import 'package:flutter/material.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String message;
  final String buttonText;
  final VoidCallback onPressed;
  final IconData icon;
  final Color? iconColor;
  final Color? buttonColor;
  final double? iconSize;
  final Widget? customImage;

  const EmptyStateWidget({
    super.key,
    required this.title,
    required this.message,
    required this.buttonText,
    required this.onPressed,
    this.icon = Icons.add,
    this.iconColor,
    this.buttonColor,
    this.iconSize,
    this.customImage,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon or Custom Image
            if (customImage != null)
              customImage!
            else
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: (iconColor ?? Colors.grey.shade400).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  size: iconSize ?? 40,
                  color: iconColor ?? Colors.grey.shade400,
                ),
              ),
            const SizedBox(height: 24),

            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),

            // Action Button
            ElevatedButton.icon(
              onPressed: onPressed,
              icon: Icon(icon, size: 18),
              label: Text(buttonText),
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor ?? const Color(0xFF2E7D32),
                foregroundColor: Colors.white,
                minimumSize: const Size(200, 48),
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

// ============================================
// PRE-BUILT EMPTY STATE VARIANTS
// ============================================

class EmptyHarvestState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptyHarvestState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Harvest Records',
      message: 'Add your first harvest to start tracking your farm production.',
      buttonText: 'Add Harvest',
      icon: Icons.agriculture,
      onPressed: onPressed,
    );
  }
}

class EmptySalesState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptySalesState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Sales Records',
      message: 'Record your first sale to start tracking income.',
      buttonText: 'Add Sale',
      icon: Icons.sell,
      onPressed: onPressed,
    );
  }
}

class EmptyInventoryState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptyInventoryState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Inventory Items',
      message: 'Add fertilizers, pesticides, or tools to track your stock.',
      buttonText: 'Add Item',
      icon: Icons.inventory,
      onPressed: onPressed,
    );
  }
}

class EmptyWorkersState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptyWorkersState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Workers Added',
      message: 'Add workers to track labor and assign tasks.',
      buttonText: 'Add Worker',
      icon: Icons.people,
      onPressed: onPressed,
    );
  }
}

class EmptyReportsState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptyReportsState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Data Yet',
      message: 'Add harvests and sales to see financial reports.',
      buttonText: 'Add Harvest',
      icon: Icons.bar_chart,
      onPressed: onPressed,
    );
  }
}

class EmptyCropsState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptyCropsState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Crops Added',
      message: 'Add your crops to start tracking harvests and expenses.',
      buttonText: 'Add Crop',
      icon: Icons.grass,
      onPressed: onPressed,
    );
  }
}

class EmptyDealersState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptyDealersState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Dealers Added',
      message: 'Add dealers to record sales and track payments.',
      buttonText: 'Add Dealer',
      icon: Icons.store,
      onPressed: onPressed,
    );
  }
}

class EmptyToolsState extends StatelessWidget {
  final VoidCallback onPressed;
  const EmptyToolsState({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'No Tools Added',
      message: 'Add ladders, sprayers, or other equipment to your inventory.',
      buttonText: 'Add Tool',
      icon: Icons.handyman,
      onPressed: onPressed,
    );
  }
}

class EmptyDashboardState extends StatelessWidget {
  final VoidCallback onPressed;
  final String userName;
  const EmptyDashboardState({
    super.key, 
    required this.onPressed,
    this.userName = 'Farmer',
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      title: 'Welcome $userName!',
      message: 'Start by adding your first harvest to see insights here.',
      buttonText: 'Add Harvest',
      icon: Icons.agriculture,
      onPressed: onPressed,
    );
  }
}