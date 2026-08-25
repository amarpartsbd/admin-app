import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});
  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  Future<List<Map<String, dynamic>>>? _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/employees', query: {'per_page': 100}).then((r) => (r['data'] as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(title: const Text('Employees / Payroll')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ListView(children: [const SizedBox(height: 140), Center(child: Text(snap.error.toString()))]);
            final list = snap.data ?? [];
            if (list.isEmpty) return ListView(children: const [SizedBox(height: 160), Center(child: Text('No employees.', style: TextStyle(color: Color(0xFF64748B))))]);
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final e = list[i];
                return Card(margin: EdgeInsets.zero, child: ListTile(
                  leading: CircleAvatar(backgroundColor: const Color(0xFFEDE9FE), child: Text((e['name'] ?? '?').toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w700))),
                  title: Text(e['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text('${e['designation'] ?? '—'}  ·  ${money(cur, (e['monthly_salary'] ?? 0) as num)}/mo'),
                  trailing: e['is_active'] == true ? null : const Text('inactive', style: TextStyle(fontSize: 11, color: Color(0xFF94A3B8))),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => EmployeeDetailScreen(id: e['id'] as int, name: e['name'] ?? ''))),
                ));
              },
            );
          },
        ),
      ),
    );
  }
}

class EmployeeDetailScreen extends StatefulWidget {
  const EmployeeDetailScreen({super.key, required this.id, required this.name});
  final int id;
  final String name;
  @override
  State<EmployeeDetailScreen> createState() => _EmployeeDetailScreenState();
}

class _EmployeeDetailScreenState extends State<EmployeeDetailScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      _data = Map<String, dynamic>.from(await context.read<AppState>().api.get('/employees/${widget.id}'));
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pay() async {
    final emp = _data!['employee'] as Map<String, dynamic>;
    final ok = await showModalBottomSheet<bool>(
      context: context, isScrollControlled: true,
      builder: (_) => _SalarySheet(employeeId: widget.id, salary: (emp['monthly_salary'] ?? 0) as num));
    if (ok == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final cur = state.currency;
    final emp = _data?['employee'] as Map<String, dynamic>?;
    final pays = (_data?['salary_payments'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      floatingActionButton: (emp != null && state.can('finance.manage'))
          ? FloatingActionButton.extended(onPressed: _pay, icon: const Icon(Icons.payments), label: const Text('Pay Salary'))
          : null,
      body: _loading || emp == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(padding: const EdgeInsets.all(16), children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14), border: Border.all(color: const Color(0xFFE2E8F0))),
                child: Column(children: [
                  _row('Designation', emp['designation']?.toString() ?? '—'),
                  _row('Phone', emp['phone']?.toString() ?? '—'),
                  _row('Monthly salary', money(cur, (emp['monthly_salary'] ?? 0) as num)),
                  _row('Joined', emp['joining_date']?.toString() ?? '—'),
                ]),
              ),
              const SizedBox(height: 16),
              const Text('Salary Payments', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF334155))),
              const SizedBox(height: 8),
              if (pays.isEmpty) const Padding(padding: EdgeInsets.all(12), child: Text('No payments yet.', style: TextStyle(color: Color(0xFF94A3B8)))),
              for (final p in pays)
                Card(margin: const EdgeInsets.only(bottom: 8), child: ListTile(
                  dense: true,
                  title: Text(money(cur, (p['amount'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('${p['period'] ?? ''}  ·  ${p['method'] ?? ''}  ·  ${p['status'] ?? ''}'),
                  trailing: Text(p['paid_on']?.toString() ?? '', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                )),
              const SizedBox(height: 80),
            ]),
    );
  }

  Widget _row(String l, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(l, style: const TextStyle(color: Color(0xFF64748B))),
          Text(v, style: const TextStyle(fontWeight: FontWeight.w600)),
        ]),
      );
}

class _SalarySheet extends StatefulWidget {
  const _SalarySheet({required this.employeeId, required this.salary});
  final int employeeId;
  final num salary;
  @override
  State<_SalarySheet> createState() => _SalarySheetState();
}

class _SalarySheetState extends State<_SalarySheet> {
  late final TextEditingController _amount = TextEditingController(text: widget.salary.toStringAsFixed(0));
  String _method = 'cash';
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    final amt = double.tryParse(_amount.text.trim()) ?? 0;
    if (amt <= 0) { setState(() => _error = 'Enter a valid amount.'); return; }
    setState(() { _saving = true; _error = null; });
    try {
      final res = await context.read<AppState>().api.post('/employees/${widget.employeeId}/salary', body: {
        'amount': amt, 'period': DateTime.now().toIso8601String().substring(0, 10), 'payment_method': _method,
      });
      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res['message']?.toString() ?? 'Paid.')));
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
          const Text('Pay Salary', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: _amount, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount')),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: _method,
            decoration: const InputDecoration(labelText: 'Method'),
            items: const [
              DropdownMenuItem(value: 'cash', child: Text('Cash')),
              DropdownMenuItem(value: 'bkash', child: Text('bKash')),
              DropdownMenuItem(value: 'bank_transfer', child: Text('Bank Transfer')),
            ],
            onChanged: (v) => setState(() => _method = v ?? 'cash'),
          ),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Paying…' : 'Confirm Payment')),
        ]),
      ),
    );
  }
}
