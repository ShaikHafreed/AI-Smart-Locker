import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';
import 'approval_request_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  static const _bg           = Color(0xFF0A0E1A);
  static const _surface      = Color(0xFF111827);
  static const _card         = Color(0xFF1C2333);
  static const _border       = Color(0xFF2A3550);
  static const _cyan         = Color(0xFF00D4FF);
  static const _green        = Color(0xFF00FF88);
  static const _red          = Color(0xFFFF3B5C);
  static const _orange       = Color(0xFFFFB800);
  static const _textPrimary  = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF6B7A99);

  Map<String, dynamic> _status = {};
  List<dynamic>        _logs   = [];
  bool   _loading   = true;
  bool   _refreshing = false;
  String _userName  = 'Owner';
  Timer? _autoRefreshTimer;

  @override
  void initState() {
    super.initState();
    _loadAll();
    // Auto-refresh every 10 seconds
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (mounted && !_refreshing) _silentRefresh();
    });
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    final info = await ApiService.getUserInfo();
    // Parallel fetch — status + logs at same time
    final data = await ApiService.getDashboardData();
    if (mounted) {
      setState(() {
        _userName = info['name'] ?? 'Owner';
        _status   = data['status'] ?? {};
        _logs     = data['logs']   ?? [];
        _loading  = false;
      });
    }
  }

  Future<void> _silentRefresh() async {
    final data = await ApiService.getDashboardData();
    if (mounted) {
      setState(() {
        _status = data['status'] ?? _status;
        _logs   = data['logs']   ?? _logs;
      });
    }
  }

  Future<void> _manualRefresh() async {
    setState(() => _refreshing = true);
    await _silentRefresh();
    setState(() => _refreshing = false);
  }

  int get _ownerCount    => _logs.where((l) => l['result'].toString().contains('Owner Verified')).length;
  int get _intruderCount => _logs.where((l) => l['result'].toString().contains('Intruder')).length;
  int get _totalEvents   => _logs.length;
  String get _lastEvent  => _logs.isNotEmpty ? _logs.last['result'].toString() : 'No Activity';
  bool get _hasPending   => (_status['pending'] ?? 'NONE') == 'WAITING';

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
                onRefresh: _manualRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 20),
                      if (_hasPending) _buildPendingAlert(),
                      _buildLockerStatus(),
                      const SizedBox(height: 20),
                      _buildStatsGrid(),
                      const SizedBox(height: 20),
                      _buildRecentActivity(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('DASHBOARD',
            style: TextStyle(color: _textSecondary, fontSize: 11,
                letterSpacing: 3, fontWeight: FontWeight.w600)),
        const SizedBox(height: 4),
        Text('Hi, $_userName 👋',
            style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
      ]),
      GestureDetector(
        onTap: _manualRefresh,
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _border)),
          child: _refreshing
              ? SizedBox(width: 20, height: 20,
                  child: CircularProgressIndicator(color: _cyan, strokeWidth: 2))
              : const Icon(Icons.refresh_rounded, color: _cyan, size: 20),
        ),
      ),
    ]);
  }

  Widget _buildPendingAlert() {
    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ApprovalRequestScreen())),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _red.withOpacity(0.5))),
        child: Row(children: [
          Container(width: 10, height: 10,
              decoration: BoxDecoration(color: _red, shape: BoxShape.circle)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('⚠️ Unknown Visitor Detected!',
                style: TextStyle(color: _red, fontWeight: FontWeight.w700, fontSize: 14)),
            Text('Tap to Approve or Reject',
                style: TextStyle(color: _textSecondary, fontSize: 12)),
          ])),
          Icon(Icons.chevron_right_rounded, color: _red),
        ]),
      ),
    );
  }

  Widget _buildLockerStatus() {
    final isOnline = (_status['locker'] ?? '') == 'ONLINE';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: _card, borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isOnline ? _green.withOpacity(0.3) : _border)),
      child: Row(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: isOnline ? _green.withOpacity(0.1) : _textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.lock_rounded,
              color: isOnline ? _green : _textSecondary, size: 24),
        ),
        const SizedBox(width: 16),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Locker Status',
              style: TextStyle(color: _textSecondary, fontSize: 12)),
          const SizedBox(height: 4),
          Text(isOnline ? 'ONLINE & SECURE' : 'OFFLINE',
              style: TextStyle(
                  color: isOnline ? _green : _textSecondary,
                  fontSize: 16, fontWeight: FontWeight.w700)),
        ])),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
              color: isOnline ? _green.withOpacity(0.1) : _textSecondary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Row(children: [
            Container(width: 6, height: 6,
                decoration: BoxDecoration(
                    color: isOnline ? _green : _textSecondary,
                    shape: BoxShape.circle)),
            const SizedBox(width: 6),
            Text(isOnline ? 'Active' : 'Offline',
                style: TextStyle(
                    color: isOnline ? _green : _textSecondary,
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _buildStatsGrid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('SYSTEM STATS',
          style: TextStyle(color: _textSecondary, fontSize: 11,
              letterSpacing: 2.5, fontWeight: FontWeight.w600)),
      const SizedBox(height: 14),
      Row(children: [
        _statCard('Total Events',  '$_totalEvents',   Icons.history_rounded,       _cyan),
        const SizedBox(width: 12),
        _statCard('Owner Access',  '$_ownerCount',    Icons.verified_user_rounded, _green),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _statCard('Intruders',     '$_intruderCount', Icons.warning_amber_rounded, _red),
        const SizedBox(width: 12),
        _statCard('Last Event',    _lastEvent.length > 12
            ? '${_lastEvent.substring(0, 12)}..' : _lastEvent,
            Icons.access_time_rounded, _orange),
      ]),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
            color: _card, borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _border)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 12),
          Text(value,
              style: TextStyle(color: _textPrimary, fontSize: 22,
                  fontWeight: FontWeight.w800),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label, style: TextStyle(color: _textSecondary, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recent = _logs.reversed.take(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text('RECENT ACTIVITY',
            style: TextStyle(color: _textSecondary, fontSize: 11,
                letterSpacing: 2.5, fontWeight: FontWeight.w600)),
        Text('${_logs.length} total',
            style: TextStyle(color: _textSecondary, fontSize: 11)),
      ]),
      const SizedBox(height: 14),
      if (recent.isEmpty)
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border)),
          child: Center(child: Text('No activity yet',
              style: TextStyle(color: _textSecondary))),
        )
      else
        Container(
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border)),
          child: Column(
            children: recent.asMap().entries.map((entry) {
              final i    = entry.key;
              final log  = entry.value;
              final result = log['result']?.toString() ?? '';
              final time   = log['event_time']?.toString() ?? '';
              final isOwner    = result.contains('Owner') || result.contains('Approved');
              final isIntruder = result.contains('Intruder') || result.contains('Rejected');
              final color = isOwner ? _green : isIntruder ? _red : _cyan;
              final icon  = isOwner
                  ? Icons.check_circle_rounded
                  : isIntruder
                      ? Icons.warning_amber_rounded
                      : Icons.info_rounded;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Row(children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          color: color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8)),
                      child: Icon(icon, color: color, size: 16),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(result,
                          style: TextStyle(color: _textPrimary, fontSize: 13,
                              fontWeight: FontWeight.w500)),
                      if (time.isNotEmpty)
                        Text(time.length > 19 ? time.substring(0, 19) : time,
                            style: TextStyle(color: _textSecondary, fontSize: 11)),
                    ])),
                    if (log['similarity'] != null && (log['similarity'] as num) > 0)
                      Text('${(log['similarity'] as num).toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontSize: 12,
                              fontWeight: FontWeight.w600)),
                  ]),
                ),
                if (i < recent.length - 1)
                  Divider(color: _border, height: 1, indent: 16, endIndent: 16),
              ]);
            }).toList(),
          ),
        ),
    ]);
  }
}