// lib/utils/helpers.dart
import 'dart:math';
import 'dart:convert';

class Helpers {  
  static String generateId() {
    return DateTime.now().millisecondsSinceEpoch.toString() + 
           Random().nextInt(10000).toString();
  }
  
  static String formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
  
  static String formatDisplayDate(String date) {
    if (date.isEmpty) return '';
    if (date.length >= 10) {
      final parts = date.substring(0, 10).split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      }
    }
    return date;
  }
  
  static String getCurrentDate() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  static String hashPin(String pin) {
    // Simple hash for demo - in production use proper crypto
    final bytes = utf8.encode(pin);
    return base64.encode(bytes);
  }
  
  static bool verifyPin(String inputPin, String storedHash) {
    return hashPin(inputPin) == storedHash;
  }
}