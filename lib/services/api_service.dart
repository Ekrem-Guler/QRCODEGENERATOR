import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = 'https://web-production-46712.up.railway.app';

  Future<Map<String, dynamic>> generateQR({
    required String type,
    required Map<String, String> data,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/generate'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'type': type,
          'data': data,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to generate QR code');
      }
    } catch (e) {
      throw Exception('Connection error: $e');
    }
  }
}
