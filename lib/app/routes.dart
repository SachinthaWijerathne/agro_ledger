import 'package:agro_ledger/screens/auth_screens/onboarding_screen.dart';
import 'package:agro_ledger/screens/auth_screens/signin_screen.dart';
import 'package:agro_ledger/screens/auth_screens/signup_screen.dart';
import 'package:agro_ledger/screens/auth_screens/splash_screen.dart';
import 'package:agro_ledger/screens/tab_screens/main_tab_screen.dart';
import 'package:flutter/material.dart';
import 'package:agro_ledger/utils/constants.dart';

class AppRoutes {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppConstants.routeSplash:
        return _buildPageRoute(const SplashScreen(), settings);
      case AppConstants.routeLogin:
        return _buildPageRoute(const LoginScreen(), settings);
      case AppConstants.routeSignup:
        return _buildPageRoute(const SignupScreen(), settings); 
      // case AppConstants.routePinSetup:
      //   return _buildPageRoute(const PinSetupScreen(), settings);
      // case AppConstants.routePinLogin:
      //   return _buildPageRoute(const PinLoginScreen(), settings);
      case AppConstants.routeOnboarding:
        return _buildPageRoute(const OnboardingScreen(), settings);
      case AppConstants.routeHome:
        return _buildPageRoute(const MainTabScreen(), settings);
      default:
        return _buildPageRoute(
          const Scaffold(body: Center(child: Text('Route not found'))),
          settings,
        );
    }
  }

  static PageRouteBuilder _buildPageRoute(Widget page, RouteSettings settings) {
    return PageRouteBuilder(
      settings: settings,
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeInOut;
        var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
        var offsetAnimation = animation.drive(tween);
        return SlideTransition(position: offsetAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  static void push(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushNamed(routeName, arguments: arguments);
  }

  static void pushReplacement(String routeName, {Object? arguments}) {
    navigatorKey.currentState?.pushReplacementNamed(routeName, arguments: arguments);
  }

  static void pop() {
    navigatorKey.currentState?.pop();
  }
}