import 'package:flutter/material.dart';
import '../api_service.dart';
import '../theme.dart';
import 'image_viewer_screen.dart';

class GalleryScreen extends StatefulWidget {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  List<String> _images = [];
  Map<String, String> _headers = const {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final headers = await ApiService.imageAuthHeaders();
    final raw = await ApiService.getImages();
    if (mounted) {
      setState(() {
        _headers = headers;
        _images = raw.map((e) => e.toString()).toList();
        _loading = false;
      });
    }
  }

  Future<void> _refresh() async {
    final raw = await ApiService.getImages();
    if (mounted) setState(() => _images = raw.map((e) => e.toString()).toList());
  }

  Future<void> _open(String url) async {
    final deleted = await Navigator.push<bool>(context, MaterialPageRoute(
      builder: (_) => ImageViewerScreen(imageUrl: url, title: 'Captured Image', canDelete: true),
    ));
    if (deleted == true && mounted) {
      setState(() => _images.remove(url));
    }
  }

  String _fileNameOf(String url) {
    final seg = Uri.parse(url).pathSegments;
    return seg.isNotEmpty ? seg.last : '';
  }

  Future<void> _quickDelete(String url) async {
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

    final ok = await ApiService.deleteImage(_fileNameOf(url));
    if (!mounted) return;
    if (ok) {
      setState(() => _images.remove(url));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text("Couldn't delete image", style: TextStyle(color: AppColors.textHi)),
        backgroundColor: AppColors.surface,
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.bg,
        elevation: 0,
        iconTheme: const IconThemeData(color: AppColors.textHi),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SystemLabel('Gallery'),
            const SizedBox(height: 2),
            Text(_loading ? 'Loading…' : '${_images.length} captured images',
                style: const TextStyle(color: AppColors.textHi, fontSize: 16, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.cyan))
          : _images.isEmpty
              ? _buildEmpty()
              : Column(children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                    child: Row(children: [
                      Icon(Icons.touch_app_rounded, color: AppColors.textLo, size: 14),
                      SizedBox(width: 6),
                      Text('Tap to view · hold to delete',
                          style: TextStyle(color: AppColors.textLo, fontSize: 11)),
                    ]),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.cyan,
                      backgroundColor: AppColors.surface,
                      onRefresh: _refresh,
                      child: GridView.builder(
                        padding: const EdgeInsets.all(16),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.82,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (_, i) => _tile(_images[i]),
                      ),
                    ),
                  ),
                ]),
    );
  }

  Widget _tile(String url) {
    final isEvidence = url.contains('evidence_');
    final tag = isEvidence ? 'EVIDENCE' : 'VISITOR';
    final tagColor = isEvidence ? AppColors.coral : AppColors.cyan;
    return GestureDetector(
      onTap: () => _open(url),
      onLongPress: () => _quickDelete(url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.line),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Image.network(
                url,
                headers: _headers,
                fit: BoxFit.cover,
                gaplessPlayback: true,
                loadingBuilder: (ctx, child, progress) {
                  if (progress == null) return child;
                  return Container(
                    color: AppColors.panelBottom,
                    child: const Center(
                      child: SizedBox(width: 22, height: 22,
                          child: CircularProgressIndicator(color: AppColors.cyan, strokeWidth: 2)),
                    ),
                  );
                },
                errorBuilder: (ctx, err, st) => Container(
                  color: AppColors.panelBottom,
                  child: Icon(Icons.broken_image_rounded, color: AppColors.textLo.withOpacity(0.6)),
                ),
              ),
              // gradient scrim + tag
              Positioned(
                left: 0, right: 0, bottom: 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter, end: Alignment.topCenter,
                      colors: [Colors.black.withOpacity(0.75), Colors.transparent],
                    ),
                  ),
                  child: Row(children: [
                    Container(width: 6, height: 6,
                        decoration: BoxDecoration(color: tagColor, shape: BoxShape.circle)),
                    const SizedBox(width: 6),
                    Text(tag,
                        style: TextStyle(color: tagColor, fontFamily: kMono, fontSize: 10,
                            letterSpacing: 1.5, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    const Icon(Icons.zoom_out_map_rounded, color: Colors.white70, size: 14),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.photo_library_outlined, color: AppColors.textLo.withOpacity(0.6), size: 56),
          const SizedBox(height: 14),
          const Text('No captured images yet', style: TextStyle(color: AppColors.textLo, fontSize: 15)),
        ],
      ),
    );
  }
}
