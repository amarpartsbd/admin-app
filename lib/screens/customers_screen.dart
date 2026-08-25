import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class CustomersScreen extends StatefulWidget {
  const CustomersScreen({super.key});
  @override
  State<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends State<CustomersScreen> {
  final _search = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/customers', query: {
      'per_page': 50,
      if (_query.isNotEmpty) 'search': _query,
    }).then((r) => (r['data'] as List).cast<Map<String, dynamic>>());
  }

  Future<void> _create() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewCustomerSheet(),
    );
    if (saved == true) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(hintText: 'Search name / phone…', prefixIcon: const Icon(Icons.search), isDense: true,
                suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); setState(() { _query = ''; _load(); }); }) : null),
              onSubmitted: (v) => setState(() { _query = v.trim(); _load(); }),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(onPressed: _create, icon: const Icon(Icons.person_add), label: const Text('New')),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ListView(children: [const SizedBox(height: 140), Center(child: Text(snap.error.toString()))]);
            final list = snap.data ?? [];
            if (list.isEmpty) return ListView(children: const [SizedBox(height: 160), Center(child: Text('No customers.', style: TextStyle(color: Color(0xFF64748B))))]);
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, i) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = list[i];
                return Card(
                  margin: EdgeInsets.zero,
                  child: ListTile(
                    leading: CircleAvatar(backgroundColor: const Color(0xFFE0E7FF), child: Text((c['name'] ?? '?').toString().substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFF4F46E5), fontWeight: FontWeight.w700))),
                    title: Text(c['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${c['phone'] ?? ''}${c['city'] != null ? '  ·  ${c['city']}' : ''}'),
                    trailing: Text('${c['orders_count'] ?? 0} orders', style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NewCustomerSheet extends StatefulWidget {
  const _NewCustomerSheet();
  @override
  State<_NewCustomerSheet> createState() => _NewCustomerSheetState();
}

class _NewCustomerSheetState extends State<_NewCustomerSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _city = TextEditingController();
  bool _saving = false;
  String? _error;

  Future<void> _save() async {
    if (_name.text.trim().isEmpty || _phone.text.trim().isEmpty) {
      setState(() => _error = 'Name and phone are required.');
      return;
    }
    setState(() { _saving = true; _error = null; });
    try {
      await context.read<AppState>().api.post('/customers', body: {
        'name': _name.text.trim(), 'phone': _phone.text.trim(),
        if (_city.text.trim().isNotEmpty) 'city': _city.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
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
          const Text('New Customer', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name')),
          const SizedBox(height: 10),
          TextField(controller: _phone, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Phone')),
          const SizedBox(height: 10),
          TextField(controller: _city, decoration: const InputDecoration(labelText: 'City (optional)')),
          if (_error != null) ...[const SizedBox(height: 10), Text(_error!, style: const TextStyle(color: Color(0xFFDC2626)))],
          const SizedBox(height: 16),
          FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Saving…' : 'Save Customer')),
        ]),
      ),
    );
  }
}
