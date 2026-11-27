import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../config.dart';
import '../state/app_state.dart';
import '../theme.dart';
import 'otp_screen.dart';
import 'firebase_otp_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phone = TextEditingController();
  final _id = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;
  bool _usePassword = false;
  bool _showPassword = false;
  String? _error;

  Future<void> _passwordSubmit() async {
    final id = _id.text.trim();
    if (id.length < 5 || _password.text.isEmpty) {
      setState(() => _error = 'Enter your email (or phone) and password.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await context.read<AppState>().passwordLogin(id, _password.text);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submit() async {
    final phone = _phone.text.trim();
    if (phone.length < 6) {
      setState(() => _error = 'Enter a valid phone number.');
      return;
    }
    setState(() { _loading = true; _error = null; });

    if (context.read<AppState>().useFirebaseLogin) {
      await _firebaseStart(phone);
      return;
    }

    try {
      await context.read<AppState>().requestOtp(phone);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => OtpScreen(phone: phone),
      ));
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Firebase Phone Auth: Google sends the OTP, then codeSent hands us a
  /// verificationId we carry to the code screen.
  Future<void> _firebaseStart(String phone) async {
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _e164(phone),
        timeout: const Duration(seconds: 60),
        verificationCompleted: (_) {},
        verificationFailed: (e) {
          if (mounted) setState(() { _error = e.message ?? 'Verification failed.'; _loading = false; });
        },
        codeSent: (verificationId, _) {
          if (!mounted) return;
          setState(() => _loading = false);
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => FirebaseOtpScreen(phone: phone, verificationId: verificationId),
          ));
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  /// Normalise a Bangladeshi number to E.164 (+880…).
  String _e164(String raw) {
    final d = raw.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('88')) return '+$d';
    if (d.startsWith('0')) return '+880${d.substring(1)}';
    return '+880$d';
  }

  @override
  Widget build(BuildContext context) {
    final brand = context.watch<AppState>().brandColor;
    return Scaffold(
      body: Stack(children: [
        // Brand gradient top
        Container(height: 320, decoration: BoxDecoration(gradient: brandGradient(brand))),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              const SizedBox(height: 40),
              Center(
                child: Container(
                  height: 84, width: 84,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [BoxShadow(color: Color(0x33000000), blurRadius: 24, offset: Offset(0, 10))],
                  ),
                  child: Icon(Icons.storefront_rounded, color: brand, size: 42),
                ),
              ),
              const SizedBox(height: 20),
              Text(AppConfig.appName, textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: Colors.white, letterSpacing: -0.4)),
              const SizedBox(height: 6),
              const Text('Sign in to your workspace', textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              const SizedBox(height: 34),
              // Card
              Container(
                padding: const EdgeInsets.all(22),
                decoration: softCard(),
                child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Mobile OTP'), icon: Icon(Icons.sms_outlined)),
                      ButtonSegment(value: true, label: Text('Password'), icon: Icon(Icons.lock_outline_rounded)),
                    ],
                    selected: {_usePassword},
                    showSelectedIcon: false,
                    onSelectionChanged: (v) => setState(() { _usePassword = v.first; _error = null; }),
                  ),
                  const SizedBox(height: 18),
                  if (!_usePassword) ...[
                    const Text('Mobile number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _phone,
                      keyboardType: TextInputType.phone,
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: 0.3),
                      decoration: const InputDecoration(hintText: '01XXXXXXXXX', prefixIcon: Icon(Icons.phone_iphone_rounded)),
                      onSubmitted: (_) => _submit(),
                    ),
                  ] else ...[
                    const Text('Email or mobile number', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _id,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username, AutofillHints.email],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(hintText: 'you@shop.com or 01XXXXXXXXX', prefixIcon: Icon(Icons.person_outline_rounded)),
                    ),
                    const SizedBox(height: 14),
                    const Text('Password', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: kInk)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _password,
                      obscureText: !_showPassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      decoration: InputDecoration(
                        hintText: 'Your password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          tooltip: _showPassword ? 'Hide password' : 'Show password',
                          icon: Icon(_showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                      onSubmitted: (_) => _passwordSubmit(),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Row(children: [
                      const Icon(Icons.error_outline_rounded, color: kDanger, size: 16),
                      const SizedBox(width: 6),
                      Expanded(child: Text(_error!, style: const TextStyle(color: kDanger, fontSize: 12.5))),
                    ]),
                  ],
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _loading ? null : (_usePassword ? _passwordSubmit : _submit),
                    child: _loading
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(_usePassword ? 'Sign in' : 'Send OTP'),
                  ),
                ]),
              ),
              const SizedBox(height: 18),
              Text(_usePassword ? 'Use the email or mobile number and password your admin set in the ERP.' : 'We\'ll send a one-time code to verify your number.',
                  textAlign: TextAlign.center, style: const TextStyle(color: kFaint, fontSize: 12)),
            ]),
          ),
        ),
      ]),
    );
  }
}
