import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/image_source_picker.dart';

/// Cadre jaune: nom du client + code du colis (à présenter à l'expéditeur).
class ParcelCodeBox extends StatefulWidget {
  final String tripId;
  const ParcelCodeBox({super.key, required this.tripId});

  @override
  State<ParcelCodeBox> createState() => _ParcelCodeBoxState();
}

class _ParcelCodeBoxState extends State<ParcelCodeBox> {
  String? _code;
  String _name = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final r = await Get.find<ApiClient>().getData('/api/driver/parcel-proof/${widget.tripId}');
      if (r.statusCode == 200 && r.body is Map && mounted) {
        setState(() {
          _code = '${r.body['code'] ?? ''}';
          _name = '${r.body['customer_name'] ?? ''}';
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_code == null || _code!.isEmpty) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFFFFF3CD), borderRadius: BorderRadius.circular(12)),
      child: Row(children: [
        Expanded(child: Text('Pour récupérer le colis, présente-toi avec le nom du client et ce code :\n$_name',
            style: const TextStyle(color: Colors.black87, fontWeight: FontWeight.w600))),
        Text(_code!, style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w900, letterSpacing: 3, color: Colors.black)),
      ]),
    );
  }
}

class ParcelProofFlow {
  /// Demande la preuve de remise (en main propre, ou photo si déposé).
  /// Retourne true pour continuer la fin de course existante, false si le chauffeur annule.
  /// Si le serveur ne répond pas, on laisse continuer (le service ne doit jamais être bloqué).
  static Future<bool> ensureProof(String tripId) async {
    final api = Get.find<ApiClient>();
    try {
      final r = await api.getData('/api/driver/parcel-proof/$tripId');
      if (r.statusCode != 200 || r.body is! Map) return true;
      if (r.body['has_proof'] == true) return true;
    } catch (_) {
      return true;
    }
    final mode = await Get.bottomSheet<String>(
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: Get.theme.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
        child: SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Padding(padding: EdgeInsets.only(bottom: 8), child: Text('Comment as-tu remis le colis ?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16))),
          ListTile(leading: const Icon(Icons.handshake_outlined), title: const Text('Remis en main propre'), onTap: () => Get.back(result: 'hand')),
          ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Déposé (photo obligatoire)'), onTap: () => Get.back(result: 'dropped')),
        ])),
      ),
    );
    if (mode == null) return false;
    Map<String, String> body = {'mode': mode};
    List<MultipartBody> files = [];
    if (mode == 'dropped') {
      final photo = await pickPhotoWithChoice();
      if (photo == null) {
        showCustomSnackBar('La photo est obligatoire quand le colis est déposé.');
        return false;
      }
      final c = TextEditingController();
      final go = await Get.dialog<bool>(AlertDialog(
        title: const Text('Où as-tu déposé le colis ?'),
        content: TextField(controller: c, maxLength: 150, decoration: const InputDecoration(hintText: 'Ex : devant la porte, avec le gardien')),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: const Text('Annuler')),
          TextButton(onPressed: () => Get.back(result: true), child: const Text('Envoyer la photo')),
        ],
      ));
      if (go != true) return false;
      body['note'] = c.text.trim();
      files = [MultipartBody('photo', photo)];
    }
    try {
      final r = await api.postMultipartData('/api/driver/parcel-proof/$tripId', body, files, null, []);
      if (r.statusCode == 200) return true;
      String msg = 'Envoi impossible. Réessaie.';
      try {
        if (r.body is Map && r.body['message'] != null) msg = '${r.body['message']}';
      } catch (_) {}
      showCustomSnackBar(msg);
    } catch (_) {
      showCustomSnackBar('Envoi impossible. Réessaie.');
    }
    return false;
  }
}
