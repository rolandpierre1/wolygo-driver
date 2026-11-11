import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/image_source_picker.dart';

/// Livraisons Repas: offres disponibles et livraison en cours.
class FoodDeliveriesScreen extends StatefulWidget {
  const FoodDeliveriesScreen({super.key});

  @override
  State<FoodDeliveriesScreen> createState() => _FoodDeliveriesScreenState();
}

class _FoodDeliveriesScreenState extends State<FoodDeliveriesScreen> {
  ApiClient get _api => Get.find<ApiClient>();
  List<dynamic> _offers = [];
  Map<String, dynamic>? _current;
  bool _loading = true;
  bool _busy = false;
  bool _enabled = false;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _load();
    _t = Timer.periodic(const Duration(seconds: 12), (_) => _load(silent: true));
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() => _loading = true);
    try {
      final st = await _api.getData('/api/driver/food/settings');
      if (st.statusCode == 200 && st.body is Map) _enabled = st.body['enabled'] == true;
      final c = await _api.getData('/api/driver/food/current');
      if (c.statusCode == 200 && c.body is Map) {
        _current = c.body['order'] == null ? null : Map<String, dynamic>.from(c.body['order'] as Map);
      }
      if (_current == null) {
        final o = await _api.getData('/api/driver/food/offers');
        if (o.statusCode == 200 && o.body is Map) _offers = (o.body['offers'] as List?) ?? [];
      } else {
        _offers = [];
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _toggle(bool v) async {
    setState(() {
      _enabled = v;
      _busy = true;
    });
    final r = await _api.postData('/api/driver/food/settings', {'enabled': v ? 1 : 0});
    if (r.statusCode != 200) {
      _enabled = !v;
      showCustomSnackBar('Impossible de changer ce réglage.');
    } else {
      showCustomSnackBar(v ? 'Tu recevras les livraisons Repas' : 'Livraisons Repas désactivées', isError: false);
    }
    if (mounted) setState(() => _busy = false);
    _load(silent: true);
  }

  Future<void> _act(String path, String okMsg, {Map<String, dynamic>? body}) async {
    setState(() => _busy = true);
    final r = await _api.postData(path, body ?? {});
    String msg = okMsg;
    if (r.statusCode != 200) {
      msg = 'Action impossible.';
      try {
        if (r.body is Map && r.body['message'] != null) msg = '${r.body['message']}';
      } catch (_) {}
    }
    showCustomSnackBar(msg, isError: r.statusCode != 200);
    if (mounted) setState(() => _busy = false);
    _load();
  }

  Future<void> _deliver(Map<String, dynamic> o) async {
    final mode = await Get.bottomSheet<String>(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Get.theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Comment as-tu remis la commande ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ListTile(leading: const Icon(Icons.handshake_outlined), title: const Text('Remise en main propre'), onTap: () => Get.back(result: 'hand')),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Déposée (photo obligatoire)'), onTap: () => Get.back(result: 'dropped')),
        ])),
      ),
    );
    if (mode == null) return;
    if (mode == 'hand') {
      await _act('/api/driver/food/orders/${o['id']}/delivered', 'Livraison terminée ✅', body: {'mode': 'hand'});
      return;
    }
    final photo = await pickPhotoWithChoice();
    if (photo == null) {
      showCustomSnackBar('La photo est obligatoire quand la commande est déposée.');
      return;
    }
    final noteC = TextEditingController();
    final go = await Get.dialog<bool>(AlertDialog(
      title: const Text('Où as-tu déposé la commande ?'),
      content: TextField(controller: noteC, maxLength: 150, decoration: const InputDecoration(hintText: 'Ex : devant la porte, avec le gardien')),
      actions: [
        TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
        TextButton(onPressed: () => Get.back(result: true), child: const Text('Terminer la livraison')),
      ],
    ));
    if (go != true) return;
    setState(() => _busy = true);
    String msg = 'Livraison terminée ✅';
    bool ok = false;
    try {
      final r = await _api.postMultipartData('/api/driver/food/orders/${o['id']}/delivered',
          {'mode': 'dropped', 'note': noteC.text.trim()}, [MultipartBody('photo', photo)], null, []);
      ok = r.statusCode == 200;
      if (!ok) {
        msg = 'Envoi impossible. Réessaie.';
        try {
          if (r.body is Map && r.body['message'] != null) msg = '${r.body['message']}';
        } catch (_) {}
      }
    } catch (_) {
      msg = 'Envoi impossible. Réessaie.';
    }
    showCustomSnackBar(msg, isError: !ok);
    if (mounted) setState(() => _busy = false);
    _load();
  }

  void _map(String q) => launchUrl(Uri.parse('https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(q)}'), mode: LaunchMode.externalApplication);

  Widget _addr(String label, String value, {String? phone}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)), Text(value, style: const TextStyle(fontWeight: FontWeight.w600))])),
          IconButton(onPressed: () => _map(value), icon: const Icon(Icons.navigation_outlined)),
          if (phone != null && phone.isNotEmpty) IconButton(onPressed: () => launchUrl(Uri.parse('tel:$phone')), icon: const Icon(Icons.phone_outlined)),
        ]),
      );

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBar(title: const Text('Livraisons Repas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(12), children: [
                Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  child: SwitchListTile(
                    value: _enabled,
                    onChanged: _busy ? null : _toggle,
                    title: const Text('Accepter les livraisons Repas', style: TextStyle(fontWeight: FontWeight.w700)),
                    subtitle: Text(_enabled ? 'Activé : tu vois les nouvelles commandes à livrer.' : 'Désactivé : active pour recevoir les commandes de restaurants.'),
                  ),
                ),
                if (!_enabled && _current == null)
                  const Padding(padding: EdgeInsets.all(24), child: Text('Active l\'option ci-dessus pour voir les livraisons Repas.', textAlign: TextAlign.center))
                else if (_current != null) _currentCard(primary)
                else if (_offers.isEmpty)
                  const Padding(padding: EdgeInsets.all(32), child: Text('Aucune livraison disponible pour le moment. Cette page se met à jour automatiquement.', textAlign: TextAlign.center))
                else
                  for (final raw in _offers)
                    Builder(builder: (c) {
                      final o = Map<String, dynamic>.from(raw as Map);
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(child: Text('${o['restaurant']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
                              Text('${(o['earning'] as num).toStringAsFixed(2)} \$', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: primary)),
                            ]),
                            Text('${o['status'] == 'ready' ? 'Prête à récupérer' : (o['status'] == 'placed' ? 'Payée · en attente du restaurant' : 'En préparation')} · ${o['items_count']} article(s)'),
                            const SizedBox(height: 6),
                            Text('Récupérer : ${o['restaurant_address']}'),
                            Text('Livrer : ${o['delivery_address']}'),
                            const SizedBox(height: 10),
                            SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _busy ? null : () => _act('/api/driver/food/orders/${o['id']}/accept', 'Livraison acceptée'), child: const Text('Accepter la livraison'))),
                          ]),
                        ),
                      );
                    }),
              ]),
            ),
    );
  }

  Widget _currentCard(Color primary) {
    final o = _current!;
    final picked = o['status'] == 'picked_up';
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text('${o['restaurant']}  ·  #${o['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
            Text('${(o['earning'] as num).toStringAsFixed(2)} \$', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: primary)),
          ]),
          const SizedBox(height: 4),
          Text(picked ? 'En route vers le client' : (o['status'] == 'ready' ? 'Commande prête — va la récupérer' : (o['status'] == 'placed' ? 'En attente que le restaurant accepte' : 'En préparation — va au restaurant')), style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
          if ((o['code'] ?? '').toString().isNotEmpty)
            Container(
              margin: const EdgeInsets.only(top: 8, bottom: 4),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
              child: Row(children: [
                Expanded(child: Text('Au restaurant, présente-toi avec le nom du client et ce code :\n${o['customer_name'] ?? ''}', style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
                Text('${o['code']}', style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.black)),
              ]),
            ),
          const SizedBox(height: 6),
          for (final it in (o['items'] as List)) Text('$it'),
          if ((o['note'] ?? '').toString().isNotEmpty) Text('Note : ${o['note']}'),
          const Divider(),
          _addr('Restaurant', '${o['restaurant_address']}', phone: o['restaurant_phone']?.toString()),
          _addr('Client ${o['customer_name'] ?? ''}', '${o['delivery_address']}', phone: o['customer_phone']?.toString()),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: (_busy || o['status'] == 'placed') ? null : () => picked ? _deliver(o) : _act('/api/driver/food/orders/${o['id']}/picked', 'Commande récupérée'),
              child: Text(picked ? 'J\'ai livré la commande' : 'J\'ai récupéré la commande'),
            ),
          ),
        ]),
      ),
    );
  }
}
