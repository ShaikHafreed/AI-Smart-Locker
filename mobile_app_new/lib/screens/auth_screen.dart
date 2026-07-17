import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../theme.dart';
import '../api_service.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  static const _bg           = Color(0xFF0A0E1A);
  static const _surface      = Color(0xFF111827);
  static const _card         = Color(0xFF1C2333);
  static const _border       = Color(0xFF2A3550);
  static const _cyan         = Color(0xFF00D4FF);
  static const _green        = Color(0xFF00FF88);
  static const _red          = Color(0xFFFF3B5C);
  static const _textPrimary  = Color(0xFFE8EDF5);
  static const _textSec      = Color(0xFF6B7A99);

  static const _headers = {
    "ngrok-skip-browser-warning": "true",
    "Content-Type": "application/json"
  };

  final _phoneCtrl = TextEditingController();
  final _otpCtrl   = TextEditingController();
  final _nameCtrl  = TextEditingController();

  bool   _loading    = false;
  bool   _otpSent    = false;
  String _errorMsg   = '';
  String _demoOtp    = '';
  bool   _smsSent    = false;
  int    _resendTimer = 0;

  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
    serverClientId: '659356355972-pp40m043r12v2c0pcvij41po72s08s2u.apps.googleusercontent.com',
  );

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _otpCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  // ── Send OTP ─────────────────────────────────────────────────
  Future<void> _sendOtp() async {
    final phone = _phoneCtrl.text.trim();
    if (phone.length < 10) {
      setState(() => _errorMsg = 'Enter a valid 10-digit phone number');
      return;
    }
    setState(() { _loading = true; _errorMsg = ''; _demoOtp = ''; });
    try {
      final r = await ApiService.publicPost(
        '/auth/send_otp',
        headers: _headers,
        body: jsonEncode({'phone': phone}),
      );
      final data = jsonDecode(r.body);
      if (data['success'] == true) {
        setState(() {
          _otpSent   = true;
          _smsSent   = data['sms_sent'] == true;
          _demoOtp   = data['demo_otp'] ?? '';
          _loading   = false;
          _resendTimer = 30;
        });
        _startResendTimer();
      } else {
        setState(() {
          _errorMsg = data['message'] ?? 'Failed to send OTP';
          _loading  = false;
        });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error. Check if server is running.'; _loading = false; });
    }
  }

  void _startResendTimer() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() => _resendTimer--);
      return _resendTimer > 0;
    });
  }

  // ── Verify OTP ───────────────────────────────────────────────
  Future<void> _verifyOtp() async {
    final phone = _phoneCtrl.text.trim();
    final otp   = _otpCtrl.text.trim();
    final name  = _nameCtrl.text.trim();
    if (otp.length != 6) {
      setState(() => _errorMsg = 'Enter the 6-digit OTP');
      return;
    }
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      final r = await ApiService.publicPost(
        '/auth/verify_otp',
        headers: _headers,
        body: jsonEncode({'phone': phone, 'otp': otp, 'name': name}),
      );
      final data = jsonDecode(r.body);
      if (data['success'] == true) {
        await _saveAndNavigate(data);
      } else {
        setState(() { _errorMsg = data['message'] ?? 'Invalid OTP'; _loading = false; });
      }
    } catch (e) {
      setState(() { _errorMsg = 'Connection error: $e'; _loading = false; });
    }
  }

  // ── Google Sign-In ───────────────────────────────────────────
  Future<void> _googleLogin() async {
    setState(() { _loading = true; _errorMsg = ''; });
    try {
      // Sign out first to force account picker
      await _googleSignIn.signOut();
      final account = await _googleSignIn.signIn();
      if (account == null) {
        setState(() { _loading = false; });
        return;
      }
      final auth    = await account.authentication;
      final idToken = auth.idToken ?? '';

      final r = await ApiService.publicPost(
        '/auth/google',
        headers: _headers,
        body: jsonEncode({
          'id_token':  idToken,
          'google_id': account.id,
          'email':     account.email,
          'name':      account.displayName ?? '',
        }),
      );
      final data = jsonDecode(r.body);
      if (data['success'] == true) {
        await _saveAndNavigate(data);
      } else {
        setState(() {
          _errorMsg = data['message'] ?? 'Google login failed';
          _loading  = false;
        });
      }
    } on PlatformException catch (e) {
      setState(() {
        _errorMsg = 'Google error: ${e.message}\n\nMake sure SHA-1 is added in Firebase console.';
        _loading  = false;
      });
    } catch (e) {
      setState(() {
        _errorMsg = 'Google sign-in failed: $e';
        _loading  = false;
      });
    }
  }

  // ── Save session and go to home ──────────────────────────────
  Future<void> _saveAndNavigate(Map data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('jwt_token',  data['token'] ?? '');
    await prefs.setString('user_name',  data['user']['name']  ?? 'Owner');
    await prefs.setString('user_phone', data['user']['phone'] ?? '');
    await prefs.setString('user_email', data['user']['email'] ?? '');
    if (mounted) Navigator.pushReplacementNamed(context, '/home');
  }

  // ── BUILD ────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 24),
          child: Column(
            children: [
              const SizedBox(height: 28),
              _buildLogo(),
              const SizedBox(height: 24),
              _buildTitle(),
              const SizedBox(height: 36),
              if (!_otpSent) ...[
                _buildPhoneField(),
                const SizedBox(height: 16),
                _buildButton('Send OTP', _loading ? null : _sendOtp, _cyan),
                const SizedBox(height: 24),
                _buildDivider(),
                const SizedBox(height: 24),
                _buildGoogleButton(),
              ] else ...[
                // Phone chip
                _buildPhoneChip(),
                const SizedBox(height: 16),
                _buildNameField(),
                const SizedBox(height: 12),
                _buildOtpField(),
                const SizedBox(height: 8),
                // Demo OTP banner (shown only if SMS not configured)
                if (_demoOtp.isNotEmpty && !_smsSent)
                  _buildDemoBanner(),
                // SMS sent confirmation
                if (_smsSent)
                  _buildSmsSentBanner(),
                const SizedBox(height: 16),
                _buildButton('Verify & Sign In', _loading ? null : _verifyOtp, _cyan),
                const SizedBox(height: 12),
                _buildResendRow(),
              ],
              if (_errorMsg.isNotEmpty) ...[
                const SizedBox(height: 16),
                _buildError(),
              ],
              const SizedBox(height: 40),
              Text('AI Smart Cupboard — Final Year Project',
                  style: TextStyle(color: _textSec, fontSize: 11)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return const SentinelCore(size: 140, color: _cyan, icon: Icons.lock_rounded);
  }

  Widget _buildTitle() {
    return Column(children: [
      Text(_otpSent ? 'VERIFY IDENTITY' : 'SECURE ACCESS',
          style: const TextStyle(color: _cyan, fontFamily: kMono, fontSize: 11,
              letterSpacing: 3, fontWeight: FontWeight.w600)),
      const SizedBox(height: 10),
      Text('AI Smart Cupboard',
          style: TextStyle(color: _textPrimary, fontSize: 24, fontWeight: FontWeight.w800)),
      const SizedBox(height: 6),
      Text(_otpSent ? 'Enter the OTP sent to your phone' : 'Sign in to secure your locker',
          style: TextStyle(color: _textSec, fontSize: 13)),
    ]);
  }

  Widget _buildPhoneField() {
    return Container(
      decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 17),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: _border))),
          child: Text('+91', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
        ),
        Expanded(child: TextField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(10)
          ],
          style: TextStyle(color: _textPrimary, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Phone number',
            hintStyle: TextStyle(color: _textSec),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          ),
        )),
      ]),
    );
  }

  Widget _buildPhoneChip() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
          color: _cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _cyan.withOpacity(0.25))),
      child: Row(children: [
        Icon(Icons.phone_rounded, color: _cyan, size: 16),
        const SizedBox(width: 8),
        Text('+91 ${_phoneCtrl.text}',
            style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
        const Spacer(),
        GestureDetector(
          onTap: () => setState(() { _otpSent = false; _otpCtrl.clear(); _errorMsg = ''; _demoOtp = ''; }),
          child: Text('Change', style: TextStyle(color: _cyan, fontSize: 12)),
        ),
      ]),
    );
  }

  Widget _buildNameField() {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: TextField(
        controller: _nameCtrl,
        style: TextStyle(color: _textPrimary),
        decoration: InputDecoration(
          hintText: 'Your name (optional)',
          hintStyle: TextStyle(color: _textSec),
          prefixIcon: Icon(Icons.person_outline_rounded, color: _textSec),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildOtpField() {
    return Container(
      decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border)),
      child: TextField(
        controller: _otpCtrl,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.digitsOnly,
          LengthLimitingTextInputFormatter(6)
        ],
        textAlign: TextAlign.center,
        style: TextStyle(color: _textPrimary, fontSize: 26, letterSpacing: 10,
            fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: '------',
          hintStyle: TextStyle(color: _textSec, fontSize: 22, letterSpacing: 8),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20),
        ),
      ),
    );
  }

  Widget _buildDemoBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: const Color(0xFFFFB800).withOpacity(0.1),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFFFFB800).withOpacity(0.4))),
      child: Row(children: [
        const Icon(Icons.info_outline_rounded, color: Color(0xFFFFB800), size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Demo Mode — MSG91 not configured',
              style: TextStyle(color: Color(0xFFFFB800), fontSize: 11, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text('Your OTP: $_demoOtp',
              style: const TextStyle(color: Color(0xFFFFB800), fontSize: 18,
                  fontWeight: FontWeight.w800, letterSpacing: 4)),
        ])),
      ]),
    );
  }

  Widget _buildSmsSentBanner() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _green.withOpacity(0.4))),
      child: Row(children: [
        Icon(Icons.check_circle_rounded, color: _green, size: 16),
        const SizedBox(width: 8),
        Text('OTP sent via SMS to +91 ${_phoneCtrl.text}',
            style: TextStyle(color: _green, fontSize: 13)),
      ]),
    );
  }

  Widget _buildResendRow() {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      Text("Didn't receive OTP? ", style: TextStyle(color: _textSec, fontSize: 13)),
      GestureDetector(
        onTap: _resendTimer > 0 ? null : _sendOtp,
        child: Text(
          _resendTimer > 0 ? 'Resend in ${_resendTimer}s' : 'Resend OTP',
          style: TextStyle(
              color: _resendTimer > 0 ? _textSec : _cyan,
              fontSize: 13, fontWeight: FontWeight.w600),
        ),
      ),
    ]);
  }

  Widget _buildButton(String label, VoidCallback? onTap, Color color) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
              colors: onTap == null
                  ? [color.withOpacity(0.4), color.withOpacity(0.4)]
                  : [color.withOpacity(0.85), color]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: _loading
              ? const SizedBox(width: 22, height: 22,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5))
              : Text(label,
                  style: const TextStyle(color: Color(0xFF0A0E1A),
                      fontWeight: FontWeight.w800, fontSize: 16)),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Row(children: [
      Expanded(child: Divider(color: _border)),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Text('OR', style: TextStyle(color: _textSec, fontSize: 12, fontWeight: FontWeight.w600)),
      ),
      Expanded(child: Divider(color: _border)),
    ]);
  }

  Widget _buildGoogleButton() {
    return GestureDetector(
      onTap: _loading ? null : _googleLogin,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            width: 24, height: 24,
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: const Center(
                child: Text('G',
                    style: TextStyle(color: Colors.red, fontWeight: FontWeight.w900, fontSize: 14))),
          ),
          const SizedBox(width: 12),
          Text('Continue with Google',
              style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600, fontSize: 15)),
        ]),
      ),
    );
  }

  Widget _buildError() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _red.withOpacity(0.3))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(Icons.error_outline_rounded, color: _red, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Text(_errorMsg, style: TextStyle(color: _red, fontSize: 13))),
      ]),
    );
  }
}