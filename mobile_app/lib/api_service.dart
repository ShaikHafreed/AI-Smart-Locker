import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {

  static Future<Map<String, dynamic>> getStatus() async {

    print("REQUESTING FLASK...");

    final response = await http.get(
      Uri.parse(
        "http://192.168.31.229:5000/status",
      ),
    );

    print("STATUS CODE:");
    print(response.statusCode);

    print("RESPONSE:");
    print(response.body);

    return jsonDecode(response.body);
  }
}