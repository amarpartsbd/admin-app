import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'b2b_client_screen.dart';

class B2bScreen extends StatefulWidget {
  const B2bScreen({super.key});
  @override
  State<B2bScreen> createState() => _B2bScreenState();
}

class _B2bScreenState extends State<B2bScreen> {
  final _search = TextEditingController();
  Future<List<Map<String, dynamic>>>? _future;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().api.get('/b2b/clients', query: {
      'per_page': 50,
      if (_query.isNotEmpty) 'search': _query,
    }).then((res) => (res['data'] as List).cast<Map<String, dynamic>>());
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Scaffold(
      appBar: AppBar(
        title: const Text('B2B Clients'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(hintText: 'Search client…', prefixIcon: const Icon(Icons.search), isDense: true,
                suffixIcon: _query.isNotEmpty ? IconButton(icon: const Icon(Icons.close), onPressed: () { _search.clear(); setState(() { _query = ''; _load(); }); }) : null),
              onSubmitted: (v) => setState(() { _query = v.trim(); _load(); }),
            ),
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => setState(_load),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());
            if (snap.hasError) return ListView(children: [const SizedBox(height: 140), Center(child: Text(snap.error.toString()))]);
            final clients = snap.data ?? [];
            if (clients.isEmpty) return ListView(children: const [SizedBox(height: 160), Center(child: Text('No clients found.', style: TextStyle(color: Color(0xFF64748B))))]);
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: clients.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final c = clients[i];
                final due = (c['due'] ?? 0) as num;
                final name = (c['company_name'] ?? 'Client').toString();
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(16),
                    onTap: () => Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => B2bClientScreen(clientId: c['id'] as int, name: c['company_name'] ?? ''),
                    )).then((_) => setState(_load)),
                    child: Ink(
                      padding: const EdgeInsets.all(13),
                      decoration: softCard(radius: 16),
                      child: Row(children: [
                        Container(
                          height: 44, width: 44,
                          decoration: BoxDecoration(color: const Color(0xFFEDE9FE), borderRadius: BorderRadius.circular(12)),
                          alignment: Alignment.center,
                          child: Text(name.substring(0, 1).toUpperCase(), style: const TextStyle(color: Color(0xFF6D28D9), fontWeight: FontWeight.w800, fontSize: 17)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: kInk)),
                          const SizedBox(height: 3),
                          Row(children: [
                            Icon(Icons.person_outline_rounded, size: 13, color: kFaint),
                            const SizedBox(width: 3),
                            Flexible(child: Text('${c['contact_person'] ?? '—'}', maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: kMuted))),
                            const SizedBox(width: 8),
                            Icon(Icons.receipt_long_rounded, size: 13, color: kFaint),
                            const SizedBox(width: 3),
                            Text('${c['orders_count'] ?? 0}', style: const TextStyle(fontSize: 12.5, color: kMuted)),
                          ]),
                        ])),
                        const SizedBox(width: 8),
                        if (due > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(color: kDanger.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(10)),
                            child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                              const Text('DUE', style: TextStyle(fontSize: 8.5, color: kDanger, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
                              Text(money(cur, due), style: const TextStyle(color: kDanger, fontWeight: FontWeight.w800, fontSize: 13)),
                            ]),
                          )
                        else
                          const Icon(Icons.chevron_right_rounded, color: kFaint),
                      ]),
                    ),
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
