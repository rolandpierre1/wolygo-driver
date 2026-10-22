import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ride_sharing_user_app/common_widgets/app_bar_widget.dart';
import 'package:ride_sharing_user_app/data/api_client.dart';
import 'package:ride_sharing_user_app/helper/display_helper.dart';
import 'package:ride_sharing_user_app/util/dimensions.dart';
import 'package:ride_sharing_user_app/util/styles.dart';
import 'package:url_launcher/url_launcher.dart';

/// Portefeuille WolyGo: solde, profil de paiement Stripe, retraits, historique.
class WolygoWalletScreen extends StatefulWidget {
  const WolygoWalletScreen({super.key});

  @override
  State<WolygoWalletScreen> createState() => _WolygoWalletScreenState();
}

class _WolygoWalletScreenState extends State<WolygoWalletScreen> with WidgetsBindingObserver {
  bool _loading = true;
  bool _busy = false;
  String? _error;
  Map<String, dynamic>? _data;
  String _method = 'weekly';
  final TextEditingController _amountController = TextEditingController();
  bool _waitingStripe = false;

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
    // Retour de la page Stripe: on revérifie le statut du profil.
    if (state == AppLifecycleState.resumed && _waitingStripe) {
      _waitingStripe = false;
      _refreshStripeThenLoad();
    }
  }

  double _num(dynamic v) => v is num ? v.toDouble() : double.tryParse('${v ?? 0}') ?? 0;
  String _money(dynamic v) => '${_num(v).toStringAsFixed(2)} \$';

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

  Future<void> _refreshStripeThenLoad() async {
    await _api.postData('/api/driver/wallet/stripe/refresh', {});
    await _load(silent: true);
  }

  Future<void> _openStripe() async {
    setState(() => _busy = true);
    final res = await _api.postData('/api/driver/wallet/stripe/onboarding', {});
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.statusCode == 200 && res.body is Map && res.body['data']?['url'] != null) {
      _waitingStripe = true;
      await launchUrl(Uri.parse(res.body['data']['url']), mode: LaunchMode.externalApplication);
    } else {
      showCustomSnackBar(_messageOf(res, 'Impossible d\'ouvrir le profil de paiement.'));
    }
  }

  String _messageOf(dynamic res, String fallback) {
    try {
      if (res.body is Map && res.body['message'] != null) return '${res.body['message']}';
    } catch (_) {}
    return fallback;
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

  String _methodLabel(String m) => {'weekly': 'Hebdomadaire (lundi)', 'next_day': 'Lendemain ouvré', 'instant': 'Instantané (carte)'}[m] ?? m;

  String _statusLabel(String s) => {'pending': 'En attente', 'processing': 'En cours', 'paid': 'Envoyé', 'failed': 'Échoué'}[s] ?? s;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).primaryColor;
    return Scaffold(
      appBar: AppBarWidget(title: 'Portefeuille', showBackButton: true, regularAppbar: true),
      body: _loading
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
                  child: ListView(padding: const EdgeInsets.all(Dimensions.paddingSizeDefault), children: [
                    _balanceCard(primary),
                    const SizedBox(height: 16),
                    _stripeCard(primary),
                    const SizedBox(height: 16),
                    if (_data?['stripe']?['payouts_enabled'] == true) _payoutCard(primary),
                    if (_data?['stripe']?['payouts_enabled'] == true) const SizedBox(height: 16),
                    _payoutsList(),
                    const SizedBox(height: 16),
                    _ledgerList(),
                    const SizedBox(height: 40),
                  ]),
                ),
    );
  }

  Widget _card({required Widget child}) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Theme.of(context).hintColor.withOpacity(.25)),
        ),
        child: child,
      );

  Widget _balanceCard(Color primary) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: primary, borderRadius: BorderRadius.circular(16)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Solde disponible', style: textRegular.copyWith(color: Colors.white70)),
          const SizedBox(height: 6),
          Text(_money(_data?['balance']), style: textBold.copyWith(color: Colors.white, fontSize: 32)),
          const SizedBox(height: 6),
          Text('Ta part est ajoutée après chaque course terminée et payée en ligne.',
              style: textRegular.copyWith(color: Colors.white70, fontSize: 12)),
        ]),
      );

  Widget _stripeCard(Color primary) {
    final stripe = Map<String, dynamic>.from(_data?['stripe'] ?? {});
    final ready = stripe['payouts_enabled'] == true;
    final started = stripe['connected'] == true;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(ready ? Icons.verified : Icons.account_balance, color: ready ? Colors.green : primary),
          const SizedBox(width: 8),
          Expanded(child: Text('Profil de paiement', style: textSemiBold.copyWith(fontSize: 16))),
        ]),
        const SizedBox(height: 8),
        Text(
          ready
              ? 'Ton profil est prêt. Tes retraits sont envoyés vers ton compte bancaire via Stripe.'
              : started
                  ? 'Ton profil n\'est pas encore terminé. Complète-le pour pouvoir retirer ton argent.'
                  : 'Crée ton profil de paiement (compte bancaire, identité) sur la page sécurisée de Stripe. WolyGo ne garde pas tes informations bancaires.',
          style: textRegular,
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: _busy ? null : _openStripe,
            child: Text(ready ? 'Modifier mon profil de paiement' : started ? 'Continuer mon profil de paiement' : 'Créer mon profil de paiement'),
          ),
        ),
      ]),
    );
  }

  Widget _payoutCard(Color primary) {
    final methods = _enabledMethods();
    final min = _num(_data?['settings']?['min_payout']);
    final amount = double.tryParse(_amountController.text.replaceAll(',', '.')) ?? 0;
    final sel = methods.firstWhere((m) => m['method'] == _method, orElse: () => <String, dynamic>{});
    final fee = _num(sel['fee']);
    final net = amount - fee;
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Retirer mon argent', style: textSemiBold.copyWith(fontSize: 16)),
        const SizedBox(height: 4),
        Text('Minimum ${_money(min)}', style: textRegular.copyWith(fontSize: 12)),
        const SizedBox(height: 12),
        TextField(
          controller: _amountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Montant à retirer', suffixText: '\$', border: OutlineInputBorder()),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: 8),
        if (methods.isEmpty) const Text('Aucune méthode de retrait n\'est disponible pour le moment.'),
        ...methods.map((m) => RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: m['method'],
              groupValue: _method,
              onChanged: (v) => setState(() => _method = v ?? _method),
              title: Text(_methodLabel(m['method'])),
              subtitle: Text('Frais ${_money(m['fee'])}'),
            )),
        if (methods.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(net > 0 ? 'Tu recevras ${_money(net)} (frais ${_money(fee)}).' : 'Le montant doit couvrir les frais (${_money(fee)}).',
              style: textMedium),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: (_busy || net <= 0 || amount < min) ? null : _requestPayout,
              child: _busy ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Retirer'),
            ),
          ),
        ],
      ]),
    );
  }

  Widget _payoutsList() {
    final list = (_data?['payouts'] as List?) ?? [];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Mes retraits', style: textSemiBold.copyWith(fontSize: 16)),
        const SizedBox(height: 8),
        if (list.isEmpty) const Text('Aucun retrait pour le moment.'),
        ...list.map((p) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('${_money(p['amount'])} — ${_methodLabel('${p['method']}')}'),
              subtitle: Text('Reçu: ${_money(p['net'])} · frais ${_money(p['fee'])}'),
              trailing: Text(_statusLabel('${p['status']}'), style: textMedium),
            )),
      ]),
    );
  }

  Widget _ledgerList() {
    final list = (_data?['ledger'] as List?) ?? [];
    return _card(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Historique', style: textSemiBold.copyWith(fontSize: 16)),
        const SizedBox(height: 8),
        if (list.isEmpty) const Text('Aucun mouvement pour le moment.'),
        ...list.map((e) {
          final amt = _num(e['amount']);
          final created = '${e['created_at'] ?? ''}';
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text('${e['note'] ?? ''}'),
            subtitle: Text(created.length >= 10 ? created.substring(0, 10) : created),
            trailing: Text('${amt >= 0 ? '+' : ''}${_money(amt)}',
                style: textSemiBold.copyWith(color: amt >= 0 ? Colors.green : Colors.red)),
          );
        }),
      ]),
    );
  }
}
