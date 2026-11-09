import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/rental/screens/rental_pay_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Mes locations: statut, prolonger, terminer.
class MyRentalsScreen extends StatefulWidget {
  const MyRentalsScreen({super.key});

  @override
  State<MyRentalsScreen> createState() => _MyRentalsScreenState();
}

class _MyRentalsScreenState extends State<MyRentalsScreen> {
  ApiClient get _api => Get.find<ApiClient>();
  List<dynamic> _items = [];
  bool _loading = true;

  static const _status = {
    'awaiting_payment': 'En attente de paiement',
    'active': 'En cours',
    'overdue': 'En retard — compte bloqué',
    'return_pending': 'Retour à confirmer par le propriétaire',
    'ended': 'Terminée',
    'cancelled': 'Annulée',
  };
  static const _dep = {
    'pending': 'Dépôt en attente',
    'held': 'Dépôt retenu en garantie',
    'refunded': 'Dépôt remboursé',
    'partial': 'Dépôt remboursé en partie',
    'retained': 'Dépôt conservé',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getData('/api/driver/rental/bookings');
      if (r.statusCode == 200 && r.body is Map) _items = (r.body['bookings'] as List?) ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _extend(Map b) async {
    int qty = 1;
    final unit = b['period'] == 'week' ? 'semaine(s)' : 'jour(s)';
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: const Text('Prolonger la location'),
          content: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            IconButton(onPressed: qty > 1 ? () => set(() => qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$qty $unit', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            IconButton(onPressed: qty < 30 ? () => set(() => qty++) : null, icon: const Icon(Icons.add_circle_outline)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Annuler')),
            TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Payer')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    final res = await _api.postData('/api/driver/rental/bookings/${b['id']}/extend', {'qty': qty});
    if (res.statusCode != 200 || res.body is! Map || res.body['checkout_url'] == null) {
      String msg = 'Prolongation impossible.';
      try {
        if (res.body is Map && res.body['message'] != null) msg = '${res.body['message']}';
      } catch (_) {}
      showCustomSnackBar(msg);
      return;
    }
    final token = '${res.body['token']}';
    await Get.to(() => RentalPayScreen(url: '${res.body['checkout_url']}'));
    bool paid = false;
    for (int i = 0; i < 3 && !paid; i++) {
      final v = await _api.postData('/api/driver/rental/verify', {'token': token});
      paid = v.statusCode == 200;
      if (!paid) await Future.delayed(const Duration(seconds: 2));
    }
    showCustomSnackBar(paid ? 'Location prolongée ✅' : 'Paiement non confirmé.');
    _load();
  }

  Future<void> _end(Map b) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: const Text('Terminer la location ?'),
        content: const Text('Rends le véhicule au propriétaire. Il confirmera le retour et ton dépôt sera remboursé si tu ne dois rien.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Oui, terminer')),
        ],
      ),
    );
    if (ok != true) return;
    final res = await _api.postData('/api/driver/rental/bookings/${b['id']}/end', {});
    showCustomSnackBar(res.statusCode == 200 ? 'Demande de retour envoyée.' : 'Action impossible.');
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes locations')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _items.isEmpty
              ? const Center(child: Text('Aucune location.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _items.length,
                    itemBuilder: (c, i) {
                      final b = Map<String, dynamic>.from(_items[i] as Map);
                      final st = '${b['status']}';
                      final canAct = st == 'active' || st == 'overdue';
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Text('${b['vehicle'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                            const SizedBox(height: 4),
                            Text(_status[st] ?? st, style: TextStyle(color: st == 'overdue' ? Colors.red : Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
                            const SizedBox(height: 6),
                            Text('Du ${b['start_date']} au ${b['end_date']}'),
                            Text('Location: ${b['rent_amount']} \$ · Dépôt: ${b['deposit_amount']} \$'),
                            Text(_dep['${b['deposit_status']}'] ?? '', style: const TextStyle(fontSize: 12.5)),
                            if ((b['deposit_note'] ?? '').toString().isNotEmpty) Text('Note: ${b['deposit_note']}', style: const TextStyle(fontSize: 12.5)),
                            if ((b['owner'] ?? '').toString().isNotEmpty) Text('Propriétaire: ${b['owner']}'),
                            if ((b['owner_phone'] ?? '').toString().isNotEmpty)
                              TextButton.icon(
                                onPressed: () => launchUrl(Uri.parse('tel:${b['owner_phone']}')),
                                icon: const Icon(Icons.phone, size: 18),
                                label: Text('${b['owner_phone']}'),
                              ),
                            if (canAct)
                              Row(children: [
                                Expanded(child: ElevatedButton(onPressed: () => _extend(b), child: const Text('Prolonger'))),
                                const SizedBox(width: 10),
                                Expanded(child: OutlinedButton(onPressed: () => _end(b), child: const Text('Terminer'))),
                              ]),
                          ]),
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}
