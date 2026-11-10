import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

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

  Future<void> _act(String path, String okMsg) async {
    setState(() => _busy = true);
    final r = await _api.postData(path, {});
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
                if (_current != null) _currentCard(primary)
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
                            Text('${o['status'] == 'ready' ? 'Prête à récupérer' : 'En préparation'} · ${o['items_count']} article(s)'),
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
          Text(picked ? 'En route vers le client' : (o['status'] == 'ready' ? 'Commande prête — va la récupérer' : 'En préparation — va au restaurant'), style: TextStyle(color: primary, fontWeight: FontWeight.w600)),
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
              onPressed: _busy ? null : () => picked ? _act('/api/driver/food/orders/${o['id']}/delivered', 'Livraison terminée ✅') : _act('/api/driver/food/orders/${o['id']}/picked', 'Commande récupérée'),
              child: Text(picked ? 'J\'ai livré la commande' : 'J\'ai récupéré la commande'),
            ),
          ),
        ]),
      ),
    );
  }
}
