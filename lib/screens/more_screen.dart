import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'customers_screen.dart';
import 'pos_screen.dart';
import 'returns_screen.dart';
import 'products_screen.dart';
import 'inventory_screen.dart';
import 'purchases_screen.dart';
import 'finance_screen.dart';
import 'employees_screen.dart';
import 'reports_screen.dart';
import 'profile_screen.dart';
import 'warehouse_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final tiles = <_Tile>[
      if (state.can('warehouse.pack')) _Tile('Packing', Icons.scale_rounded, const Color(0xFF7C3AED), const WarehouseScreen()),
      if (state.can('orders.create')) _Tile('POS', Icons.point_of_sale, const Color(0xFF059669), const PosScreen()),
      if (state.can('customers.view')) _Tile('Customers', Icons.people_alt, const Color(0xFF2563EB), const CustomersScreen()),
      if (state.can('products.view')) _Tile('Products', Icons.inventory_2, const Color(0xFF0891B2), const ProductsScreen()),
      if (state.can('inventory.view')) _Tile('Inventory', Icons.warehouse, const Color(0xFFCA8A04), const InventoryScreen()),
      if (state.can('purchases.view')) _Tile('Purchases', Icons.shopping_cart, const Color(0xFF475569), const PurchasesScreen()),
      if (state.can('returns.view')) _Tile('Returns', Icons.assignment_return, const Color(0xFFDC2626), const ReturnsScreen()),
      if (state.can('finance.view')) _Tile('Finance', Icons.account_balance_wallet, const Color(0xFF059669), const FinanceScreen()),
      if (state.can('finance.view')) _Tile('Employees', Icons.badge, const Color(0xFF7C3AED), const EmployeesScreen()),
      if (state.can('reports.view')) _Tile('Reports', Icons.bar_chart, const Color(0xFF2563EB), const ReportsScreen()),
      _Tile('Profile', Icons.person, const Color(0xFF64748B), const ProfileScreen()),
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: GridView.count(
        crossAxisCount: 3,
        padding: const EdgeInsets.all(16),
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        children: tiles.map((t) => _tile(context, t)).toList(),
      ),
    );
  }

  Widget _tile(BuildContext context, _Tile t) => InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => t.screen)),
        child: Container(
          decoration: softCard(radius: 18),
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              padding: const EdgeInsets.all(13),
              decoration: BoxDecoration(color: t.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(14)),
              child: Icon(t.icon, color: t.color, size: 26),
            ),
            const SizedBox(height: 10),
            Text(t.label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: kInk)),
          ]),
        ),
      );
}

class _Tile {
  _Tile(this.label, this.icon, this.color, this.screen);
  final String label;
  final IconData icon;
  final Color color;
  final Widget screen;
}
