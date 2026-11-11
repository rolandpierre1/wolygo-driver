import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/features/profile/controllers/profile_controller.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';

/// Mes types de travail: Passager, Colis, Repas (chaque changement est enregistré tout de suite).
class WorkTypesScreen extends StatefulWidget {
  const WorkTypesScreen({super.key});

  @override
  State<WorkTypesScreen> createState() => _WorkTypesScreenState();
}

class _WorkTypesScreenState extends State<WorkTypesScreen> {
  ApiClient get _api => Get.find<ApiClient>();
  bool _ride = true;
  bool _parcel = true;
  bool _food = false;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pc = Get.find<ProfileController>();
      await pc.getProfileInfo();
      final s = pc.profileInfo?.details?.services;
      if (s != null && s.isNotEmpty) {
        _ride = s.contains('ride_request');
        _parcel = s.contains('parcel');
      }
      final r = await _api.getData('/api/driver/food/settings');
      if (r.statusCode == 200 && r.body is Map) _food = r.body['enabled'] == true;
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<bool> _saveServices(bool ride, bool parcel) async {
    final p = Get.find<ProfileController>().profileInfo;
    if (p == null) return false;
    final services = <String>[if (ride) 'ride_request', if (parcel) 'parcel'];
    final fields = <String, String>{
      '_method': 'put',
      'first_name': p.firstName ?? '',
      'last_name': p.lastName ?? '',
      'identification_type': p.identificationType ?? '',
      'identification_number': p.identificationNumber ?? '',
      'email': p.email ?? '',
      'service': jsonEncode(services),
    };
    try {
      final r = await _api.postMultipartData('/api/driver/update/profile', fields, [], null, []);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<void> _toggleService({bool? ride, bool? parcel}) async {
    final nr = ride ?? _ride;
    final np = parcel ?? _parcel;
    if (!nr && !np) {
      showCustomSnackBar('Garde au moins Passager ou Livraison de colis activé.');
      return;
    }
    final before = [_ride, _parcel];
    setState(() {
      _ride = nr;
      _parcel = np;
      _busy = true;
    });
    final ok = await _saveServices(nr, np);
    if (!ok) {
      _ride = before[0];
      _parcel = before[1];
      showCustomSnackBar('Impossible de changer ce réglage. Réessaie.');
    } else {
      showCustomSnackBar('Enregistré', isError: false);
      try {
        Get.find<ProfileController>().getProfileInfo();
      } catch (_) {}
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _toggleFood(bool v) async {
    setState(() {
      _food = v;
      _busy = true;
    });
    bool ok = false;
    try {
      final r = await _api.postData('/api/driver/food/settings', {'enabled': v ? 1 : 0});
      ok = r.statusCode == 200;
    } catch (_) {}
    if (!ok) {
      _food = !v;
      showCustomSnackBar('Impossible de changer ce réglage. Réessaie.');
    } else {
      showCustomSnackBar('Enregistré', isError: false);
    }
    if (mounted) setState(() => _busy = false);
  }

  Widget _tile(String title, String sub, bool value, ValueChanged<bool> onChanged) => Card(
        margin: const EdgeInsets.only(bottom: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: SwitchListTile(
          value: value,
          onChanged: _busy ? null : onChanged,
          title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
          subtitle: Text(sub),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes types de travail')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(14), children: [
              const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: Text('Choisis comment tu veux travailler. Tu peux changer quand tu veux.'),
              ),
              if (_busy) const Padding(padding: EdgeInsets.only(bottom: 8), child: LinearProgressIndicator()),
              _tile('Passager', 'Transporter des passagers', _ride, (v) => _toggleService(ride: v)),
              _tile('Livraison de colis', 'Livrer des colis', _parcel, (v) => _toggleService(parcel: v)),
              _tile('Livraison Repas', 'Livrer des commandes de restaurants', _food, _toggleFood),
            ]),
    );
  }
}
