import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';
import '../theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
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
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Sign Out', style: TextStyle(color: AppColors.textHi)),
        content: const Text('Are you sure you want to sign out?',
            style: TextStyle(color: AppColors.textLo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textLo)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign Out',
                style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
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
          backgroundColor: AppColors.bg,
          body: Center(child: CircularProgressIndicator(color: AppColors.cyan)));
    }
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: RefreshIndicator(
          color: AppColors.cyan,
          backgroundColor: AppColors.surface,
          onRefresh: _loadData,
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIdentity(),
                const SizedBox(height: 26),
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

  Widget _buildIdentity() {
    final initial = _ownerName.isNotEmpty ? _ownerName[0].toUpperCase() : 'O';
    return PanelCard(
      glow: AppColors.cyan,
      padding: const EdgeInsets.all(18),
      child: Row(children: [
        Container(
          width: 60, height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [
              AppColors.cyan.withOpacity(0.30),
              AppColors.cyan.withOpacity(0.05),
            ]),
            border: Border.all(color: AppColors.cyan.withOpacity(0.5), width: 1.5),
            boxShadow: [BoxShadow(color: AppColors.cyan.withOpacity(0.25), blurRadius: 20, spreadRadius: -4)],
          ),
          alignment: Alignment.center,
          child: Text(initial,
              style: const TextStyle(color: AppColors.cyan, fontSize: 24, fontWeight: FontWeight.w800)),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('OWNER',
              style: TextStyle(color: AppColors.textLo, fontFamily: kMono, fontSize: 10,
                  letterSpacing: 2.5, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(_ownerName,
              style: const TextStyle(color: AppColors.textHi, fontSize: 22, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
        ])),
        GestureDetector(
          onTap: _showRenameDialog,
          child: const GlowChip(Icons.edit_rounded, AppColors.cyan),
        ),
      ]),
    );
  }

  Widget _buildSystemStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SystemLabel('System Stats'),
        const SizedBox(height: 14),
        Row(children: [
          _statTile('Total Events',  '$_totalEvents',   Icons.equalizer_rounded,      AppColors.cyan),
          const SizedBox(width: 12),
          _statTile('Owner Access',  '$_ownerCount',    Icons.verified_user_rounded,  AppColors.mint),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _statTile('Intruders',     '$_intruderCount', Icons.warning_amber_rounded,  AppColors.coral),
          const SizedBox(width: 12),
          _statTile('Approved',      '$_approvedCount', Icons.check_circle_rounded,   AppColors.cyan),
        ]),
        const SizedBox(height: 12),
        Row(children: [
          _statTile('Rejected',      '$_rejectedCount', Icons.cancel_rounded,          AppColors.amber),
          const SizedBox(width: 12),
          _statTile('Server',        '192.168.31.229',  Icons.dns_rounded,             AppColors.violet),
        ]),
      ],
    );
  }

  Widget _statTile(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: PanelCard(
        padding: const EdgeInsets.all(14),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlowChip(icon, color, size: 16, padding: 8),
          const SizedBox(height: 12),
          Text(value,
              style: const TextStyle(color: AppColors.textHi, fontFamily: kMono,
                  fontSize: 18, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.textLo, fontSize: 10.5)),
        ]),
      ),
    );
  }

  Widget _buildAppInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SystemLabel('App Info'),
        const SizedBox(height: 14),
        PanelCard(
          child: Column(children: [
            _infoRow('Model',     'ArcFace + MTCNN'),
            const Divider(color: AppColors.line, height: 1),
            _infoRow('Threshold', 'Similarity ≥ 50%'),
            const Divider(color: AppColors.line, height: 1),
            _infoRow('Polling',   '60s approval window'),
            const Divider(color: AppColors.line, height: 1),
            _infoRow('Evidence',  '10 photos on reject'),
            const Divider(color: AppColors.line, height: 1),
            _infoRow('Auth',      'JWT + OTP + Google'),
            const Divider(color: AppColors.line, height: 1),
            _infoRow('Version',   '1.0.0 — Final Year Project'),
          ]),
        ),
      ],
    );
  }

  Widget _infoRow(String key, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(key, style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
          Text(value,
              style: const TextStyle(color: AppColors.textHi, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SystemLabel('Security'),
        const SizedBox(height: 14),
        _actionTile('Manage Owner Faces', Icons.face_rounded, AppColors.cyan,
            () => Navigator.pushNamed(context, '/owner_faces')),
        const SizedBox(height: 10),
        _actionTile('View Gallery', Icons.photo_library_outlined, AppColors.violet,
            () => Navigator.pushNamed(context, '/gallery')),
        const SizedBox(height: 10),
        _actionTile('Sign Out', Icons.logout_rounded, AppColors.coral, _logout),
      ],
    );
  }

  Widget _actionTile(String label, IconData icon, Color color, VoidCallback onTap) {
    return PanelCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        GlowChip(icon, color, size: 18, padding: 9),
        const SizedBox(width: 14),
        Text(label,
            style: const TextStyle(color: AppColors.textHi, fontSize: 14, fontWeight: FontWeight.w600)),
        const Spacer(),
        const Icon(Icons.chevron_right_rounded, color: AppColors.textLo, size: 20),
      ]),
    );
  }

  void _showRenameDialog() {
    final ctrl = TextEditingController(text: _ownerName);
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Edit Name', style: TextStyle(color: AppColors.textHi)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: AppColors.textHi),
          decoration: const InputDecoration(
            hintText: 'Your name',
            hintStyle: TextStyle(color: AppColors.textLo),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.line)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.cyan)),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textLo)),
          ),
          TextButton(
            onPressed: () {
              _saveOwnerName(ctrl.text.trim());
              Navigator.pop(context);
            },
            child: const Text('Save',
                style: TextStyle(color: AppColors.cyan, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}
