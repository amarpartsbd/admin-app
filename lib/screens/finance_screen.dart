import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Map<String, dynamic>? _summary;
  List<Map<String, dynamic>> _txns = [];
  bool _loading = true;
  String _filter = ''; // '', 'income', 'expense'

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final api = context.read<AppState>().api;
      final s = await api.get('/finance/summary', query: {'range': 'month'});
      final t = await api.get('/finance/transactions', query: {'per_page': 50, if (_filter.isNotEmpty) 'type': _filter});
      _summary = Map<String, dynamic>.from(s['summary']);
      _txns = (t['data'] as List).cast<Map<String, dynamic>>();
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _add(String type) async {
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true, builder: (_) => _TxnSheet(type: type));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    final canManage = state.can('finance.manage');
    return Scaffold(
      appBar: AppBar(title: const Text('Finance'), actions: [
        IconButton(icon: const Icon(Icons.request_quote_outlined), tooltip: 'Payables',
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PayablesScreen()))),
      ]),
      floatingActionButton: canManage
          ? Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              FloatingActionButton.extended(heroTag: 'inc', backgroundColor: const Color(0xFF059669), onPressed: () => _add('income'), icon: const Icon(Icons.add), label: const Text('Income')),
              const SizedBox(width: 10),
              FloatingActionButton.extended(heroTag: 'exp', backgroundColor: const Color(0xFFDC2626), onPressed: () => _add('expense'), icon: const Icon(Icons.remove), label: const Text('Expense')),
            ])
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(padding: const EdgeInsets.all(16), children: [
                const Text('This Month', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(child: _stat('Income', money(cur, (_summary?['income'] ?? 0) as num), const Color(0xFF059669))),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Expense', money(cur, (_summary?['expense'] ?? 0) as num), const Color(0xFFDC2626))),
                  const SizedBox(width: 10),
                  Expanded(child: _stat('Net', money(cur, (_summary?['net_cashflow'] ?? 0) as num), const Color(0xFF2563EB))),
                ]),
                const SizedBox(height: 16),
                Row(children: [
                  _chip('All', ''), const SizedBox(width: 8),
                  _chip('Income', 'income'), const SizedBox(width: 8),
                  _chip('Expense', 'expense'),
                ]),
                const SizedBox(height: 8),
                for (final t in _txns) _txnTile(t, cur),
                const SizedBox(height: 80),
              ]),
            ),
    );
  }

  Widget _chip(String label, String v) => ChoiceChip(label: Text(label), selected: _filter == v, onSelected: (_) { setState(() => _filter = v); _load(); });

  Widget _stat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: color)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Color(0xFF64748B))),
        ]),
      );

  Widget _txnTile(Map<String, dynamic> t, String cur) {
    final isIncome = t['type'] == 'income';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: (isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626)).withValues(alpha: 0.12),
          child: Icon(isIncome ? Icons.south_west : Icons.north_east, color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626), size: 20),
        ),
        title: Text(t['category'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text('${t['payee'] ?? t['description'] ?? ''}  ·  ${t['date'] ?? ''}', maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${isIncome ? '+' : '−'}${money(cur, (t['amount'] ?? 0) as num)}', style: TextStyle(fontWeight: FontWeight.w700, color: isIncome ? const Color(0xFF059669) : const Color(0xFFDC2626))),
          if (t['status'] != 'approved') Text(t['status'] ?? '', style: const TextStyle(fontSize: 11, color: Color(0xFFEA580C))),
        ]),
      ),
    );
  }
}

class _TxnSheet extends StatefulWidget {
  const _TxnSheet({required this.type});
  final String type;
  @override
  State<_TxnSheet> createState() => _TxnSheetState();
}

class _TxnSheetState extends State<_TxnSheet> {
  final _category = TextEditingController();
  final _amount = TextEditingController();
  final _payee = TextEditingController();
  final _desc = TextEditingController();
  List<Map<String, dynamic>> _employees = [];
  int? _employeeId;
  bool _saving = false;
  String? _error;

  bool get _isIncome => widget.type == 'income';

  @override
  void initState() {
    super.initState();
    if (!_isIncome && context.read<AppState>().can('finance.view')) _loadEmployees();
  }

  Future<void> _loadEmployees() async {
    try {
      final r = await context.read<AppState>().api.get('/employees', query: {'per_page': 100});
      if (mounted) setState(() => _employees = (r['data'] as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  Future<void> _save() async {
    if (_category.text.trim().isEmpty || (double.tryParse(_amount.text.trim()) ?? 0) <= 0) {
      setState(() => _error = 'Category and a valid amount are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await context.read<AppState>().api.post('/finance/${widget.type}', body: {
        'category': _category.text.trim(),
        'amount': double.parse(_amount.text.trim()),
        if (_employeeId != null) 'employee_id': _employeeId,
        if (_employeeId == null && _payee.text.trim().isNotEmpty) 'payee': _payee.text.trim(),
        if (_desc.text.trim().isNotEmpty) 'description': _desc.text.trim(),
        'transaction_date': DateTime.now().toIso8601String().substring(0, 10),
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Saved.')));
      }
    } catch (e) {
      setState(() { _error = e.toString(); _saving = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(_isIncome ? 'Add Income' : 'Add Expense', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          TextField(controller: _category, decoration: const InputDecoration(labelText: 'Category')),
          const SizedBox(height: 10),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 10),
          if (!_isIncome && _employees.isNotEmpty) ...[
            DropdownButtonFormField<int?>(
              initialValue: _employeeId,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Payee'),
              items: [
                const DropdownMenuItem<int?>(value: null, child: Text('— Other / manual —')),
                ..._employees.map((e) => DropdownMenuItem<int?>(value: e['id'] as int, child: Text('👤 ${e['name']}', overflow: TextOverflow.ellipsis))),
              ],
              onChanged: (v) => setState(() => _employeeId = v),
            ),
            if (_employeeId != null)
              const Padding(padding: EdgeInsets.only(top: 6, left: 4), child: Text('Will be added to this employee\'s profile.', style: TextStyle(fontSize: 11.5, color: kSuccess))),
            const SizedBox(height: 10),
          ],
          if (_employeeId == null) ...[
            TextField(controller: _payee, decoration: const InputDecoration(labelText: 'Payee (optional)')),
            const SizedBox(height: 10),
          ],
          TextField(controller: _desc, decoration: const InputDecoration(labelText: 'Description (optional)')),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: kDanger))],
          const SizedBox(height: 16),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _isIncome ? kSuccess : kDanger),
            onPressed: _saving ? null : _save,
            child: Text(_saving ? 'Saving…' : (_isIncome ? 'Record Income' : 'Record Expense')),
          ),
        ]),
      ),
    );
  }
}

class PayablesScreen extends StatefulWidget {
  const PayablesScreen({super.key});
  @override
  State<PayablesScreen> createState() => _PayablesScreenState();
}

class _PayablesScreenState extends State<PayablesScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().api.get('/finance/payables', query: {'per_page': 50}).then((r) => (r['data'] as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Payables')),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
          final list = snap.data ?? [];
          if (list.isEmpty) return const Center(child: Text('No payables.', style: TextStyle(color: Color(0xFF64748B))));
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, i) => const SizedBox(height: 8),
            itemBuilder: (context, i) {
              final p = list[i];
              return Card(margin: EdgeInsets.zero, child: ListTile(
                title: Text(p['party'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text('${p['reference'] ?? ''}  ·  due ${p['due_date'] ?? '—'}  ·  ${p['status']}'),
                trailing: Text(money(cur, (p['outstanding'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700, color: Color(0xFFDC2626))),
              ));
            },
          );
        },
      ),
    );
  }
}
