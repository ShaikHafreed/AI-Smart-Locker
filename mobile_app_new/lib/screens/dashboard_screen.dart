import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF111827);
  static const _card = Color(0xFF1C2333);
  static const _border = Color(0xFF2A3550);
  static const _cyan = Color(0xFF00D4FF);
  static const _green = Color(0xFF00FF88);
  static const _red = Color(0xFFFF3B5C);
  static const _amber = Color(0xFFFFB800);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF6B7A99);

  Map<String, dynamic> _status = {};
  bool _loading = true;
  bool _refreshing = false;
  String _lockerState = 'SECURE';
  Timer? _pollTimer;

  late AnimationController _pulseCtrl;
  late AnimationController _scanCtrl;
  late Animation<double> _pulseAnim;
  late Animation<double> _scanAnim;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _scanCtrl = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();
    _pulseAnim = Tween<double>(begin: 0.6, end: 1.0).animate(CurvedAnimation(parent: _pulseCtrl, curve: Curves.easeInOut));
    _scanAnim = Tween<double>(begin: 0.0, end: 1.0).animate(CurvedAnimation(parent: _scanCtrl, curve: Curves.linear));
    _fetchStatus();
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => _fetchStatus(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _pulseCtrl.dispose();
    _scanCtrl.dispose();
    super.dispose();
  }

  Future<void> _fetchStatus({bool silent = false}) async {
    if (!silent) setState(() => _refreshing = true);
    try {
      final data = await ApiService.getStatus();
      // /status returns: { "intruders": 30, "last_event": "...", "locker": "ONLINE", "pending": "APPROVED", "total_logs": 172 }
      final pending = (data['pending'] ?? '').toString().toUpperCase();

      setState(() {
        _status = data;
        _loading = false;
        _refreshing = false;
        if (pending == 'WAITING') {
          _lockerState = 'PENDING';
        } else if ((data['intruders'] ?? 0) > 0 &&
            (data['last_event'] ?? '').toString().toLowerCase().contains('intruder')) {
          _lockerState = 'ALERT';
        } else {
          _lockerState = 'SECURE';
        }
      });
    } catch (e) {
      setState(() { _loading = false; _refreshing = false; });
    }
  }

  Color get _stateColor {
    switch (_lockerState) {
      case 'ALERT':   return _red;
      case 'PENDING': return _amber;
      default:        return _green;
    }
  }

  String get _stateLabel {
    switch (_lockerState) {
      case 'ALERT':   return 'INTRUDER ALERT';
      case 'PENDING': return 'AWAITING APPROVAL';
      default:        return 'SECURE';
    }
  }

  IconData get _stateIcon {
    switch (_lockerState) {
      case 'ALERT':   return Icons.lock_open_rounded;
      case 'PENDING': return Icons.lock_clock_outlined;
      default:        return Icons.lock_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: _cyan))
            : RefreshIndicator(
                color: _cyan,
                backgroundColor: _surface,
                onRefresh: () => _fetchStatus(),
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 28),
                      _buildLockHero(),
                      const SizedBox(height: 28),
                      _buildStatsRow(),
                      const SizedBox(height: 24),
                      _buildLastEvent(),
                      const SizedBox(height: 24),
                      _buildQuickActions(),
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
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AI SMART LOCKER',
                style: TextStyle(color: _textSecondary, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Security Hub',
                style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
          ],
        ),
        GestureDetector(
          onTap: () => _fetchStatus(),
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: _card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _refreshing ? _cyan : _border),
            ),
            child: _refreshing
                ? const SizedBox(width: 20, height: 20,
                    child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
                : const Icon(Icons.refresh_rounded, color: _cyan, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildLockHero() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 40),
      decoration: BoxDecoration(
        color: _surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _stateColor.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: _stateColor.withOpacity(0.08), blurRadius: 30, spreadRadius: 4)],
      ),
      child: Column(
        children: [
          SizedBox(
            height: 120, width: 120,
            child: Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _pulseAnim,
                  builder: (_, __) => Container(
                    width: 110, height: 110,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: _stateColor.withOpacity(_pulseAnim.value * 0.5), width: 1.5),
                    ),
                  ),
                ),
                Container(
                  width: 80, height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _stateColor.withOpacity(0.12),
                    border: Border.all(color: _stateColor.withOpacity(0.6), width: 2),
                  ),
                ),
                Icon(_stateIcon, color: _stateColor, size: 36),
                if (_lockerState == 'PENDING')
                  AnimatedBuilder(
                    animation: _scanAnim,
                    builder: (_, __) => Positioned(
                      top: _scanAnim.value * 110,
                      child: Container(
                        width: 110, height: 2,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            Colors.transparent, _amber.withOpacity(0.8), Colors.transparent,
                          ]),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: _stateColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _stateColor.withOpacity(0.4)),
            ),
            child: Text(_stateLabel,
                style: TextStyle(color: _stateColor, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.5)),
          ),
          const SizedBox(height: 12),
          Text('Facial recognition active', style: TextStyle(color: _textSecondary, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    // Exact field names from /status API:
    // total_logs, intruders — no owner_count field, so we calculate owners = total - intruders
    final total     = int.tryParse((_status['total_logs'] ?? 0).toString()) ?? 0;
    final intruders = int.tryParse((_status['intruders']  ?? 0).toString()) ?? 0;
    final owners    = (total - intruders).clamp(0, total);

    return Row(
      children: [
        _statCard('Total Events', '$total',     Icons.history_rounded,       _cyan),
        const SizedBox(width: 12),
        _statCard('Owner Access', '$owners',    Icons.verified_user_rounded, _green),
        const SizedBox(width: 12),
        _statCard('Intruders',    '$intruders', Icons.warning_amber_rounded, _red),
      ],
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 10),
            Text(value, style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: TextStyle(color: _textSecondary, fontSize: 10.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildLastEvent() {
    final lastEvent = (_status['last_event'] ?? 'No events yet').toString();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _card, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.notifications_active_outlined, color: _cyan, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('LAST EVENT',
                    style: TextStyle(color: _textSecondary, fontSize: 10, letterSpacing: 2, fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(lastEvent,
                    style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('QUICK ACTIONS',
            style: TextStyle(color: _textSecondary, fontSize: 11, letterSpacing: 2.5, fontWeight: FontWeight.w600)),
        const SizedBox(height: 14),
        Row(
          children: [
            _actionButton('View Gallery', Icons.photo_library_outlined, _cyan,
                () => Navigator.pushNamed(context, '/gallery')),
            const SizedBox(width: 12),
            _actionButton('Access Logs', Icons.list_alt_rounded, _amber,
                () => Navigator.pushNamed(context, '/logs')),
          ],
        ),
        if (_lockerState == 'PENDING') ...[
          const SizedBox(height: 12),
          _fullActionButton('Respond to Visitor', Icons.how_to_reg_rounded, _red,
              () => Navigator.pushNamed(context, '/approval')),
        ],
      ],
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Column(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(height: 8),
              Text(label, style: TextStyle(color: _textPrimary, fontSize: 12.5, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fullActionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [color.withOpacity(0.8), color]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
          ],
        ),
      ),
    );
  }
}