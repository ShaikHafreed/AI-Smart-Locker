import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  // Fast path — only reachable on the same local WiFi network.
  static const String _localUrl = "http://192.168.31.229:5000";
  // Fallback — a public tunnel, reachable from anywhere (mobile data, etc.).
  static const String _publicUrl = "https://smudgy-imminent-hankie.ngrok-free.dev";

  /// Current best-known base URL. Starts local (fastest on WiFi); any
  /// request that fails while on local auto-retries against the public
  /// tunnel and, on success, switches for the rest of the session — so
  /// WiFi stays fast and mobile data still works without any user action.
  static String baseUrl = _localUrl;

  static const _timeout = Duration(seconds: 10);

  // Cache for token — avoid reading SharedPreferences on every call
  static String? _cachedToken;

  static Future<String> _getToken() async {
    if (_cachedToken != null) return _cachedToken!;
    final prefs = await SharedPreferences.getInstance();
    _cachedToken = prefs.getString('jwt_token') ?? '';
    return _cachedToken!;
  }

  static void clearTokenCache() => _cachedToken = null;

  static Future<Map<String, String>> _authHeaders() async {
    final token = await _getToken();
    return {
      "ngrok-skip-browser-warning": "true",
      "Content-Type": "application/json",
      "Authorization": "Bearer $token",
    };
  }

  // ── Core request helpers with local→public fallback ──────────

  static bool _isNetworkFailure(Object e) =>
      e is! FormatException; // anything but a bad-response-body counts as unreachable

  static Future<http.Response> _get(String path, {Map<String, String>? headers}) async {
    final h = headers ?? await _authHeaders();
    try {
      return await http.get(Uri.parse("$baseUrl$path"), headers: h).timeout(_timeout);
    } catch (e) {
      if (baseUrl == _localUrl && _isNetworkFailure(e)) {
        baseUrl = _publicUrl;
        return await http.get(Uri.parse("$baseUrl$path"), headers: h).timeout(_timeout);
      }
      rethrow;
    }
  }

  static Future<http.Response> _post(String path, {Map<String, String>? headers, Object? body}) async {
    final h = headers ?? await _authHeaders();
    try {
      return await http.post(Uri.parse("$baseUrl$path"), headers: h, body: body).timeout(_timeout);
    } catch (e) {
      if (baseUrl == _localUrl && _isNetworkFailure(e)) {
        baseUrl = _publicUrl;
        return await http.post(Uri.parse("$baseUrl$path"), headers: h, body: body).timeout(_timeout);
      }
      rethrow;
    }
  }

  static Future<http.Response> _delete(String path, {Map<String, String>? headers}) async {
    final h = headers ?? await _authHeaders();
    try {
      return await http.delete(Uri.parse("$baseUrl$path"), headers: h).timeout(_timeout);
    } catch (e) {
      if (baseUrl == _localUrl && _isNetworkFailure(e)) {
        baseUrl = _publicUrl;
        return await http.delete(Uri.parse("$baseUrl$path"), headers: h).timeout(_timeout);
      }
      rethrow;
    }
  }

  /// Public POST with local→public fallback, for pre-login calls (OTP,
  /// Google sign-in) that don't have a JWT yet and must pass their own
  /// headers rather than using [_authHeaders].
  static Future<http.Response> publicPost(String path, {required Map<String, String> headers, Object? body}) =>
      _post(path, headers: headers, body: body);

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return (prefs.getString('jwt_token') ?? '').isNotEmpty;
  }

  static Future<Map<String, String>> getUserInfo() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'name':  prefs.getString('user_name')  ?? 'Owner',
      'phone': prefs.getString('user_phone') ?? '',
      'email': prefs.getString('user_email') ?? '',
    };
  }

  static Future<void> logout() async {
    clearTokenCache();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('jwt_token');
    await prefs.remove('user_name');
    await prefs.remove('user_phone');
    await prefs.remove('user_email');
  }

  // Fetch status and logs in PARALLEL — halves loading time
  static Future<Map<String, dynamic>> getDashboardData() async {
    try {
      final headers = await _authHeaders();
      final results = await Future.wait([
        _get("/status", headers: headers),
        _get("/logs", headers: headers),
      ]);

      final status = jsonDecode(results[0].body) as Map<String, dynamic>;
      final logs   = jsonDecode(results[1].body) as List<dynamic>;

      return {'status': status, 'logs': logs};
    } catch (e) {
      return {'status': {}, 'logs': []};
    }
  }

  static Future<Map<String, dynamic>> getStatus() async {
    try {
      final response = await _get("/status");
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<List<dynamic>> getLogs() async {
    try {
      final response = await _get("/logs");
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getPendingAccess() async {
    try {
      final response = await _get("/pending_access");
      return jsonDecode(response.body);
    } catch (e) {
      return {};
    }
  }

  static Future<void> approveAccess() async {
    try {
      await _get("/approve");
    } catch (_) {}
  }

  static Future<void> rejectAccess() async {
    try {
      await _get("/reject");
    } catch (_) {}
  }

  static Future<void> registerToken(String token) async {
    try {
      await _post("/register_token", body: jsonEncode({"token": token}));
    } catch (_) {}
  }

  static Future<List<dynamic>> getImages() async {
    try {
      final response = await _get("/images");
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  // ── Images: auth-aware loading, fetching, and URL building ──

  /// Header map for loading a JWT-protected image straight into
  /// Image.network(url, headers: ...). Resolve once, reuse for a page.
  static Future<Map<String, String>> imageAuthHeaders() async {
    final token = await _getToken();
    return {
      "ngrok-skip-browser-warning": "true",
      "Authorization": "Bearer $token",
    };
  }

  /// Fetch raw image bytes with auth — used to save/share an image.
  /// [url] should be built from [imageUrl] so it always targets the
  /// currently active base URL.
  static Future<Uint8List?> getImageBytes(String url) async {
    try {
      final token = await _getToken();
      final headers = {
        "ngrok-skip-browser-warning": "true",
        "Authorization": "Bearer $token",
      };
      var resp = await http.get(Uri.parse(url), headers: headers)
          .timeout(const Duration(seconds: 20));
      if (resp.statusCode == 200) return resp.bodyBytes;
      return null;
    } catch (e) {
      // If the URL was built against the local base and that's unreachable,
      // retry once against the public tunnel.
      if (baseUrl == _localUrl && url.startsWith(_localUrl) && _isNetworkFailure(e)) {
        baseUrl = _publicUrl;
        final retryUrl = url.replaceFirst(_localUrl, _publicUrl);
        try {
          final token = await _getToken();
          final resp = await http.get(Uri.parse(retryUrl), headers: {
            "ngrok-skip-browser-warning": "true",
            "Authorization": "Bearer $token",
          }).timeout(const Duration(seconds: 20));
          if (resp.statusCode == 200) return resp.bodyBytes;
        } catch (_) {}
      }
      return null;
    }
  }

  /// Build the URL for a stored image filename (used by log details).
  static String imageUrl(String imageName) => "$baseUrl/image/$imageName";

  /// Deletes a gallery image on the server by its filename.
  static Future<bool> deleteImage(String imageName) async {
    try {
      final resp = await _delete("/image/$imageName");
      final data = jsonDecode(resp.body);
      return data['success'] == true;
    } catch (_) {
      return false;
    }
  }
}
