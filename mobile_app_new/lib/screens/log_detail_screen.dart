import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme.dart';
import 'image_viewer_screen.dart';

/// Detail view for a single access-log event: result, full date/time,
/// similarity, and the image captured at that moment (tap to zoom / save / share).
class LogDetailScreen extends StatefulWidget {
  final Map<String, dynamic> log;
  const LogDetailScreen({super.key, required this.log});

  @override
  State<LogDetailScreen> createState() => _LogDetailScreenState();
}

class _LogDetailScreenState extends State<LogDetailScreen> {
  Map<String, String> _headers = const {};
  bool _headersReady = false;

  @override
  void initState() {
    super.initState();
    ApiService.imageAuthHeaders().then((h) {
      if (mounted) setState(() { _headers = h; _headersReady = true; });
    });
  }

  String get _result => (widget.log['result'] ?? '').toString();
  String get _imageName => (widget.log['image_name'] ?? '').toString();

  bool get _hasImage {
    final n = _imageName.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png');
  }

  String get _imageUrl => ApiService.imageUrl(_imageName);

  Color get _color {
    final r = _result.toLowerCase();
    if (r.contains('owner') || r.contains('verified')) return AppColors.mint;
    if (r.contains('intruder') || r.contains('no face') || r.contains('detected')) return AppColors.coral;
    if (r.contains('approv')) return AppColors.cyan;
    if (r.contains('reject')) return AppColors.amber;
    if (r.contains('evidence')) return AppColors.violet;
    return AppColors.textLo;
  }

  IconData get _icon {
    final r = _result.toLowerCase();
    if (r.contains('owner') || r.contains('verified')) return Icons.verified_user_rounded;
    if (r.contains('intruder') || r.contains('no face') || r.contains('detected')) return Icons.person_off_rounded;
    if (r.contains('approv')) return Icons.check_circle_rounded;
    if (r.contains('reject')) return Icons.cancel_rounded;
    if (r.contains('evidence')) return Icons.camera_alt_rounded;
    return Icons.info_outline_rounded;
  }

  static const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];

  DateTime? get _dt {
    final raw = (widget.log['event_time'] ?? '').toString();
    if (raw.isEmpty) return null;
    try { return DateTime.parse(raw); } catch (_) { return null; }
  }

  String _fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

  String _fmtTime(DateTime d) {
    final ampm = d.hour >= 12 ? 'PM' : 'AM';
    var h = d.hour % 12; if (h == 0) h = 12;
    final m = d.minute.toString().padLeft(2, '0');
    final s = d.second.toString().padLeft(2, '0');
    return '$h:$m:$s $ampm';
  }

  String _relative(DateTime d) {
    final diff = DateTime.now().difference(d);
    if (diff.inSeconds < 60) return '${diff.inSeconds}s ago';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  void _openImage() {
    Navigator.push(context, MaterialPageRoute(
      builder: (_) => ImageViewerScreen(
        imageUrl: _imageUrl,
        title: _result.isEmpty ? 'Captured Image' : _result,
        subtitle: _dt != null ? '${_fmtDate(_dt!)} · ${_fmtTime(_dt!)}' : null,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final dt = _dt;
    final similarity = widget.log['similarity'];
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHi),
        title: const SystemLabel('Event Detail'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Hero
          PanelCard(
            glow: _color,
            borderColor: _color.withOpacity(0.30),
            padding: const EdgeInsets.all(20),
            child: Row(children: [
              GlowChip(_icon, _color, size: 26, padding: 14),
              const SizedBox(width: 16),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(_result.isEmpty ? 'Event' : _result,
                    style: TextStyle(color: _color, fontSize: 18, fontWeight: FontWeight.w800)),
                if (dt != null) ...[
                  const SizedBox(height: 4),
                  Text(_relative(dt),
                      style: const TextStyle(color: AppColors.textLo, fontFamily: kMono, fontSize: 12)),
                ],
              ])),
            ]),
          ),
          const SizedBox(height: 22),

          const SystemLabel('Details'),
          const SizedBox(height: 14),
          PanelCard(
            child: Column(children: [
              _row('Date', dt != null ? _fmtDate(dt) : '—'),
              const Divider(color: AppColors.line, height: 1),
              _row('Time', dt != null ? _fmtTime(dt) : '—'),
              const Divider(color: AppColors.line, height: 1),
              _row('Result', _result.isEmpty ? '—' : _result),
              if (similarity != null && (similarity as num) > 0) ...[
                const Divider(color: AppColors.line, height: 1),
                _row('Similarity', '${(similarity).toStringAsFixed(1)}%', valueColor: _color),
              ],
              if (widget.log['id'] != null) ...[
                const Divider(color: AppColors.line, height: 1),
                _row('Event ID', '#${widget.log['id']}'),
              ],
              if (_imageName.isNotEmpty) ...[
                const Divider(color: AppColors.line, height: 1),
                _row('File', _imageName),
              ],
            ]),
          ),
          const SizedBox(height: 22),

          const SystemLabel('Captured Image'),
          const SizedBox(height: 14),
          if (!_hasImage)
            PanelCard(
              child: Row(children: [
                Icon(Icons.image_not_supported_rounded, color: AppColors.textLo.withOpacity(0.7), size: 20),
                const SizedBox(width: 12),
                const Expanded(child: Text('No image was captured for this event',
                    style: TextStyle(color: AppColors.textLo, fontSize: 13))),
              ]),
            )
          else if (!_headersReady)
            const SizedBox(height: 220, child: Center(child: CircularProgressIndicator(color: AppColors.cyan)))
          else
            GestureDetector(
              onTap: _openImage,
              child: PanelCard(
                padding: const EdgeInsets.all(6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Stack(children: [
                    Image.network(
                      _imageUrl,
                      headers: _headers,
                      width: double.infinity,
                      height: 320,
                      fit: BoxFit.cover,
                      loadingBuilder: (ctx, child, progress) {
                        if (progress == null) return child;
                        return Container(height: 320, color: AppColors.panelBottom,
                            child: const Center(child: CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2)));
                      },
                      errorBuilder: (ctx, e, st) => Container(height: 320, color: AppColors.panelBottom,
                          child: Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textLo.withOpacity(0.6), size: 40))),
                    ),
                    Positioned(
                      right: 10, bottom: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(Icons.zoom_out_map_rounded, color: Colors.white, size: 14),
                          SizedBox(width: 6),
                          Text('Tap to view · save · share',
                              style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                        ]),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ]),
      ),
    );
  }

  Widget _row(String key, String value, {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(key, style: const TextStyle(color: AppColors.textLo, fontSize: 13)),
          const SizedBox(width: 16),
          Expanded(child: Text(value,
              textAlign: TextAlign.right,
              style: TextStyle(color: valueColor ?? AppColors.textHi, fontSize: 13,
                  fontWeight: FontWeight.w600, fontFamily: kMono))),
        ],
      ),
    );
  }
}
