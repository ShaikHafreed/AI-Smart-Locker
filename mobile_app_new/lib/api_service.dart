import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl =
      "https://smudgy-imminent-hankie.ngrok-free.dev";

  // Shorter timeout — fail fast instead of waiting 30s
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
    final headers = await _authHeaders();
    try {
      final results = await Future.wait([
        http.get(Uri.parse("$baseUrl/status"), headers: headers)
            .timeout(_timeout),
        http.get(Uri.parse("$baseUrl/logs"), headers: headers)
            .timeout(_timeout),
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
      final response = await http.get(
        Uri.parse("$baseUrl/status"),
        headers: await _authHeaders(),
      ).timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  static Future<List<dynamic>> getLogs() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/logs"),
        headers: await _authHeaders(),
      ).timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }

  static Future<Map<String, dynamic>> getPendingAccess() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/pending_access"),
        headers: await _authHeaders(),
      ).timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return {};
    }
  }

  static Future<void> approveAccess() async {
    try {
      await http.get(Uri.parse("$baseUrl/approve"),
          headers: await _authHeaders()).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> rejectAccess() async {
    try {
      await http.get(Uri.parse("$baseUrl/reject"),
          headers: await _authHeaders()).timeout(_timeout);
    } catch (_) {}
  }

  static Future<void> registerToken(String token) async {
    try {
      await http.post(
        Uri.parse("$baseUrl/register_token"),
        headers: await _authHeaders(),
        body: jsonEncode({"token": token}),
      ).timeout(_timeout);
    } catch (_) {}
  }

  static Future<List<dynamic>> getImages() async {
    try {
      final response = await http.get(
        Uri.parse("$baseUrl/images"),
        headers: await _authHeaders(),
      ).timeout(_timeout);
      return jsonDecode(response.body);
    } catch (e) {
      return [];
    }
  }
}