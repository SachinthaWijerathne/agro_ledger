// lib/auth/splash_screen.dart
import 'package:agro_ledger/services/local_storage_service.dart';
import 'package:agro_ledger/utils/constants.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAppState();
  }

  Future<void> _checkAppState() async {
    await Future.delayed(const Duration(milliseconds: 2500));

    try {
      final localStorage = await LocalStorageService.getInstance();

      // 1. Check if user profile exists
      final users = await localStorage.getAllUserProfiles();

      if (users.isEmpty) {
        // No user → Go to SignUp
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppConstants.routeSignup);
        }
        return;
      }

      // 2. Check if user has a farm
      final farms = await localStorage.getAllFarms();

      if (farms.isEmpty) {
        // No farm → Go to Onboarding
        if (mounted) {
          Navigator.pushReplacementNamed(context, AppConstants.routeOnboarding);
        }
        return;
      }

      // 3. User and farm exist → Go directly to Home
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.routeHome);
      }
    } catch (e) {
      debugPrint('❌ Splash error: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppConstants.routeSignup);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1B5E20), Color(0xFF2E7D32), Color(0xFF4CAF50)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(60),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.2),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(60),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/logo/logo.png',
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 32),
              const Text(
                'AGRO LEDGER',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Farm Management Simplified',
                style: TextStyle(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 48),
              const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              const SizedBox(height: 16),
              const Text('Loading...', style: TextStyle(color: Colors.white70)),
            ],
          ),
        ),
      ),
    );
  }
}
