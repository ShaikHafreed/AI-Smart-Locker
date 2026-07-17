import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme.dart';
import 'log_detail_screen.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  List<dynamic> _logs = [];
  bool _loading = true;
  bool _refreshing = false;
  String _activeFilter = 'All';
  Timer? _pollTimer;

  final List<String> _filters = ['All', 'Owner', 'Intruder', 'Approved', 'Rejected', 'Evidence'];

  @override
  void initState() {
    super.initState();
    _fetchLogs();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) => _fetchLogs(silent: true));
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  // /logs returns field "result" e.g. "Owner Verified", "Intruder Detected", "No Face Detected"
  String _getResult(dynamic log) => (log['result'] ?? '').toString();

  Future<void> _fetchLogs({bool silent = false}) async {
    if (!silent) setState(() => _refreshing = true);
    try {
      final data = await ApiService.getLogs();
      setState(() {
        _logs = data;
        _loading = false;
        _refreshing = false;
      });
    } catch (e) {
      setState(() { _loading = false; _refreshing = false; });
    }
  }

  List<dynamic> get _filteredLogs {
    if (_activeFilter == 'All') return _logs;
    return _logs.where((log) {
      final r = _getResult(log).toLowerCase();
      switch (_activeFilter) {
        case 'Owner':    return r.contains('owner') || r.contains('verified') || r.contains('granted');
        case 'Intruder': return r.contains('intruder') || r.contains('detected') || r.contains('no face');
        case 'Approved': return r.contains('approv');
        case 'Rejected': return r.contains('reject');
        case 'Evidence': return r.contains('evidence');
        default:         return true;
      }
    }).toList();
  }

  // Count by result value directly from logs list
  int _countOwners()    => _logs.where((l) { final r = _getResult(l).toLowerCase(); return r.contains('owner') || r.contains('verified'); }).length;
  int _countIntruders() => _logs.where((l) { final r = _getResult(l).toLowerCase(); return r.contains('intruder') || r.contains('no face') || r.contains('detected'); }).length;
  int _countApproved()  => _logs.where((l) => _getResult(l).toLowerCase().contains('approv')).length;
  int _countRejected()  => _logs.where((l) => _getResult(l).toLowerCase().contains('reject')).length;

  String _relativeTime(dynamic raw) {
    if (raw == null || raw.toString().isEmpty) return '—';
    try {
      final dt = DateTime.parse(raw.toString());
      final diff = DateTime.now().difference(dt);
      if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24)   return '${diff.inHours}h ago';
      return '${diff.inDays}d ago';
    } catch (_) { return raw.toString(); }
  }

  Color _resultColor(String result) {
    final r = result.toLowerCase();
    if (r.contains('owner') || r.contains('verified')) return AppColors.mint;
    if (r.contains('intruder') || r.contains('no face') || r.contains('detected')) return AppColors.coral;
    if (r.contains('approv')) return AppColors.cyan;
    if (r.contains('reject')) return AppColors.amber;
    if (r.contains('evidence')) return AppColors.violet;
    return AppColors.textLo;
  }

  IconData _resultIcon(String result) {
    final r = result.toLowerCase();
    if (r.contains('owner') || r.contains('verified')) return Icons.verified_user_rounded;
    if (r.contains('intruder') || r.contains('no face') || r.contains('detected')) return Icons.person_off_rounded;
    if (r.contains('approv')) return Icons.check_circle_rounded;
    if (r.contains('reject')) return Icons.cancel_rounded;
    if (r.contains('evidence')) return Icons.camera_alt_rounded;
    return Icons.info_outline_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredLogs;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildStatsRow(),
            const SizedBox(height: 10),
            _buildFilters(),
            const SizedBox(height: 10),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
                  : filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: AppColors.cyan,
                          backgroundColor: AppColors.surface,
                          onRefresh: () => _fetchLogs(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                            itemCount: filtered.length,
                            separatorBuilder: (_, __) => const SizedBox(height: 10),
                            itemBuilder: (_, i) => _buildLogCard(filtered[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SystemLabel('Access Logs'),
              const SizedBox(height: 6),
              Row(crossAxisAlignment: CrossAxisAlignment.baseline, textBaseline: TextBaseline.alphabetic, children: [
                Text('${_logs.length}',
                    style: const TextStyle(color: AppColors.textHi, fontFamily: kMono,
                        fontSize: 26, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                const Text('events recorded',
                    style: TextStyle(color: AppColors.textLo, fontSize: 13)),
              ]),
            ],
          ),
          GestureDetector(
            onTap: () => _fetchLogs(),
            child: GlowChip(_refreshing ? Icons.hourglass_top_rounded : Icons.refresh_rounded, AppColors.cyan),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _miniStat('Owners',    _countOwners(),    AppColors.mint),
          const SizedBox(width: 10),
          _miniStat('Intruders', _countIntruders(), AppColors.coral),
          const SizedBox(width: 10),
          _miniStat('Approved',  _countApproved(),  AppColors.cyan),
          const SizedBox(width: 10),
          _miniStat('Rejected',  _countRejected(),  AppColors.amber),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(color: color, fontFamily: kMono, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: AppColors.textLo, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final f = _filters[i];
          final active = f == _activeFilter;
          return GestureDetector(
            onTap: () => setState(() => _activeFilter = f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: active ? AppColors.cyan.withOpacity(0.14) : AppColors.panelBottom,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? AppColors.cyan : AppColors.line),
                boxShadow: active
                    ? [BoxShadow(color: AppColors.cyan.withOpacity(0.2), blurRadius: 12, spreadRadius: -4)]
                    : null,
              ),
              child: Text(f,
                  style: TextStyle(
                    color: active ? AppColors.cyan : AppColors.textLo,
                    fontSize: 13,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  )),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLogCard(dynamic log) {
    // Exact fields from /logs: result, event_time, id, image_name, similarity
    final result = _getResult(log);
    final color  = _resultColor(result);
    final time   = _relativeTime(log['event_time']);
    final similarity = log['similarity'];
    final subtitle = similarity != null
        ? 'Similarity: ${similarity.toStringAsFixed(1)}%'
        : (log['image_name'] ?? '').toString();

    return PanelCard(
      padding: EdgeInsets.zero,
      radius: 14,
      onTap: () => Navigator.push(context, MaterialPageRoute(
        builder: (_) => LogDetailScreen(log: Map<String, dynamic>.from(log as Map)),
      )),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // colored left accent
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
                boxShadow: [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, spreadRadius: -2)],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(13),
              child: GlowChip(_resultIcon(result), color, size: 18, padding: 8),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(result,
                        style: const TextStyle(color: AppColors.textHi, fontSize: 14, fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: const TextStyle(color: AppColors.textLo, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(time, style: const TextStyle(color: AppColors.textLo, fontFamily: kMono, fontSize: 11)),
                  const SizedBox(height: 4),
                  Icon(Icons.chevron_right_rounded, color: AppColors.textLo.withOpacity(0.6), size: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.history_toggle_off_rounded, color: AppColors.textLo.withOpacity(0.6), size: 52),
          const SizedBox(height: 14),
          Text('No logs for "$_activeFilter"', style: const TextStyle(color: AppColors.textLo, fontSize: 15)),
        ],
      ),
    );
  }
}
