import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../api_service.dart';
import '../native_media.dart';
import '../theme.dart';

/// Full-screen, zoomable image viewer that loads a JWT-protected image and
/// offers Save-to-gallery and Share (WhatsApp, etc.) actions. The image is
/// downloaded once and the bytes are reused for display and both actions.
/// When [canDelete] is true, a Delete action is also shown; on successful
/// deletion the screen pops with `true` so the caller can remove it locally.
class ImageViewerScreen extends StatefulWidget {
  final String imageUrl;
  final String title;
  final String? subtitle;
  final bool canDelete;
  const ImageViewerScreen({
    super.key,
    required this.imageUrl,
    this.title = 'Image',
    this.subtitle,
    this.canDelete = false,
  });

  @override
  State<ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<ImageViewerScreen> {
  Uint8List? _bytes;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await ApiService.getImageBytes(widget.imageUrl);
    if (mounted) setState(() { _bytes = data; _loading = false; });
  }

  String get _fileName {
    final seg = Uri.parse(widget.imageUrl).pathSegments;
    final last = seg.isNotEmpty ? seg.last : 'locker_image.jpg';
    return last.isEmpty ? 'locker_image.jpg' : last;
  }

  void _toast(String msg, Color color) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(color: AppColors.textHi)),
      backgroundColor: AppColors.surface,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: color.withOpacity(0.5)),
      ),
    ));
  }

  Future<void> _save() async {
    if (_bytes == null || _busy) return;
    setState(() => _busy = true);
    final ok = await NativeMedia.saveToGallery(_bytes!, _fileName);
    setState(() => _busy = false);
    _toast(ok ? 'Saved to your gallery' : "Couldn't save image", ok ? AppColors.mint : AppColors.coral);
  }

  Future<void> _share() async {
    if (_bytes == null || _busy) return;
    setState(() => _busy = true);
    await NativeMedia.shareImage(_bytes!, _fileName,
        text: 'AI Smart Cupboard — ${widget.title}');
    setState(() => _busy = false);
  }

  Future<void> _confirmDelete() async {
    if (_busy) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AppColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Image', style: TextStyle(color: AppColors.textHi)),
        content: const Text('This removes the image from the server permanently.',
            style: TextStyle(color: AppColors.textLo)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: AppColors.textLo)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete',
                style: TextStyle(color: AppColors.coral, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    final ok = await ApiService.deleteImage(_fileName);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      Navigator.pop(context, true);
    } else {
      _toast("Couldn't delete image", AppColors.coral);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHi),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title,
                style: const TextStyle(color: AppColors.textHi, fontSize: 16, fontWeight: FontWeight.w700)),
            if (widget.subtitle != null)
              Text(widget.subtitle!,
                  style: const TextStyle(color: AppColors.textLo, fontFamily: kMono, fontSize: 11)),
          ],
        ),
      ),
      body: Center(
        child: _loading
            ? const CircularProgressIndicator(color: AppColors.cyan)
            : _bytes == null
                ? Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.broken_image_rounded, color: AppColors.textLo.withOpacity(0.6), size: 56),
                    const SizedBox(height: 12),
                    const Text('Image unavailable', style: TextStyle(color: AppColors.textLo)),
                  ])
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Image.memory(_bytes!, fit: BoxFit.contain),
                  ),
      ),
      bottomNavigationBar: (_loading || _bytes == null)
          ? null
          : Container(
              decoration: const BoxDecoration(
                color: AppColors.bg,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    Expanded(child: _actionButton('Save', Icons.download_rounded, AppColors.cyan, _save)),
                    const SizedBox(width: 12),
                    Expanded(child: _actionButton('Share', Icons.share_rounded, AppColors.mint, _share)),
                    if (widget.canDelete) ...[
                      const SizedBox(width: 12),
                      Expanded(child: _actionButton('Delete', Icons.delete_outline_rounded, AppColors.coral, _confirmDelete)),
                    ],
                  ]),
                ),
              ),
            ),
    );
  }

  Widget _actionButton(String label, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: _busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: color.withOpacity(_busy ? 0.06 : 0.12),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.35)),
          boxShadow: _busy ? null : [BoxShadow(color: color.withOpacity(0.18), blurRadius: 14, spreadRadius: -4)],
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _busy
              ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: color, strokeWidth: 2))
              : Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Text(label, style: TextStyle(color: color, fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
