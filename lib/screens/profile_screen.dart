import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final user = state.user ?? {};
    final company = state.company ?? {};
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Center(child: CircleAvatar(radius: 40, backgroundColor: state.brandColor,
          child: Text((user['name']?.toString() ?? '?').substring(0, 1).toUpperCase(),
              style: const TextStyle(fontSize: 30, color: Colors.white, fontWeight: FontWeight.w700)))),
        const SizedBox(height: 12),
        Center(child: Text(user['name']?.toString() ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
        Center(child: Text(user['phone']?.toString() ?? user['email']?.toString() ?? '', style: const TextStyle(color: Color(0xFF64748B)))),
        const SizedBox(height: 24),
        _tile('Company', company['name']?.toString() ?? '—', Icons.business),
        _tile('Role', ((user['roles'] as List?)?.join(', ') ?? '—'), Icons.badge_outlined),
        _tile('Email', user['email']?.toString() ?? '—', Icons.mail_outline),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFDC2626)),
          onPressed: () => context.read<AppState>().logout(),
          icon: const Icon(Icons.logout),
          label: const Text('Log out'),
        ),
      ]),
    );
  }

  Widget _tile(String label, String value, IconData icon) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(icon, color: const Color(0xFF64748B)),
          title: Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B))),
          subtitle: Text(value, style: const TextStyle(fontSize: 15, color: Color(0xFF0F172A), fontWeight: FontWeight.w600)),
        ),
      );
}
