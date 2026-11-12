import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Interrupteur « Accepter les livraisons Magasin » (menu du profil).
class ShopPrefTile extends StatefulWidget {
  const ShopPrefTile({super.key});

  @override
  State<ShopPrefTile> createState() => _ShopPrefTileState();
}

class _ShopPrefTileState extends State<ShopPrefTile> {
  bool _on = false;
  bool _busy = true;

  ApiClient get _api => Get.find<ApiClient>();

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await _api.getData('/api/driver/shop/settings');
      if (r.statusCode == 200 && r.body is Map) _on = r.body['enabled'] == true;
    } catch (_) {}
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _set(bool v) async {
    setState(() {
      _on = v;
      _busy = true;
    });
    bool ok = false;
    try {
      final r = await _api.postData('/api/driver/shop/settings', {'enabled': v ? 1 : 0});
      ok = r.statusCode == 200;
    } catch (_) {}
    if (!ok) {
      _on = !v;
      showCustomSnackBar('Impossible de changer ce réglage.');
    } else {
      showCustomSnackBar(v ? 'Tu recevras les livraisons Magasin' : 'Livraisons Magasin désactivées', isError: false);
    }
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).colorScheme.outline;
    return SwitchListTile(
      value: _on,
      onChanged: _busy ? null : _set,
      activeColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
      title: Text('Accepter les livraisons Magasin', style: TextStyle(color: c, fontWeight: FontWeight.w600, fontSize: 16)),
      subtitle: Text('Reçois les commandes de magasins quand tu es en ligne.', style: TextStyle(color: c.withOpacity(.8), fontSize: 12.5)),
    );
  }
}
