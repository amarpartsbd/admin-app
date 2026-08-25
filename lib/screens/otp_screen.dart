import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';
import '../theme.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({super.key, required this.phone});
  final String phone;
  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  bool _resending = false;
  String? _error;

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 4) {
      setState(() => _error = 'Enter the code you received.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppState>().verifyOtp(widget.phone, code);
      // AppState flips to loggedIn (root → HomeScreen); drop this pushed route.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<void> _resend() async {
    setState(() { _resending = true; _error = null; });
    try {
      await context.read<AppState>().requestOtp(widget.phone);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A new code has been sent.')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<AppState>().brandColor;
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 20),
              Center(
                child: Container(
                  height: 72, width: 72,
                  decoration: BoxDecoration(color: brand.withValues(alpha: 0.10), borderRadius: BorderRadius.circular(20)),
                  child: Icon(Icons.sms_rounded, color: brand, size: 34),
                ),
              ),
              const SizedBox(height: 20),
              const Text('Enter verification code', textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: kInk)),
              const SizedBox(height: 6),
              Text('Sent to ${widget.phone}', textAlign: TextAlign.center,
                  style: const TextStyle(color: kMuted, height: 1.4)),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: softCard(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 28, letterSpacing: 10, fontWeight: FontWeight.w800, color: kInk),
                    decoration: const InputDecoration(hintText: '••••••', counterText: ''),
                    maxLength: 6,
                    onSubmitted: (_) => _verify(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: kDanger, fontSize: 12.5)),
                  ],
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _verify,
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Verify & Sign in'),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? 'Sending…' : 'Resend code'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
