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
    final bytes = utf8.encode(pin);
    return base64.encode(bytes);
  }
  
  static bool verifyPin(String inputPin, String storedHash) {
    return hashPin(inputPin) == storedHash;
  }
  
  /// Find the main crop from a list of crops
  static Map<String, dynamic>? findMainCrop(List<Map<String, dynamic>> crops) {
    // First try to find crop with type 'main'
    for (var crop in crops) {
      if (crop['crop_type'] == 'main') {
        return crop;
      }
    }
    // If no main crop found, return first crop
    return crops.isNotEmpty ? crops.first : null;
  }
}