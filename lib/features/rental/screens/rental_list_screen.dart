import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/rental/screens/my_rentals_screen.dart';
import 'package:ride_sharing_user_app/features/rental/screens/rental_detail_screen.dart';

/// Louer un véhicule: liste des véhicules proposés par les partenaires.
class RentalListScreen extends StatefulWidget {
  const RentalListScreen({super.key});

  @override
  State<RentalListScreen> createState() => _RentalListScreenState();
}

class _RentalListScreenState extends State<RentalListScreen> {
  ApiClient get _api => Get.find<ApiClient>();
  List<dynamic> _items = [];
  bool _loading = true;
  String _cat = '';

  static const _cats = {
    '': 'Tous',
    'car': 'Voiture',
    'suv': 'SUV',
    'van': 'Van',
    'minibus': 'Minibus',
    'truck': 'Camion',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getData('/api/driver/rental/vehicles', query: _cat.isEmpty ? null : {'category': _cat});
      if (r.statusCode == 200 && r.body is Map) _items = (r.body['vehicles'] as List?) ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Louer un véhicule'),
        actions: [
          TextButton(onPressed: () => Get.to(() => const MyRentalsScreen()), child: const Text('Mes locations')),
        ],
      ),
      body: Column(children: [
        SizedBox(
          height: 54,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            children: [
              for (final e in _cats.entries)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: _cat == e.key,
                    onSelected: (_) {
                      _cat = e.key;
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _items.isEmpty
                  ? const Center(child: Text('Aucun véhicule disponible pour le moment.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _items.length,
                        itemBuilder: (c, i) {
                          final v = Map<String, dynamic>.from(_items[i] as Map);
                          final photos = (v['photos'] as List?) ?? [];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            clipBehavior: Clip.antiAlias,
                            child: InkWell(
                              onTap: () => Get.to(() => RentalDetailScreen(vehicle: v)),
                              child: Row(children: [
                                SizedBox(
                                  width: 120,
                                  height: 100,
                                  child: photos.isNotEmpty
                                      ? Image.network('${photos.first}', fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(color: Colors.black12))
                                      : Container(color: Colors.black12, child: const Icon(Icons.directions_car, size: 40)),
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                      Text('${v['brand']} ${v['model']} ${v['year'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                                      const SizedBox(height: 2),
                                      Text('${v['owner'] ?? ''}${(v['city'] ?? '').toString().isNotEmpty ? ' · ${v['city']}' : ''}', style: const TextStyle(fontSize: 12.5, color: Colors.black54)),
                                      const SizedBox(height: 6),
                                      Text('${v['price_day']} \$/jour · ${v['price_week']} \$/sem.', style: TextStyle(color: Theme.of(context).primaryColor, fontWeight: FontWeight.w600)),
                                      Text('Dépôt: ${v['deposit']} \$', style: const TextStyle(fontSize: 12)),
                                    ]),
                                  ),
                                ),
                              ]),
                            ),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
