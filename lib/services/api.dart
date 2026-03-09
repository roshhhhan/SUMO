import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import '../models/bracket.dart';

class ApiService {
  // Use localhost for desktop, 10.0.2.2 for Android emulator
  static String get _baseUrl {
    if (Platform.isAndroid) {
      return 'http://10.0.2.2:8080/api'; // Android emulator
    } else {
      return 'http://localhost:8080/api'; // Desktop/web
    }
  }
  static const _timeout = Duration(seconds: 30);

  Future<List<Map<String, dynamic>>> getTournaments() async {
    try {
      developer.log('Fetching tournaments...');
      developer.log('GET $_baseUrl/tournaments');

      final resp = await http.get(Uri.parse('$_baseUrl/tournaments')).timeout(_timeout, onTimeout: () {
        throw Exception('Request timeout after ${_timeout.inSeconds}s');
      });

      developer.log('Response status: ${resp.statusCode}');
      developer.log('Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final List<dynamic> body = jsonDecode(resp.body);
        return body.map((item) => Map<String, dynamic>.from(item as Map)).toList();
      } else {
        throw Exception('Failed to fetch tournaments: ${resp.body}');
      }
    } catch (e) {
      developer.log('ERROR: $e');
      rethrow;
    }
  }

  Future<Bracket> createBracket(
      String name, List<String> teams, String type) async {
    try {
      developer.log('Creating bracket: $name with ${teams.length} teams');
      developer.log('POST $_baseUrl/brackets');
      
      final resp = await http.post(Uri.parse('$_baseUrl/brackets'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({'name': name, 'teams': teams, 'type': type}))
          .timeout(_timeout, onTimeout: () {
        throw Exception('Request timeout after ${_timeout.inSeconds}s');
      });
      
      developer.log('Response status: ${resp.statusCode}');
      developer.log('Response body: ${resp.body}');
      
      if (resp.statusCode == 201) {
        final body = jsonDecode(resp.body);
        return Bracket.fromJson(body);
      } else {
        throw Exception('Failed to create bracket: ${resp.body}');
      }
    } catch (e) {
      developer.log('ERROR: $e');
      rethrow;
    }
  }

  Future<Bracket> getBracket(int id) async {
    final resp = await http.get(Uri.parse('$_baseUrl/brackets/$id'));
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return Bracket.fromJson(body);
    } else {
      throw Exception('Bracket not found');
    }
  }

  Future<Bracket> updateMatch(
      int bracketId, int round, int index, int scoreA, int scoreB) async {
    final resp = await http.put(
        Uri.parse('$_baseUrl/brackets/$bracketId/match'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'round': round,
          'index': index,
          'scoreA': scoreA,
          'scoreB': scoreB
        }));
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return Bracket.fromJson(body);
    } else {
      throw Exception('Failed to update: ${resp.body}');
    }
  }
}
