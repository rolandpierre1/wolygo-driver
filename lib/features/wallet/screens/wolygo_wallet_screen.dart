import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:url_launcher/url_launcher.dart';

/// Mon portefeuille (même présentation que Crisyo): solde, méthode de paiement
/// automatique (hebdomadaire / lendemain ouvré / instantané), retrait, historique.
/// Les informations bancaires sont saisies sur la page sécurisée de Stripe.
class WolygoWalletScreen extends StatefulWidget {
  const WolygoWalletScreen({super.key});

  @override
  State<WolygoWalletScreen> createState() => _WolygoWalletScreenState();
}

class _WolygoWalletScreenState extends State<WolygoWalletScreen> with WidgetsBindingObserver {
  static const Color _ink = Color(0xFF111111);

  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _data;
  String _method = 'weekly';
  bool _waitingStripe = false;
  final TextEditingController _amountController = TextEditingController();

  ApiClient get _api => Get.find<ApiClient>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _amountController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Retour de la page Stripe: on revérifie le statut de la méthode.
    if (state == AppLifecycleState.resumed && _waitingStripe) {
      _waitingStripe = false;
      _refreshStripeThenLoad();
    }
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;
  String _money(dynamic v) => '${_num(v).toStringAsFixed(2)} \$';

  String _messageOf(dynamic res, String fallback) {
    try {
      if (res.body is Map && res.body['message'] != null) return '${res.body['message']}';
    } catch (_) {}
    return fallback;
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) setState(() { _loading = true; _error = null; });
    final res = await _api.getData('/api/driver/wallet/overview');
    if (!mounted) return;
    if (res.statusCode == 200 && res.body is Map && res.body['data'] is Map) {
      final data = Map<String, dynamic>.from(res.body['data']);
      setState(() {
        _data = data;
        _loading = false;
        _error = null;
        final methods = _enabledMethods();
        if (methods.isNotEmpty && !methods.any((m) => m['method'] == _method)) {
          _method = methods.first['method'];
        }
        if (_amountController.text.isEmpty) {
          final b = _num(data['balance']);
          if (b > 0) _amountController.text = b.toStringAsFixed(2);
        }
      });
    } else {
      setState(() { _loading = false; _error = 'Impossible de charger le portefeuille. Vérifie ta connexion.'; });
    }
  }

  List<Map<String, dynamic>> _enabledMethods() {
    final list = (_data?['settings']?['methods'] as List?) ?? [];
    return list.map((e) => Map<String, dynamic>.from(e)).where((m) => m['enabled'] == true).toList();
  }

  bool get _ready => _data?['stripe']?['payouts_enabled'] == true;
  bool get _started => _data?['stripe']?['connected'] == true;
  List<Map<String, dynamic>> get _accounts =>
      ((_data?['payout_accounts'] as List?) ?? []).map((e) => Map<String, dynamic>.from(e)).toList();
  Map<String, dynamic>? _accountFor(String method) {
    final want = method == 'instant' ? 'card' : 'bank';
    for (final a in _accounts) {
      if (a['type'] == want) return a;
    }
    return null;
  }

  Future<void> _refreshStripeThenLoad() async {
    await _api.postData('/api/driver/wallet/stripe/refresh', {});
    await _load(silent: true);
  }

  Future<void> _openStripe({bool manage = false}) async {
    setState(() => _busy = true);
    final res = await _api.postData(manage ? '/api/driver/wallet/stripe/dashboard' : '/api/driver/wallet/stripe/onboarding', {});
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.statusCode == 200 && res.body is Map && res.body['data']?['url'] != null) {
      _waitingStripe = true;
      await launchUrl(Uri.parse(res.body['data']['url']), mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar(_messageOf(res, 'Impossible d\'ouvrir la page de paiement.'));
    }
  }

  Future<void> _requestPayout() async {
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      showCustomSnackBar('Entre un montant valide.');
      return;
    }
    setState(() => _busy = true);
    final res = await _api.postData('/api/driver/wallet/payout', {'amount': amount.toStringAsFixed(2), 'method': _method});
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.statusCode == 200) {
      showCustomSnackBar('Retrait enregistré.', isError: false);
      _amountController.clear();
      await _load(silent: true);
    } else {
      showCustomSnackBar(_messageOf(res, 'Le retrait a échoué.'));
    }
  }

  String _methodLabel(String m) => {'weekly': 'Hebdomadaire (lundi)', 'next_day': 'Lendemain ouvré', 'instant': 'Instantané'}[m] ?? m;
  String _methodDesc(String m) => {
        'weekly': 'Versement chaque lundi',
        'next_day': 'Versement le lendemain ouvré',
        'instant': 'Versement instantané (par carte)',
      }[m] ?? '';
  IconData _methodIcon(String m) => {
        'weekly': Icons.calendar_today_outlined,
        'next_day': Icons.access_time,
        'instant': Icons.bolt,
      }[m] ?? Icons.payments_outlined;
  String _statusLabel(String s) => {'pending': 'En attente', 'processing': 'En cours', 'paid': 'Envoyé', 'failed': 'Échoué'}[s] ?? s;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
                ? Center(child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(mainAxisSize: MainAxisSize.min, children: [
                      Text(_error!, textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
                    ]),
                  ))
                : RefreshIndicator(
                    onRefresh: () => _load(silent: true),
                    child: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: [
                      Row(children: [
                        IconButton(
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.arrow_back, color: _ink),
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      ]),
                      const Text('Mon portefeuille', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800, color: _ink)),
                      const SizedBox(height: 18),
                      _balanceCard(),
                      const SizedBox(height: 18),
                      _methodsCard(),
                      const SizedBox(height: 18),
                      _payoutsList(),
                      const SizedBox(height: 18),
                      _ledgerList(),
                    ]),
                  ),
      ),
    );
  }

  Widget _box({required Widget child}) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: const Color(0xFFFAFAFA),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFD9D9D9)),
        ),
        child: child,
      );

  Widget _balanceCard() => Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 28),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          gradient: const LinearGradient(colors: [Color(0xFF111111), Color(0xFF3A3A3A)], begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Icon(Icons.account_balance_wallet_outlined, color: Colors.white, size: 36),
          const SizedBox(height: 22),
          const Text('Solde disponible', style: TextStyle(color: Colors.white70, fontSize: 17)),
          const SizedBox(height: 6),
          Text('${_num(_data?['balance']).toStringAsFixed(2)} CAD',
              style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
        ]),
      );

  Widget _methodsCard() {
    final methods = _enabledMethods();
    return _box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: const [
          Icon(Icons.payments_outlined, color: _ink),
          SizedBox(width: 12),
          Expanded(child: Text('Méthode de paiement automatique',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink))),
        ]),
        const SizedBox(height: 16),
        if (!_ready)
          Align(
            alignment: Alignment.centerLeft,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: _ink, foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: _busy ? null : () => _openStripe(),
              icon: const Icon(Icons.add),
              label: Text(_started ? 'Continuer ma méthode' : 'Ajouter une méthode', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
        if (!_ready)
          const Padding(
            padding: EdgeInsets.only(top: 10),
            child: Text('Ton compte bancaire est enregistré sur la page sécurisée de Stripe. WolyGo ne garde pas tes informations bancaires.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
        if (_ready)
          Column(children: [
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Row(children: [
                Icon(Icons.verified, color: Colors.green),
                SizedBox(width: 8),
                Text('Compte enregistré via Stripe', style: TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ),
            _accountRow('bank', 'Compte bancaire', Icons.account_balance_outlined),
            const SizedBox(height: 8),
            _accountRow('card', 'Carte de débit', Icons.credit_card),
          ]),
        const SizedBox(height: 16),
        ...methods.map((m) {
          final key = '${m['method']}';
          final active = _method == key;
          return GestureDetector(
            onTap: () => setState(() => _method = key),
            child: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: active ? const Color(0xFFEAEAEA) : Colors.white,
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: active ? _ink : const Color(0xFFD9D9D9), width: active ? 1.6 : 1),
              ),
              child: Stack(children: [
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Icon(_methodIcon(key), color: _ink, size: 30),
                  const SizedBox(height: 12),
                  Text(_methodLabel(key), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
                  const SizedBox(height: 4),
                  Text(_methodDesc(key), style: const TextStyle(fontSize: 16, color: Colors.black54)),
                  const SizedBox(height: 10),
                  Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(_money(m['fee']), style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: _ink)),
                    const SizedBox(width: 6),
                    const Padding(padding: EdgeInsets.only(bottom: 3), child: Text('/ virement', style: TextStyle(fontSize: 15, color: Colors.black54))),
                  ]),
                  if (active && _ready) ..._payoutInline(),
                ]),
                if (active) const Positioned(right: 0, top: 0, child: Icon(Icons.check, color: _ink)),
              ]),
            ),
          );
        }),
        if (methods.isEmpty) const Text('Aucune méthode de paiement n\'est disponible pour le moment.'),
      ]),
    );
  }

  Widget _accountRow(String type, String title, IconData icon) {
    final list = _accounts.where((a) => '${a['type']}' == type).toList();
    final text = list.isEmpty
        ? 'Non ajouté'
        : list.map((a) => '${a['name'] != null && '${a['name']}'.isNotEmpty ? '${a['name']} ' : ''}•••• ${a['last4']}').join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(border: Border.all(color: const Color(0xFFD9D9D9)), borderRadius: BorderRadius.circular(18)),
      child: Row(children: [
        Icon(icon, color: _ink),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          Text(text, style: const TextStyle(fontSize: 13, color: Colors.black54)),
        ])),
        TextButton(
          onPressed: _busy ? null : () => _openStripe(manage: true),
          child: Text(list.isEmpty ? 'Ajouter' : 'Modifier'),
        ),
      ]),
    );
  }

  List<Widget> _payoutInline() {
    final min = _num(_data?['settings']?['min_payout']);
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final sel = _enabledMethods().firstWhere((m) => m['method'] == _method, orElse: () => <String, dynamic>{});
    final fee = _num(sel['fee']);
    final net = amount - fee;
    final balance = _num(_data?['balance']);
    final acct = _accountFor(_method);
    if (_accounts.isNotEmpty && acct == null) {
      final isInstant = _method == 'instant';
      return [
        const SizedBox(height: 14),
        const Divider(height: 1),
        const SizedBox(height: 14),
        Text(
          isInstant
              ? 'Pour le versement instantané, ajoute ta carte de débit (numéro de carte, expiration et code de sécurité).'
              : 'Pour ce versement, ajoute ton compte bancaire (numéro d\'institution, numéro de transit et numéro de compte).',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: _ink, foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            ),
            onPressed: _busy ? null : () => _openStripe(manage: true),
            icon: const Icon(Icons.add),
            label: Text(isInstant ? 'Ajouter une carte de débit' : 'Ajouter un compte bancaire', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ];
    }
    return [
      const SizedBox(height: 14),
      const Divider(height: 1),
      const SizedBox(height: 14),
      if (acct != null) Text('Versé sur: ${acct['label']}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      if (acct != null) const SizedBox(height: 4),
      Text('Minimum ${_money(min)} · solde disponible ${_money(balance)}', style: const TextStyle(fontSize: 13, color: Colors.black54)),
      const SizedBox(height: 10),
      TextField(
        controller: _amountController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Montant à retirer', suffixText: '\$',
          filled: true, fillColor: Colors.white,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onChanged: (_) => setState(() {}),
      ),
      const SizedBox(height: 10),
      Text(amount <= 0
              ? 'Entre le montant que tu veux retirer.'
              : (net > 0 ? 'Tu recevras ${_money(net)} (frais ${_money(fee)}).' : 'Le montant doit couvrir les frais (${_money(fee)}).'),
          style: const TextStyle(fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      SizedBox(
        width: double.infinity,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: _ink, foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: (_busy || net <= 0 || amount < min || amount > balance) ? null : _requestPayout,
          icon: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Icon(Icons.arrow_downward),
          label: Text(amount > 0 ? 'Retirer ${_money(amount)}' : 'Retirer', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
        ),
      ),
      if (amount > balance && amount > 0)
        const Padding(padding: EdgeInsets.only(top: 8), child: Text('Le montant dépasse ton solde disponible.', style: TextStyle(color: Colors.red, fontSize: 13))),
    ];
  }

  Widget _payoutsList() {
    final list = (_data?['payouts'] as List?) ?? [];
    return _box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Mes retraits', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 8),
        if (list.isEmpty) const Text('Aucun retrait pour le moment.', style: TextStyle(color: Colors.black54)),
        ...list.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_money(p['amount'])} — ${_methodLabel('${p['method']}')}'),
              subtitle: Text('Reçu: ${_money(p['net'])} · frais ${_money(p['fee'])}'),
              trailing: Text(_statusLabel('${p['status']}'), style: const TextStyle(fontWeight: FontWeight.w600)),
            )),
      ]),
    );
  }

  Widget _ledgerList() {
    final list = (_data?['ledger'] as List?) ?? [];
    return _box(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('Historique', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: _ink)),
        const SizedBox(height: 8),
        if (list.isEmpty) const Text('Aucun mouvement pour le moment.', style: TextStyle(color: Colors.black54)),
        ...list.map((e) {
          final amt = _num(e['amount']);
          final created = '${e['created_at'] ?? ''}';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${e['note'] ?? ''}'),
            subtitle: Text(created.length >= 10 ? created.substring(0, 10) : created),
            trailing: Text('${amt >= 0 ? '+' : ''}${_money(amt)}',
                style: TextStyle(fontWeight: FontWeight.w700, color: amt >= 0 ? Colors.green : Colors.red)),
          );
        }),
      ]),
    );
  }
}
