import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static String baseUrl =
      "http://192.168.31.229:5000";

  static Future<Map<String, dynamic>> getStatus() async {

    final response =
        await http.get(
      Uri.parse("$baseUrl/status"),
    );

    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getImages() async {

    final response =
        await http.get(
      Uri.parse("$baseUrl/images"),
    );

    return jsonDecode(response.body);
  }
}