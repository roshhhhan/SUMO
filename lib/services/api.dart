import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io' show Platform;

import 'package:http/http.dart' as http;
import '../models/bracket.dart';

class ApiService {
  static const _timeout = Duration(seconds: 30);

  // Use localhost for desktop, 10.0.2.2 for Android emulator.
  // Try both ports so the app still works if 8080 is occupied
  // or running an older server without CRUD routes.
  static List<String> get _baseUrls {
    final host = Platform.isAndroid ? '10.0.2.2' : 'localhost';
    return [
      'http://$host:8080/api',
      'http://$host:8081/api',
      'http://$host:8082/api',
    ];
  }

  static bool _isRouteNotFound(http.Response resp) {
    if (resp.statusCode != 404) return false;
    final body = resp.body.toLowerCase();
    return body.contains('route not found');
  }

  Future<http.Response> _get(String path) async {
    Exception? lastError;
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      try {
        developer.log('GET $url');
        final resp = await http.get(Uri.parse(url)).timeout(_timeout);
        if (_isRouteNotFound(resp)) {
          lastError = Exception('Route not found at $baseUrl');
          continue;
        }
        return resp;
      } on TimeoutException catch (e) {
        lastError = Exception('Request timeout after ${_timeout.inSeconds}s ($url): $e');
      } catch (e) {
        lastError = Exception('Request failed ($url): $e');
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  Future<http.Response> _put(String path, {Map<String, String>? headers, Object? body}) async {
    Exception? lastError;
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      try {
        developer.log('PUT $url');
        final resp = await http.put(Uri.parse(url), headers: headers, body: body).timeout(_timeout);
        if (_isRouteNotFound(resp)) {
          lastError = Exception('Route not found at $baseUrl');
          continue;
        }
        return resp;
      } on TimeoutException catch (e) {
        lastError = Exception('Request timeout after ${_timeout.inSeconds}s ($url): $e');
      } catch (e) {
        lastError = Exception('Request failed ($url): $e');
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  Future<http.Response> _delete(String path) async {
    Exception? lastError;
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      try {
        developer.log('DELETE $url');
        final resp = await http.delete(Uri.parse(url)).timeout(_timeout);
        if (_isRouteNotFound(resp)) {
          lastError = Exception('Route not found at $baseUrl');
          continue;
        }
        return resp;
      } on TimeoutException catch (e) {
        lastError = Exception('Request timeout after ${_timeout.inSeconds}s ($url): $e');
      } catch (e) {
        lastError = Exception('Request failed ($url): $e');
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  Future<http.Response> _post(String path, {Map<String, String>? headers, Object? body}) async {
    Exception? lastError;
    for (final baseUrl in _baseUrls) {
      final url = '$baseUrl$path';
      try {
        developer.log('POST $url');
        final resp = await http.post(Uri.parse(url), headers: headers, body: body).timeout(_timeout);
        if (_isRouteNotFound(resp)) {
          lastError = Exception('Route not found at $baseUrl');
          continue;
        }
        return resp;
      } on TimeoutException catch (e) {
        // Avoid retrying POST on timeouts to reduce the chance of duplicate creates.
        throw Exception('Request timeout after ${_timeout.inSeconds}s ($url): $e');
      } catch (e) {
        lastError = Exception('Request failed ($url): $e');
      }
    }
    throw lastError ?? Exception('Request failed');
  }

  Future<List<Map<String, dynamic>>> getTournaments() async {
    try {
      developer.log('Fetching tournaments...');
      final resp = await _get('/tournaments');

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

  Future<Map<String, dynamic>> updateTournament(
    int id, {
    String? name,
    String? status,
  }) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (status != null) payload['status'] = status;

    if (payload.isEmpty) {
      throw Exception('Nothing to update');
    }

    try {
      developer.log('Updating tournament $id...');
      final resp = await _put(
        '/tournaments/$id',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      developer.log('Response status: ${resp.statusCode}');
      developer.log('Response body: ${resp.body}');

      if (resp.statusCode == 200) {
        final body = jsonDecode(resp.body);
        return Map<String, dynamic>.from(body as Map);
      } else {
        throw Exception('Failed to update tournament: ${resp.body}');
      }
    } catch (e) {
      developer.log('ERROR: $e');
      rethrow;
    }
  }

  Future<void> deleteTournament(int id) async {
    try {
      developer.log('Deleting tournament $id...');
      final resp = await _delete('/tournaments/$id');

      developer.log('Response status: ${resp.statusCode}');
      developer.log('Response body: ${resp.body}');

      if (resp.statusCode != 200) {
        throw Exception('Failed to delete tournament: ${resp.body}');
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
      final resp = await _post(
        '/brackets',
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'teams': teams, 'type': type}),
      );
      
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
    final resp = await _get('/brackets/$id');
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return Bracket.fromJson(body);
    } else {
      throw Exception('Bracket not found');
    }
  }

  Future<Bracket> updateMatch(
      int bracketId, int round, int index, int scoreA, int scoreB) async {
    final resp = await _put(
      '/brackets/$bracketId/match',
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'round': round,
        'index': index,
        'scoreA': scoreA,
        'scoreB': scoreB,
      }),
    );
    if (resp.statusCode == 200) {
      final body = jsonDecode(resp.body);
      return Bracket.fromJson(body);
    } else {
      throw Exception('Failed to update: ${resp.body}');
    }
  }
}
