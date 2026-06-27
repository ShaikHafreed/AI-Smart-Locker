import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../api_service.dart';

class OwnerFacesScreen extends StatefulWidget {
  const OwnerFacesScreen({Key? key}) : super(key: key);
  @override
  State<OwnerFacesScreen> createState() => _OwnerFacesScreenState();
}

class _OwnerFacesScreenState extends State<OwnerFacesScreen> {
  static const _bg            = Color(0xFF0A0E1A);
  static const _surface       = Color(0xFF111827);
  static const _card          = Color(0xFF1C2333);
  static const _border        = Color(0xFF2A3550);
  static const _cyan          = Color(0xFF00D4FF);
  static const _green         = Color(0xFF00FF88);
  static const _red           = Color(0xFFFF3B5C);
  static const _textPrimary   = Color(0xFFE8EDF5);
  static const _textSecondary = Color(0xFF6B7A99);

  static const _channel = MethodChannel('ai_locker/image_picker');

  List<dynamic> _ownerFaces = [];
  bool   _loading    = true;
  bool   _uploading  = false;
  String _statusMsg  = '';
  String _token      = '';

  // Cache for image bytes — avoids re-fetching on rebuild
  final Map<String, Uint8List?> _imageCache = {};

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('jwt_token') ?? '';
    await _fetchOwnerFaces();
  }

  Map<String, String> get _headers => {
    'ngrok-skip-browser-warning': 'true',
    'Authorization': 'Bearer $_token',
  };

  Future<void> _fetchOwnerFaces() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/owner_faces'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final faces = (data['faces'] ?? []) as List;
        setState(() { _ownerFaces = faces; _loading = false; });
        // Pre-fetch images after list loads
        for (final face in faces) {
          _fetchImageBytes(face['filename']?.toString() ?? '');
        }
      } else {
        setState(() { _loading = false; _statusMsg = '❌ Auth error ${response.statusCode}'; });
      }
    } catch (e) {
      setState(() { _loading = false; _statusMsg = '❌ $e'; });
    }
  }

  // Fetch image bytes with auth header and cache them
  Future<void> _fetchImageBytes(String filename) async {
    if (filename.isEmpty || _imageCache.containsKey(filename)) return;
    try {
      final response = await http.get(
        Uri.parse('${ApiService.baseUrl}/owner_face_image/$filename'),
        headers: _headers,
      );
      if (response.statusCode == 200) {
        if (mounted) setState(() => _imageCache[filename] = response.bodyBytes);
      } else {
        _imageCache[filename] = null;
      }
    } catch (_) {
      _imageCache[filename] = null;
    }
  }

  Future<void> _pickAndUpload(String source) async {
    try {
      final String? path = await _channel.invokeMethod('pickImage', {'source': source});
      if (path == null) return;

      setState(() { _uploading = true; _statusMsg = 'Uploading...'; });

      final request = http.MultipartRequest(
        'POST', Uri.parse('${ApiService.baseUrl}/upload_owner_face'));
      request.headers.addAll(_headers);
      request.files.add(await http.MultipartFile.fromPath('image', path));

      final response = await request.send();
      final body     = await response.stream.bytesToString();
      final data     = jsonDecode(body);

      setState(() {
        _uploading = false;
        _statusMsg = data['success'] == true ? '✅ Owner face saved!' : '❌ ${data['message']}';
        _imageCache.clear(); // clear cache so new image loads fresh
      });

      await _fetchOwnerFaces();
      Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _statusMsg = ''); });

    } on PlatformException catch (e) {
      setState(() { _uploading = false; _statusMsg = '❌ ${e.message}'; });
    } catch (e) {
      setState(() { _uploading = false; _statusMsg = '❌ $e'; });
    }
  }

  Future<void> _deleteOwnerFace(String filename) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: _surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete?', style: TextStyle(color: Color(0xFFE8EDF5))),
        content: Text('Remove "$filename"?', style: TextStyle(color: _textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false),
              child: Text('Cancel', style: TextStyle(color: _textSecondary))),
          TextButton(onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete',
                  style: TextStyle(color: Color(0xFFFF3B5C), fontWeight: FontWeight.w700))),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiService.baseUrl}/owner_faces/$filename'),
        headers: _headers,
      );
      final data = jsonDecode(response.body);
      setState(() {
        _statusMsg = data['success'] == true ? '✅ Deleted' : '❌ ${data['message']}';
        _imageCache.remove(filename);
      });
      await _fetchOwnerFaces();
      Timer(const Duration(seconds: 3), () { if (mounted) setState(() => _statusMsg = ''); });
    } catch (e) {
      setState(() => _statusMsg = '❌ $e');
    }
  }

  void _showOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: _surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 40, height: 4,
              decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 20),
          Text('Add Owner Face',
              style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Use a clear front-facing photo',
              style: TextStyle(color: _textSecondary, fontSize: 13)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); _pickAndUpload('camera'); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                    color: _cyan.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _cyan.withOpacity(0.4))),
                child: Column(children: [
                  Icon(Icons.camera_alt_rounded, color: _cyan, size: 32),
                  const SizedBox(height: 8),
                  Text('Camera', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
            const SizedBox(width: 16),
            Expanded(child: GestureDetector(
              onTap: () { Navigator.pop(context); _pickAndUpload('gallery'); },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 20),
                decoration: BoxDecoration(
                    color: _green.withOpacity(0.1), borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: _green.withOpacity(0.4))),
                child: Column(children: [
                  Icon(Icons.photo_library_rounded, color: _green, size: 32),
                  const SizedBox(height: 8),
                  Text('Gallery', style: TextStyle(color: _textPrimary, fontWeight: FontWeight.w600)),
                ]),
              ),
            )),
          ]),
          const SizedBox(height: 16),
        ]),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(),
            if (_statusMsg.isNotEmpty)
              Container(
                margin: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: _statusMsg.startsWith('✅') ? _green.withOpacity(0.1) : _red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: _statusMsg.startsWith('✅') ? _green.withOpacity(0.4) : _red.withOpacity(0.4)),
                ),
                child: Text(_statusMsg,
                    style: TextStyle(
                        color: _statusMsg.startsWith('✅') ? _green : _red,
                        fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                  color: _cyan.withOpacity(0.08), borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: _cyan.withOpacity(0.25))),
              child: Row(children: [
                Icon(Icons.info_outline_rounded, color: _cyan, size: 18),
                const SizedBox(width: 12),
                Expanded(child: Text(
                    'Add 2–3 clear front-facing photos. System compares every visitor against these.',
                    style: TextStyle(color: _textSecondary, fontSize: 12))),
              ]),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text('OWNER PHOTOS',
                  style: TextStyle(color: _textSecondary, fontSize: 11,
                      letterSpacing: 2.5, fontWeight: FontWeight.w600)),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator(color: _cyan))
                  : _uploading
                      ? Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                          const CircularProgressIndicator(color: _cyan),
                          const SizedBox(height: 16),
                          Text('Uploading...', style: TextStyle(color: _textSecondary)),
                        ]))
                      : _ownerFaces.isEmpty ? _buildEmpty() : _buildFaceGrid(),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showOptions,
        backgroundColor: _cyan,
        icon: const Icon(Icons.add_a_photo_rounded, color: Color(0xFF0A0E1A)),
        label: Text('Add Owner Face',
            style: TextStyle(color: const Color(0xFF0A0E1A), fontWeight: FontWeight.w700)),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('OWNER FACES',
              style: TextStyle(color: _textSecondary, fontSize: 11,
                  letterSpacing: 3, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text('${_ownerFaces.length} Photo${_ownerFaces.length != 1 ? 's' : ''}',
              style: TextStyle(color: _textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
        ]),
        GestureDetector(
          onTap: () { _imageCache.clear(); _fetchOwnerFaces(); },
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
                color: _card, borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _border)),
            child: const Icon(Icons.refresh_rounded, color: _cyan, size: 20),
          ),
        ),
      ]),
    );
  }

  Widget _buildFaceGrid() {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.85),
      itemCount: _ownerFaces.length,
      itemBuilder: (_, i) {
        final filename = _ownerFaces[i]['filename']?.toString() ?? '';
        return Container(
          decoration: BoxDecoration(
              color: _card, borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _border)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Expanded(child: ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              child: _buildImageWidget(filename),
            )),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(children: [
                Expanded(child: Text(filename,
                    style: TextStyle(color: _textSecondary, fontSize: 11),
                    maxLines: 1, overflow: TextOverflow.ellipsis)),
                GestureDetector(
                  onTap: () => _deleteOwnerFace(filename),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                        color: _red.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                    child: Icon(Icons.delete_outline_rounded, color: _red, size: 16),
                  ),
                ),
              ]),
            ),
          ]),
        );
      },
    );
  }

  // Build image from cached bytes — bypasses CORS/auth issues with Image.network
  Widget _buildImageWidget(String filename) {
    if (_imageCache.containsKey(filename)) {
      final bytes = _imageCache[filename];
      if (bytes != null) {
        return Image.memory(bytes, fit: BoxFit.cover);
      } else {
        return _imagePlaceholder(Icons.broken_image_rounded);
      }
    }
    // Not cached yet — show loader and trigger fetch
    _fetchImageBytes(filename);
    return _imagePlaceholder(null);
  }

  Widget _imagePlaceholder(IconData? icon) {
    return Container(
      color: _surface,
      child: Center(child: icon != null
          ? Icon(icon, color: _textSecondary, size: 40)
          : const CircularProgressIndicator(color: _cyan, strokeWidth: 2)),
    );
  }

  Widget _buildEmpty() {
    return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
            shape: BoxShape.circle, color: _cyan.withOpacity(0.08),
            border: Border.all(color: _cyan.withOpacity(0.2))),
        child: Icon(Icons.face_rounded, color: _cyan, size: 48),
      ),
      const SizedBox(height: 20),
      Text('No Owner Photos Yet',
          style: TextStyle(color: _textPrimary, fontSize: 18, fontWeight: FontWeight.w600)),
      const SizedBox(height: 8),
      Text('Tap the button below to add your face',
          style: TextStyle(color: _textSecondary, fontSize: 14)),
    ]));
  }
}