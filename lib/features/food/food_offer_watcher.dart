import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/food/screens/food_deliveries_screen.dart';

/// Surveille les nouvelles commandes Repas payées et ouvre une fenêtre
/// « Nouvelle livraison Repas » chez le chauffeur (comme une demande de course).
/// Ne fait rien si le chauffeur n'a pas activé « Accepter les livraisons Repas ».
class FoodOfferWatcher {
  static Timer? _timer;
  static final Set<int> _seen = {};
  static bool _showing = false;

  static void start() {
    _timer?.cancel();
    _check();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => _check());
  }

  static void stop() {
    _timer?.cancel();
    _timer = null;
  }

  static Future<void> _check() async {
    if (_showing || !Get.isRegistered<ApiClient>()) return;
    try {
      final api = Get.find<ApiClient>();
      final cur = await api.getData('/api/driver/food/current');
      if (cur.statusCode == 200 && cur.body is Map && cur.body['order'] != null) return;
      final r = await api.getData('/api/driver/food/offers');
      if (r.statusCode != 200 || r.body is! Map || r.body['enabled'] != true) return;
      final offers = (r.body['offers'] as List?) ?? [];
      final fresh = offers.where((o) => o is Map && !_seen.contains(o['id'])).toList();
      if (fresh.isEmpty) return;
      for (final o in fresh) {
        _seen.add(o['id'] as int);
      }
      final o = Map<String, dynamic>.from(fresh.first as Map);
      _showing = true;
      try {
        HapticFeedback.heavyImpact();
        SystemSound.play(SystemSoundType.alert);
      } catch (_) {}
      final go = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Nouvelle livraison Repas'),
          content: Text('${o['restaurant'] ?? ''}\nGain : ${((o['earning'] ?? 0) as num).toStringAsFixed(2)} \$\nRécupérer : ${o['restaurant_address'] ?? ''}\nLivrer : ${o['delivery_address'] ?? ''}'),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Plus tard')),
            ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Voir et accepter')),
          ],
        ),
        barrierDismissible: false,
      );
      _showing = false;
      if (go == true) Get.to(() => const FoodDeliveriesScreen());
    } catch (_) {
      _showing = false;
    }
  }
}
