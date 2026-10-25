import 'package:flutter/material.dart';

/// Couleurs de véhicule proposées au chauffeur.
/// La clé est enregistrée sur le serveur; le nom affiché vient de la traduction `color_<clé>`.
class VehicleColors {
  static const Map<String, Color> all = {
    'black': Color(0xFF111111),
    'white': Color(0xFFFFFFFF),
    'gray': Color(0xFF808080),
    'silver': Color(0xFFC0C0C0),
    'red': Color(0xFFD32F2F),
    'blue': Color(0xFF1976D2),
    'green': Color(0xFF388E3C),
    'yellow': Color(0xFFFBC02D),
    'orange': Color(0xFFF57C00),
    'brown': Color(0xFF6D4C41),
    'beige': Color(0xFFD7C4A3),
    'gold': Color(0xFFC9A227),
    'purple': Color(0xFF7B1FA2),
    'pink': Color(0xFFE91E63),
  };

  static Color of(String? key) => all[key] ?? Colors.grey;
}
