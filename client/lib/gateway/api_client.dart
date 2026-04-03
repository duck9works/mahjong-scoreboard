import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? AppConfig.baseUrl;

  Future<Map<String, dynamic>> postJson(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.post(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    final map = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return map;
    }

    final err = (map['error'] as Map<String, dynamic>?)?['message'];
    throw Exception(err ?? 'HTTP ${res.statusCode}');
  }

  Future<Map<String, dynamic>> getJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.get(uri);
    final map = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return map;
    }

    final err = (map['error'] as Map<String, dynamic>?)?['message'];
    throw Exception(err ?? 'HTTP ${res.statusCode}');
  }

  Future<Map<String, dynamic>> putJson(
      String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.put(uri,
        headers: {'Content-Type': 'application/json'}, body: jsonEncode(body));
    final map = jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return map;
    }

    final err = (map['error'] as Map<String, dynamic>?)?['message'];
    throw Exception(err ?? 'HTTP ${res.statusCode}');
  }

  Future<Map<String, dynamic>> deleteJson(String path) async {
    final uri = Uri.parse('$baseUrl$path');
    final res = await http.delete(uri);
    final map = res.body.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(res.body) as Map<String, dynamic>;

    if (res.statusCode >= 200 && res.statusCode < 300) {
      return map;
    }

    final err = (map['error'] as Map<String, dynamic>?)?['message'];
    throw Exception(err ?? 'HTTP ${res.statusCode}');
  }
}
