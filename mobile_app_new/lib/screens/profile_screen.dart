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

  static const _ownerNameKey = 'user_name';

  bool _loading = true;
  String _ownerName = 'Owner';
  Map<String, dynamic> _status = {};
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final name = prefs.getString(_ownerNameKey) ?? 'Owner';

    Map<String, dynamic> status = {};
    List<dynamic> logs = [];

    try {
      status = await ApiService.getStatus();
      logs   = await ApiService.getLogs();
    } catch (_) {}

    setState(() {
      _ownerName = name;
      _status    = status;
      _logs      = logs;
      _loading   = false;
    });
  }

  // Count directly from logs — most accurate
  int get _totalEvents  => _logs.length;
  int get _ownerCount   => _logs.where((l) => (l['result'] ?? '').toString().toLowerCase().contains('owner')).length;
  int get _intruderCount => _logs.where((l) => (l['result'] ?? '').toString().toLowerCase().contains('intruder')).length;
  int get _approvedCount => _logs.where((l) => (l['result'] ?? '').toString().toLowerCase().contains('approv')).length;
  int get _rejectedCount => _logs.where((l) => (l['result'] ?? '').toString().toLowerCase().contains('reject')).length;

  Future<void> _saveOwnerName(String name) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_ownerNameKey, name);
    setState(() => _ownerName = name);
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: Color(0xFFE8EDF5))),
        content: Text('Are you sure you want to sign out?',
            style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: Color(0xFFFF3B5C), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ApiService.logout();
      if (mounted) Navigator.pushReplacementNamed(context, '/auth');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
          backgroundColor: _bg,
          body: Center(child: CircularProgressIndicator(color: _cyan)));
    }
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: _cyan,
          backgroundColor: _surface,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(),
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
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('PROFILE',
              style: TextStyle(color: _textSecondary, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_ownerName,
              style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
        GestureDetector(
          onTap: _showRenameDialog,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border)),
            child: const Icon(Icons.edit_rounded, color: _cyan, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildSystemStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('SYSTEM STATS'),
        const SizedBox(height: 14),
        // Row 1
        Row(children: [
          _statTile('Total Events',  '$_totalEvents',   Icons.history_rounded,        _cyan),
          const SizedBox(width: 12),
          _statTile('Owner Access',  '$_ownerCount',    Icons.verified_user_rounded,  _green),
        ]),
        const SizedBox(height: 12),
        // Row 2
        Row(children: [
          _statTile('Intruders',     '$_intruderCount', Icons.warning_amber_rounded,  _red),
          const SizedBox(width: 12),
          _statTile('Approved',      '$_approvedCount', Icons.check_circle_rounded,   _cyan),
        ]),
        const SizedBox(height: 12),
        // Row 3
        Row(children: [
          _statTile('Rejected',      '$_rejectedCount', Icons.cancel_rounded,          const Color(0xFFFFB800)),
          const SizedBox(width: 12),
          _statTile('Server',        '192.168.31.229',  Icons.dns_rounded,             const Color(0xFFB48EFF)),
        ]),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(height: 10),
          Text(value,
              style: TextStyle(color: _textPrimary, fontSize: 20, fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 10.5)),
        ]),
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
              border: Border.all(color: _border)),
          child: Column(children: [
            _infoRow('Model',     'ArcFace + MTCNN'),
            Divider(color: _border, height: 1),
            _infoRow('Threshold', 'Similarity ≥ 50%'),
            Divider(color: _border, height: 1),
            _infoRow('Polling',   '60s approval window'),
            Divider(color: _border, height: 1),
            _infoRow('Evidence',  '10 photos on reject'),
            Divider(color: _border, height: 1),
            _infoRow('Auth',      'JWT + OTP + Google'),
            Divider(color: _border, height: 1),
            _infoRow('Version',   '1.0.0 — Final Year Project'),
          ]),
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
          Text(value,
              style: TextStyle(color: _textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
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
        _actionTile('Manage Owner Faces', Icons.face_rounded, _cyan,
            () => Navigator.pushNamed(context, '/owner_faces')),
        const SizedBox(height: 10),
        _actionTile('View Gallery', Icons.photo_library_outlined, const Color(0xFFB48EFF),
            () => Navigator.pushNamed(context, '/gallery')),
        const SizedBox(height: 10),
        _actionTile('Sign Out', Icons.logout_rounded, _red, _logout),
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
            border: Border.all(color: _border)),
        child: Row(children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 14),
          Text(label,
              style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
          const Spacer(),
          Icon(Icons.chevron_right_rounded, color: _textSecondary, size: 20),
        ]),
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
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: _textSecondary)),
          ),
          TextButton(
            onPressed: () {
              _saveOwnerName(ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(color: Color(0xFF00D4FF), fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}