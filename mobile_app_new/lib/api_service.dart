import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static const String baseUrl =
    "http://192.168.31.172:5000";

  // =========================
  // LOCKER STATUS
  // =========================

  static Future<Map<String, dynamic>>
      getStatus() async {

    final response = await http.get(
      Uri.parse(
        "$baseUrl/status",
      ),
    );

    return jsonDecode(
      response.body,
    );
  }

  // =========================
  // IMAGES
  // =========================

  static Future<List<dynamic>>
      getImages() async {

    final response = await http.get(
      Uri.parse(
        "$baseUrl/images",
      ),
    );

    return jsonDecode(
      response.body,
    );
  }

  // =========================
  // ACCESS LOGS
  // =========================

  static Future<List<dynamic>>
      getLogs() async {

    final response = await http.get(
      Uri.parse(
        "$baseUrl/logs",
      ),
    );

    return jsonDecode(
      response.body,
    );
  }

  // =========================
  // PENDING ACCESS
  // =========================

static Future<Map<String, dynamic>>
    getPendingAccess() async {

  try {

    final response = await http.get(
      Uri.parse(
        "$baseUrl/pending_access",
      ),
    );

    print(
      "PENDING ACCESS => ${response.body}",
    );

    return jsonDecode(
      response.body,
    );

  } catch (e) {

    print(
      "ERROR => $e",
    );

    return {
      "status": "ERROR",
      "result": e.toString(),
      "image": ""
    };
  }
}

  // =========================
  // APPROVE ACCESS
  // =========================

  static Future<void>
      approveAccess() async {

    await http.get(
      Uri.parse(
        "$baseUrl/approve",
      ),
    );
  }

  // =========================
  // REJECT ACCESS
  // =========================

  static Future<void>
      rejectAccess() async {

    await http.get(
      Uri.parse(
        "$baseUrl/reject",
      ),
    );
  }
}