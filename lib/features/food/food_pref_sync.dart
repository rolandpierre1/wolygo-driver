import 'package:get/get.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';

/// Mémorise le choix « Livraison Repas » fait à l'inscription, puis l'envoie
/// au serveur dès que le chauffeur est connecté (après l'approbation de son compte).
class FoodPrefSync {
  static const _key = 'pending_food_pref';

  static Future<void> setPending(bool on) async {
    try {
      final p = await SharedPreferences.getInstance();
      await p.setString(_key, on ? '1' : '0');
    } catch (_) {}
  }

  static Future<void> run() async {
    try {
      final p = await SharedPreferences.getInstance();
      final v = p.getString(_key);
      if (v == null) return;
      final r = await Get.find<ApiClient>().postData('/api/driver/food/settings', {'enabled': v == '1' ? 1 : 0});
      if (r.statusCode == 200) await p.remove(_key);
    } catch (_) {}
  }
}
