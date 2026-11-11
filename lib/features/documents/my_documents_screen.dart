import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/helper/image_source_picker.dart';

/// Mes documents: documents demandés par WolyGo + ajout avec date d'expiration.
class MyDocumentsScreen extends StatefulWidget {
  const MyDocumentsScreen({super.key});

  @override
  State<MyDocumentsScreen> createState() => _MyDocumentsScreenState();
}

class _MyDocumentsScreenState extends State<MyDocumentsScreen> {
  ApiClient get _api => Get.find<ApiClient>();
  List<dynamic> _rows = [];
  bool _loading = true;
  bool _busy = false;

  static const _labels = {
    'requested': 'À envoyer',
    'submitted': 'En vérification',
    'approved': 'Approuvé',
    'rejected': 'Refusé',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await _api.getData('/api/driver/documents');
      if (r.statusCode == 200 && r.body is Map) _rows = (r.body['content'] as List?) ?? [];
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _send({int? requestId, String? name}) async {
    final photo = await pickPhotoWithChoice();
    if (photo == null) return;
    if (!mounted) return;
    final d = await showDatePicker(
      context: context,
      helpText: "Date d'expiration du document",
      initialDate: DateTime.now().add(const Duration(days: 365)),
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 365 * 20)),
    );
    if (d == null) return;
    setState(() => _busy = true);
    final body = <String, String>{
      'expiry_date': '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}',
    };
    if (requestId != null) body['request_id'] = '$requestId';
    if (name != null) body['name'] = name;
    try {
      final r = await _api.postMultipartData('/api/driver/documents/upload', body, [MultipartBody('file', photo)], null, []);
      if (r.statusCode == 200) {
        showCustomSnackBar('Document envoyé. Merci !', isError: false);
        await _load();
      } else {
        showCustomSnackBar("Envoi impossible. Réessayez.");
      }
    } catch (_) {
      showCustomSnackBar("Envoi impossible. Réessayez.");
    }
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _addOther() async {
    final c = TextEditingController();
    final n = await Get.dialog<String>(AlertDialog(
      title: const Text('Nom du document'),
      content: TextField(controller: c, decoration: const InputDecoration(hintText: 'Ex : Assurance')),
      actions: [
        TextButton(onPressed: () => Get.back(), child: const Text('Annuler')),
        TextButton(onPressed: () => Get.back(result: c.text.trim()), child: const Text('Continuer')),
      ],
    ));
    if (n == null || n.isEmpty) return;
    await _send(name: n);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes documents')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _addOther,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter un document'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 90), children: [
                if (_busy) const LinearProgressIndicator(),
                if (_rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text("Aucun document pour l'instant. WolyGo vous demandera ici les documents manquants.",
                        textAlign: TextAlign.center),
                  ),
                ..._rows.map((r) {
                  final st = '${r['status']}';
                  final color = st == 'approved'
                      ? Colors.green
                      : st == 'rejected'
                          ? Colors.red
                          : st == 'submitted'
                              ? Colors.orange
                              : Colors.blueGrey;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 12),
                    child: Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text('${r['name']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                            decoration: BoxDecoration(color: color.withOpacity(.15), borderRadius: BorderRadius.circular(12)),
                            child: Text(_labels[st] ?? st, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                        ]),
                        if ((r['message'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('${r['message']}')),
                        if (r['due_date'] != null) Padding(padding: const EdgeInsets.only(top: 6), child: Text('À fournir avant le ${r['due_date']}', style: const TextStyle(color: Colors.red))),
                        if ((r['review_note'] ?? '').toString().isNotEmpty) Padding(padding: const EdgeInsets.only(top: 6), child: Text('Motif : ${r['review_note']}', style: const TextStyle(color: Colors.red))),
                        if (r['file_url'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: InkWell(
                              onTap: () => launchUrl(Uri.parse('${r['file_url']}'), mode: LaunchMode.externalApplication),
                              child: Text('Voir le fichier${r['expiry_date'] != null ? ' · expire le ${r['expiry_date']}' : ''}',
                                  style: const TextStyle(decoration: TextDecoration.underline)),
                            ),
                          ),
                        if (st != 'approved')
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: ElevatedButton.icon(
                              onPressed: _busy ? null : () => _send(requestId: r['id'] is int ? r['id'] as int : int.tryParse('${r['id']}')),
                              icon: const Icon(Icons.upload_file),
                              label: Text(r['file_url'] != null ? 'Remplacer' : 'Envoyer'),
                            ),
                          ),
                      ]),
                    ),
                  );
                }),
              ]),
            ),
    );
  }
}
