import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../state/app_state.dart';

/// Firebase Phone Auth code entry. Receives the verificationId from the
/// verifyPhoneNumber codeSent callback, verifies the code with Firebase,
/// then exchanges the Firebase ID token for our app session.
class FirebaseOtpScreen extends StatefulWidget {
  const FirebaseOtpScreen({super.key, required this.phone, required this.verificationId});
  final String phone;
  final String verificationId;
  @override
  State<FirebaseOtpScreen> createState() => _FirebaseOtpScreenState();
}

class _FirebaseOtpScreenState extends State<FirebaseOtpScreen> {
  final _code = TextEditingController();
  bool _loading = false;
  String? _error;

  Future<void> _verify() async {
    final code = _code.text.trim();
    if (code.length < 6) {
      setState(() => _error = 'Enter the 6-digit code.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final cred = PhoneAuthProvider.credential(verificationId: widget.verificationId, smsCode: code);
      final userCred = await FirebaseAuth.instance.signInWithCredential(cred);
      final idToken = await userCred.user?.getIdToken();
      if (idToken == null) throw Exception('Could not get login token.');
      await context.read<AppState>().firebaseLogin(idToken);
      // AppState flips to loggedIn → root becomes HomeScreen; drop this route.
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on FirebaseAuthException catch (e) {
      setState(() { _error = e.message ?? 'Invalid code.'; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            const SizedBox(height: 12),
            Text('Enter the 6-digit code sent to\n${widget.phone}',
                textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFF64748B), height: 1.5)),
            const SizedBox(height: 28),
            TextField(
              controller: _code,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 6,
              style: const TextStyle(fontSize: 26, letterSpacing: 8, fontWeight: FontWeight.w700),
              decoration: const InputDecoration(hintText: '••••••', counterText: ''),
              onSubmitted: (_) => _verify(),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Color(0xFFDC2626))),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _loading ? null : _verify,
              child: _loading
                  ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Verify & Sign in'),
            ),
          ]),
        ),
      ),
    );
  }
}
