import 'dart:async';
import 'package:flutter/material.dart';
import '../api_service.dart';

class LogsScreen extends StatefulWidget {
  const LogsScreen({Key? key}) : super(key: key);

  @override
  State<LogsScreen> createState() => _LogsScreenState();
}

class _LogsScreenState extends State<LogsScreen> {
  static const _bg = Color(0xFF0A0E1A);
  static const _surface = Color(0xFF111827);
  static const _card = Color(0xFF1C2333);
  static const _border = Color(0xFF2A3550);
  static const _cyan = Color(0xFF00D4FF);
  static const _green = Color(0xFF00FF88);
  static const _red = Color(0xFFFF3B5C);
  static const _amber = Color(0xFFFFB800);
  static const _purple = Color(0xFFB48EFF);
  static const _textPrimary = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF6B7A99);

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
    if (r.contains('owner') || r.contains('verified')) return _green;
    if (r.contains('intruder') || r.contains('no face') || r.contains('detected')) return _red;
    if (r.contains('approv')) return _cyan;
    if (r.contains('reject')) return _amber;
    if (r.contains('evidence')) return _purple;
    return _textSecondary;
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
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            _buildStatsRow(),
            const SizedBox(height: 8),
            _buildFilters(),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _cyan))
                  : filtered.isEmpty
                      ? _buildEmpty()
                      : RefreshIndicator(
                          color: _cyan,
                          backgroundColor: _surface,
                          onRefresh: () => _fetchLogs(),
                          child: ListView.separated(
                            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
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
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ACCESS LOGS',
                  style: TextStyle(color: _textSecondary, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text('${_logs.length} Events',
                  style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
            ],
          ),
          GestureDetector(
            onTap: () => _fetchLogs(),
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
      ),
    );
  }

  Widget _buildStatsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      child: Row(
        children: [
          _miniStat('Owners',    _countOwners(),    _green),
          const SizedBox(width: 10),
          _miniStat('Intruders', _countIntruders(), _red),
          const SizedBox(width: 10),
          _miniStat('Approved',  _countApproved(),  _cyan),
          const SizedBox(width: 10),
          _miniStat('Rejected',  _countRejected(),  _amber),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int count, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Text('$count', style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: _textSecondary, fontSize: 10)),
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return SizedBox(
      height: 42,
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
                color: active ? _cyan : _card,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: active ? _cyan : _border),
              ),
              child: Text(f,
                  style: TextStyle(
                    color: active ? _bg : _textSecondary,
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

    return Container(
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // colored left border
            Container(
              width: 4,
              decoration: BoxDecoration(
                color: color,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  bottomLeft: Radius.circular(14),
                ),
              ),
            ),
            // icon
            Padding(
              padding: const EdgeInsets.all(14),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(_resultIcon(result), color: color, size: 18),
              ),
            ),
            // text
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(result,
                        style: TextStyle(color: _textPrimary, fontSize: 14, fontWeight: FontWeight.w600)),
                    if (subtitle.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(subtitle,
                          style: TextStyle(color: _textSecondary, fontSize: 12),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
            ),
            // time
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 14, 14),
              child: Text(time, style: TextStyle(color: _textSecondary, fontSize: 11)),
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
          Icon(Icons.history_toggle_off_rounded, color: _textSecondary, size: 48),
          const SizedBox(height: 14),
          Text('No logs for "$_activeFilter"', style: TextStyle(color: _textSecondary, fontSize: 15)),
        ],
      ),
    );
  }
}