import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme.dart';
import 'approval_request_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
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
  bool get _isOnline     => (_status['locker'] ?? '') == 'ONLINE';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
            : RefreshIndicator(
                color: AppColors.cyan,
                backgroundColor: AppColors.surface,
                onRefresh: _manualRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 22),
                      _buildSentinel(),
                      const SizedBox(height: 20),
                      if (_hasPending) ...[_buildPendingAlert(), const SizedBox(height: 20)],
                      _buildStatsGrid(),
                      const SizedBox(height: 22),
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
    final statusColor = _hasPending ? AppColors.coral : _isOnline ? AppColors.mint : AppColors.textLo;
    final statusText  = _hasPending ? 'ALERT' : _isOnline ? 'SYSTEM ONLINE' : 'OFFLINE';
    return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(
            width: 7, height: 7,
            decoration: BoxDecoration(
              color: statusColor, shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: statusColor.withOpacity(0.6), blurRadius: 8, spreadRadius: 1)],
            ),
          ),
          const SizedBox(width: 8),
          Text(statusText,
              style: TextStyle(color: statusColor, fontFamily: kMono, fontSize: 11,
                  letterSpacing: 2.5, fontWeight: FontWeight.w600)),
        ]),
        const SizedBox(height: 6),
        Text('Hi, $_userName 👋',
            style: const TextStyle(color: AppColors.textHi, fontSize: 24, fontWeight: FontWeight.w700)),
      ]),
      GestureDetector(
        onTap: _manualRefresh,
        child: GlowChip(_refreshing ? Icons.hourglass_top_rounded : Icons.refresh_rounded, AppColors.cyan),
      ),
    ]);
  }

  Widget _buildSentinel() {
    final color = _hasPending ? AppColors.coral : _isOnline ? AppColors.mint : AppColors.textLo;
    final title = _hasPending ? 'INTRUDER PENDING' : _isOnline ? 'VAULT ARMED' : 'OFFLINE';
    final sub   = _hasPending
        ? 'Unknown visitor awaiting your decision'
        : _isOnline
            ? 'Face ID monitoring is active'
            : 'Device not reachable right now';
    final icon  = _hasPending
        ? Icons.gpp_maybe_rounded
        : _isOnline ? Icons.verified_user_rounded : Icons.lock_open_rounded;

    return PanelCard(
      glow: color,
      borderColor: color.withOpacity(0.30),
      padding: const EdgeInsets.symmetric(vertical: 26, horizontal: 20),
      child: Column(children: [
        SentinelCore(size: 172, color: color, armed: _isOnline || _hasPending, icon: icon),
        const SizedBox(height: 20),
        Text(title,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
        const SizedBox(height: 6),
        Text(sub,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
      ]),
    );
  }

  Widget _buildPendingAlert() {
    return PanelCard(
      glow: AppColors.coral,
      borderColor: AppColors.coral.withOpacity(0.5),
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => ApprovalRequestScreen())),
      child: Row(children: [
        const GlowChip(Icons.notifications_active_rounded, AppColors.coral, size: 18, padding: 9),
        const SizedBox(width: 14),
        const Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Unknown visitor detected',
              style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700, fontSize: 14)),
          SizedBox(height: 2),
          Text('Tap to approve or reject access',
              style: TextStyle(color: AppColors.textLo, fontSize: 12)),
        ])),
        const Icon(Icons.chevron_right_rounded, color: AppColors.coral),
      ]),
    );
  }

  Widget _buildStatsGrid() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SystemLabel('Telemetry'),
      const SizedBox(height: 14),
      Row(children: [
        _statCard('Total Events',  '$_totalEvents',   Icons.equalizer_rounded,     AppColors.cyan),
        const SizedBox(width: 12),
        _statCard('Owner Access',  '$_ownerCount',    Icons.verified_user_rounded, AppColors.mint),
      ]),
      const SizedBox(height: 12),
      Row(children: [
        _statCard('Intruders',     '$_intruderCount', Icons.warning_amber_rounded, AppColors.coral),
        const SizedBox(width: 12),
        _statCard('Last Event',    _lastEvent.length > 11
            ? '${_lastEvent.substring(0, 11)}…' : _lastEvent,
            Icons.access_time_rounded, AppColors.amber),
      ]),
    ]);
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: PanelCard(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GlowChip(icon, color, size: 16, padding: 8),
          const SizedBox(height: 14),
          Text(value,
              style: const TextStyle(color: AppColors.textHi, fontFamily: kMono,
                  fontSize: 22, fontWeight: FontWeight.w700),
              maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(color: AppColors.textLo, fontSize: 11)),
        ]),
      ),
    );
  }

  Widget _buildRecentActivity() {
    final recent = _logs.reversed.take(5).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SystemLabel('Recent Activity', trailing: Text('${_logs.length} total',
          style: const TextStyle(color: AppColors.textLo, fontFamily: kMono, fontSize: 11))),
      const SizedBox(height: 14),
      if (recent.isEmpty)
        PanelCard(
          child: Center(child: Padding(
            padding: const EdgeInsets.all(6),
            child: Text('No activity yet', style: TextStyle(color: AppColors.textLo)),
          )),
        )
      else
        PanelCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: recent.asMap().entries.map((entry) {
              final i    = entry.key;
              final log  = entry.value;
              final result = log['result']?.toString() ?? '';
              final time   = log['event_time']?.toString() ?? '';
              final isOwner    = result.contains('Owner') || result.contains('Approved');
              final isIntruder = result.contains('Intruder') || result.contains('Rejected');
              final color = isOwner ? AppColors.mint : isIntruder ? AppColors.coral : AppColors.cyan;
              final icon  = isOwner
                  ? Icons.check_circle_rounded
                  : isIntruder
                      ? Icons.warning_amber_rounded
                      : Icons.info_rounded;

              return Column(children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(children: [
                    GlowChip(icon, color, size: 16, padding: 8),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(result,
                          style: const TextStyle(color: AppColors.textHi, fontSize: 13,
                              fontWeight: FontWeight.w600)),
                      if (time.isNotEmpty)
                        Text(time.length > 19 ? time.substring(0, 19) : time,
                            style: const TextStyle(color: AppColors.textLo, fontFamily: kMono, fontSize: 11)),
                    ])),
                    if (log['similarity'] != null && (log['similarity'] as num) > 0)
                      Text('${(log['similarity'] as num).toStringAsFixed(1)}%',
                          style: TextStyle(color: color, fontFamily: kMono, fontSize: 12,
                              fontWeight: FontWeight.w700)),
                  ]),
                ),
                if (i < recent.length - 1)
                  const Divider(color: AppColors.line, height: 1, indent: 14, endIndent: 14),
              ]);
            }).toList(),
          ),
        ),
    ]);
  }
}
