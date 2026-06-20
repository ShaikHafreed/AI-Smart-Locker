import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl =
      "http://192.168.31.172:5000";

  static Future<Map<String, dynamic>>
      getStatus() async {
    final response = await http.get(
      Uri.parse("$baseUrl/status"),
    );

    return jsonDecode(response.body);
  }

  static Future<List<dynamic>>
      getLogs() async {
    final response = await http.get(
      Uri.parse("$baseUrl/logs"),
    );

    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>>
      getPendingAccess() async {
    final response = await http.get(
      Uri.parse(
        "$baseUrl/pending_access",
      ),
    );

    return jsonDecode(response.body);
  }

  static Future<void>
      approveAccess() async {
    await http.get(
      Uri.parse("$baseUrl/approve"),
    );
  }

  static Future<void>
      rejectAccess() async {
    await http.get(
      Uri.parse("$baseUrl/reject"),
    );
  }

  static Future<void>
      registerToken(
    String token,
  ) async {
    await http.post(
      Uri.parse(
        "$baseUrl/register_token",
      ),
      headers: {
        "Content-Type":
            "application/json",
      },
      body: jsonEncode({
        "token": token,
      }),
    );
  }
  static Future<List<dynamic>>
    getImages() async {

  final response = await http.get(
    Uri.parse("$baseUrl/images"),
  );

  return jsonDecode(
    response.body,
  );
}
}