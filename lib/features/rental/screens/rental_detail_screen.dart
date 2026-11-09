import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/rental/screens/rental_pay_screen.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Détail d'un véhicule + choix de la durée + paiement (location + dépôt de garantie).
class RentalDetailScreen extends StatefulWidget {
  final Map<String, dynamic> vehicle;
  const RentalDetailScreen({super.key, required this.vehicle});

  @override
  State<RentalDetailScreen> createState() => _RentalDetailScreenState();
}

class _RentalDetailScreenState extends State<RentalDetailScreen> {
  String _period = 'day';
  int _qty = 1;
  DateTime _start = DateTime.now();
  bool _busy = false;

  ApiClient get _api => Get.find<ApiClient>();
  Map<String, dynamic> get _v => widget.vehicle;

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;
  String _money(double v) => '${v.toStringAsFixed(2)} \$';
  String _two(int n) => n.toString().padLeft(2, '0');
  String _date(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  double get _rent => _qty * _num(_period == 'week' ? _v['price_week'] : _v['price_day']);
  double get _deposit => _num(_v['deposit']);

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (d != null) setState(() => _start = d);
  }

  Future<void> _pay() async {
    setState(() => _busy = true);
    final res = await _api.postData('/api/driver/rental/book', {
      'vehicle_id': _v['id'],
      'period': _period,
      'qty': _qty,
      'start_date': _date(_start),
    });
    if (!mounted) return;
    if (res.statusCode != 200 || res.body is! Map || res.body['checkout_url'] == null) {
      setState(() => _busy = false);
      String msg = 'Réservation impossible. Réessaie.';
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
    if (!mounted) return;
    setState(() => _busy = false);
    if (paid) {
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (c) => AlertDialog(
          title: const Text('Location confirmée ✅'),
          content: const Text('Ton paiement est reçu. Le propriétaire te contactera pour la remise du véhicule. Retrouve ta location dans « Mes locations ».'),
          actions: [TextButton(onPressed: () => Navigator.of(c).pop(), child: const Text('OK'))],
        ),
      );
      if (mounted) Get.back(result: true);
    } else {
      showCustomSnackBar('Paiement non confirmé. Aucune location créée.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    final photos = (_v['photos'] as List?) ?? [];
    final maxQty = _period == 'week' ? 12 : 30;
    final days = _qty * (_period == 'week' ? 7 : 1);
    final end = _start.add(Duration(days: days - 1));
    return Scaffold(
      appBar: AppBar(title: Text('${_v['brand']} ${_v['model']}')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (photos.isNotEmpty)
            SizedBox(
              height: 200,
              child: PageView(children: [
                for (final p in photos)
                  ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network('$p', fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.black12))),
              ]),
            )
          else
            Container(height: 140, decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(14)), child: const Icon(Icons.directions_car, size: 56)),
          const SizedBox(height: 14),
          Text('${_v['brand']} ${_v['model']} ${_v['year'] ?? ''}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('${_v['owner'] ?? ''}${(_v['city'] ?? '').toString().isNotEmpty ? ' · ${_v['city']}' : ''}'),
          if ((_v['description'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 8), child: Text('${_v['description']}')),
          const Divider(height: 28),
          const Text('Durée', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'day', label: Text('Par jour · ${_money(_num(_v['price_day']))}')),
              ButtonSegment(value: 'week', label: Text('Par semaine · ${_money(_num(_v['price_week']))}')),
            ],
            selected: {_period},
            onSelectionChanged: (s) => setState(() {
              _period = s.first;
              _qty = 1;
            }),
          ),
          const SizedBox(height: 10),
          Row(children: [
            Text(_period == 'week' ? 'Nombre de semaines' : 'Nombre de jours'),
            const Spacer(),
            IconButton(onPressed: _qty > 1 ? () => setState(() => _qty--) : null, icon: const Icon(Icons.remove_circle_outline)),
            Text('$_qty', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            IconButton(onPressed: _qty < maxQty ? () => setState(() => _qty++) : null, icon: const Icon(Icons.add_circle_outline)),
          ]),
          OutlinedButton.icon(onPressed: _pickDate, icon: const Icon(Icons.calendar_month_outlined), label: Text('Début : ${_date(_start)}  ·  Fin : ${_date(end)}')),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(color: primary.withOpacity(.08), borderRadius: BorderRadius.circular(14)),
            child: Column(children: [
              _row('Location', _money(_rent)),
              _row('Dépôt de garantie (remboursable)', _money(_deposit)),
              const Divider(),
              _row('Total à payer', _money(_rent + _deposit), bold: true),
            ]),
          ),
          const SizedBox(height: 8),
          const Text('Le dépôt est rendu à la fin de la location si tu ne dois rien au propriétaire. Si la location n\'est pas prolongée à la date de fin, ton compte est bloqué jusqu\'au paiement.',
              style: TextStyle(fontSize: 12.5, color: Colors.black54)),
          const SizedBox(height: 14),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _busy ? null : _pay,
              style: ElevatedButton.styleFrom(backgroundColor: primary, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))),
              child: _busy ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Payer et louer'),
            ),
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _row(String a, String b, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Flexible(child: Text(a, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400))),
          Text(b, style: TextStyle(fontWeight: bold ? FontWeight.w700 : FontWeight.w400, fontSize: bold ? 17 : 14)),
        ]),
      );
}
