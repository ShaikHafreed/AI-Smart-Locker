import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF111827);
  static const _card = Color(0xFF1C2333);
  static const _border = Color(0xFF2A3550);
  static const _cyan = Color(0xFF00D4FF);
  static const _green = Color(0xFF00FF88);
  static const _red = Color(0xFFFF3B5C);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF6B7A99);

  static const _pinKey = 'locker_pin';
  static const _loggedInKey = 'locker_logged_in';
  static const _ownerNameKey = 'locker_owner_name';

  bool _isLoggedIn = false;
  bool _hasPin = false;
  bool _loading = true;
  String _ownerName = 'Owner';
  Map<String, dynamic> _status = {};

  String _enteredPin = '';
  String _confirmPin = '';
  bool _isSettingPin = false;
  bool _pinError = false;
  String _errorMsg = '';

  @override
  void initState() {
    super.initState();
    _loadState();
  }

  Future<void> _loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final pin = prefs.getString(_pinKey);
    final loggedIn = prefs.getBool(_loggedInKey) ?? false;
    final name = prefs.getString(_ownerNameKey) ?? 'Owner';
    Map<String, dynamic> status = {};
    try {
      status = await ApiService.getStatus();
    } catch (_) {}
    setState(() {
      _hasPin = pin != null && pin.isNotEmpty;
      _isLoggedIn = loggedIn;
      _ownerName = name;
      _status = status;
      _loading = false;
    });
  }

  Future<void> _attemptLogin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    final savedPin = prefs.getString(_pinKey);
    if (pin == savedPin) {
      await prefs.setBool(_loggedInKey, true);
      setState(() { _isLoggedIn = true; _enteredPin = ''; _pinError = false; });
    } else {
      setState(() { _pinError = true; _errorMsg = 'Incorrect PIN. Try again.'; _enteredPin = ''; });
    }
  }

  Future<void> _savePin(String pin) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_pinKey, pin);
    await prefs.setBool(_loggedInKey, true);
    setState(() {
      _hasPin = true; _isLoggedIn = true; _isSettingPin = false;
      _enteredPin = ''; _confirmPin = ''; _pinError = false;
    });
  }

  Future<void> _signOut() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_loggedInKey, false);
    setState(() { _isLoggedIn = false; _enteredPin = ''; });
  }

  Future<void> _saveOwnerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerNameKey, name);
    setState(() => _ownerName = name);
  }

  void _onKeyTap(String key) {
    if (_enteredPin.length >= 4) return;
    setState(() { _enteredPin += key; _pinError = false; });
    if (_enteredPin.length == 4) {
      if (_isSettingPin) {
        if (_confirmPin.isEmpty) {
          setState(() { _confirmPin = _enteredPin; _enteredPin = ''; });
        } else {
          if (_enteredPin == _confirmPin) {
            _savePin(_enteredPin);
          } else {
            setState(() {
              _pinError = true; _errorMsg = 'PINs do not match. Try again.';
              _enteredPin = ''; _confirmPin = '';
            });
          }
        }
      } else {
        _attemptLogin(_enteredPin);
      }
    }
  }

  void _onBackspace() {
    if (_enteredPin.isEmpty) return;
    setState(() => _enteredPin = _enteredPin.substring(0, _enteredPin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(backgroundColor: _bg, body: Center(child: CircularProgressIndicator(color: _cyan)));
    if (!_isLoggedIn) return _buildLoginScreen();
    return _buildProfileScreen();
  }

  Widget _buildLoginScreen() {
    String promptText;
    if (!_hasPin && !_isSettingPin) promptText = 'No PIN set yet';
    else if (_isSettingPin && _confirmPin.isEmpty) promptText = 'Set a 4-digit PIN';
    else if (_isSettingPin && _confirmPin.isNotEmpty) promptText = 'Confirm your PIN';
    else promptText = 'Enter your PIN';

    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _cyan.withOpacity(0.1),
                    border: Border.all(color: _cyan.withOpacity(0.4), width: 2),
                  ),
                  child: const Icon(Icons.lock_person_rounded, color: _cyan, size: 40),
                ),
                const SizedBox(height: 28),
                Text('AI Smart Locker',
                    style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text(promptText, style: TextStyle(color: _textSecondary, fontSize: 14)),
                const SizedBox(height: 32),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(4, (i) {
                    final filled = i < _enteredPin.length;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 10),
                      width: 18, height: 18,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: filled ? _cyan : Colors.transparent,
                        border: Border.all(color: filled ? _cyan : _border, width: 2),
                      ),
                    );
                  }),
                ),
                if (_pinError) ...[
                  const SizedBox(height: 16),
                  Text(_errorMsg, style: const TextStyle(color: _red, fontSize: 13)),
                ],
                const SizedBox(height: 36),
                _buildNumpad(),
                const SizedBox(height: 24),
                if (!_hasPin && !_isSettingPin)
                  TextButton(
                    onPressed: () => setState(() => _isSettingPin = true),
                    child: Text('Create a PIN', style: TextStyle(color: _cyan, fontSize: 14)),
                  ),
                if (_isSettingPin)
                  TextButton(
                    onPressed: () => setState(() {
                      _isSettingPin = false; _enteredPin = ''; _confirmPin = ''; _pinError = false;
                    }),
                    child: Text('Cancel', style: TextStyle(color: _textSecondary, fontSize: 14)),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNumpad() {
    final keys = [['1','2','3'], ['4','5','6'], ['7','8','9'], ['','0','⌫']];
    return Column(
      children: keys.map((row) => Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: row.map((k) {
            if (k.isEmpty) return const SizedBox(width: 70, height: 70);
            return GestureDetector(
              onTap: () => k == '⌫' ? _onBackspace() : _onKeyTap(k),
              child: Container(
                width: 70, height: 70,
                margin: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: _card, shape: BoxShape.circle,
                  border: Border.all(color: _border),
                ),
                child: Center(
                  child: k == '⌫'
                      ? const Icon(Icons.backspace_outlined, color: _textSecondary, size: 22)
                      : Text(k, style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w500)),
                ),
              ),
            );
          }).toList(),
        ),
      )).toList(),
    );
  }

  Widget _buildProfileScreen() {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildProfileHeader(),
              const SizedBox(height: 28),
              _buildSystemStats(),
              const SizedBox(height: 24),
              _buildAppInfo(),
              const SizedBox(height: 24),
              _buildActions(),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('PROFILE',
                style: TextStyle(color: _textSecondary, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text(_ownerName,
                style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
          ],
        ),
        GestureDetector(
          onTap: _showRenameDialog,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border),
            ),
            child: const Icon(Icons.edit_rounded, color: _cyan, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStats() {
    final total = _status['total_logs'] ?? 0;
    final owners = _status['owner_count'] ?? 0;
    final intruders = _status['intruder_count'] ?? 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SYSTEM STATS'),
        const SizedBox(height: 14),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 12, mainAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _statTile('Total Events', '$total', Icons.history_rounded, _cyan),
            _statTile('Owner Access', '$owners', Icons.verified_user_rounded, _green),
            _statTile('Intruders', '$intruders', Icons.warning_amber_rounded, _red),
            _statTile('Server', '192.168.31.172', Icons.dns_rounded, const Color(0xFFB48EFF)),
          ],
        ),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const Spacer(),
          Text(value,
              style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 10.5)),
        ],
      ),
    );
  }

  Widget _buildAppInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('APP INFO'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border),
          ),
          child: Column(
            children: [
              _infoRow('Model', 'ArcFace + MTCNN'),
              Divider(color: _border, height: 1),
              _infoRow('Threshold', 'Similarity ≥ 50%'),
              Divider(color: _border, height: 1),
              _infoRow('Polling', '60s approval window'),
              Divider(color: _border, height: 1),
              _infoRow('Evidence', '10 photos on reject'),
              Divider(color: _border, height: 1),
              _infoRow('Version', '1.0.0 — Final Year Project'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: TextStyle(color: _textSecondary, fontSize: 13)),
          Text(value, style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SECURITY'),
        const SizedBox(height: 14),
        _actionTile('Change PIN', Icons.pin_outlined, _cyan, () {
          setState(() {
            _isLoggedIn = false; _isSettingPin = true;
            _hasPin = false; _enteredPin = ''; _confirmPin = '';
          });
        }),
        const SizedBox(height: 10),
        _actionTile('Sign Out', Icons.logout_rounded, _red, _signOut),
      ],
    );
  }

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 14),
            Text(label, style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: TextStyle(color: _textSecondary, fontSize: 11, letterSpacing: 2.5, fontWeight: FontWeight.w600));

  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _ownerName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Name', style: TextStyle(color: Color(0xFFE8EDF5))),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Color(0xFFE8EDF5)),
          decoration: InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: _textSecondary),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: _border)),
            focusedBorder: const UnderlineInputBorder(borderSide: BorderSide(color: _cyan)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: _textSecondary))),
          TextButton(
            onPressed: () { _saveOwnerName(ctrl.text.trim()); Navigator.pop(context); },
            child: const Text('Save', style: TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
