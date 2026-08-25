import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

/// Bottom-sheet product/variant search. Returns the picked variant map.
class ProductPicker extends StatefulWidget {
  const ProductPicker({super.key});
  @override
  State<ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<ProductPicker> {
  final _search = TextEditingController();
  List<Map<String, dynamic>> _results = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  Future<void> _load(String s) async {
    setState(() => _loading = true);
    try {
      final res = await context.read<AppState>().api.get('/products/search', query: {if (s.isNotEmpty) 'search': s});
      setState(() => _results = (res['data'] as List).cast<Map<String, dynamic>>());
    } catch (_) {} finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cur = context.watch<AppState>().currency;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _search,
              autofocus: true,
              decoration: const InputDecoration(hintText: 'Search product…', prefixIcon: Icon(Icons.search)),
              onChanged: (v) => _load(v.trim()),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : ListView.separated(
                    itemCount: _results.length,
                    separatorBuilder: (_, i) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final v = _results[i];
                      final stock = (v['stock'] ?? 0) as num;
                      return ListTile(
                        title: Text(v['product_name'] ?? ''),
                        subtitle: Text('${v['sku'] ?? ''}  ·  ${[v['color'], v['size']].where((e) => e != null).join(' ')}  ·  stock $stock'),
                        trailing: Text(money(cur, (v['unit_price'] ?? 0) as num), style: const TextStyle(fontWeight: FontWeight.w700)),
                        onTap: () => Navigator.pop(context, v),
                      );
                    },
                  ),
          ),
        ]),
      ),
    );
  }
}
