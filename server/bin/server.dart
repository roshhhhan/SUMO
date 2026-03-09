import 'dart:convert';
import 'dart:math';

import 'package:mysql1/mysql1.dart';
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:logging/logging.dart';

import 'package:sumo_bracket_server/env_loader.dart';

// simple server for bracket management

late MySqlConnection _conn;

Future<void> main(List<String> args) async {
  // configure logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((rec) => print(rec));

  final host = getEnv('DB_HOST', defaultValue: 'localhost');
  final port = int.tryParse(getEnv('DB_PORT', defaultValue: '3306')) ?? 3306;
  final user = getEnv('DB_USER', defaultValue: 'root');
  final pass = getEnv('DB_PASS', defaultValue: '');
  final dbName = getEnv('DB_NAME', defaultValue: 'sumo');
  final serverPort = int.parse(getEnv('PORT', defaultValue: '8080'));

  print('Connecting to MySQL: host=$host port=$port user=$user db=$dbName');

  final settings = pass.isEmpty
    ? ConnectionSettings(
        host: host,
        port: port,
        user: user,
        db: dbName,
      )
    : ConnectionSettings(
        host: host,
        port: port,
        user: user,
        password: pass,
        db: dbName,
      );

  try {
    _conn = await MySqlConnection.connect(settings);
    print('✓ Connected to MySQL');
  } catch (e) {
    print('✗ Failed to connect: $e');
    print('Check that XAMPP MySQL is running and credentials are correct.');
    rethrow;
  }

  await _ensureTables();

  final router = Router()
    ..get('/api/tournaments', _getTournaments)
    ..put('/api/tournaments/<id>', _updateTournament)
    ..delete('/api/tournaments/<id>', _deleteTournament)
    ..post('/api/brackets', _createBracket)
    ..get('/api/brackets/<id>', _getBracket)
    ..put('/api/brackets/<id>/match', _updateMatch);

  final handler = const Pipeline()
      .addMiddleware(logRequests())
      .addHandler(router.call);

  print('🚀 Listening on http://0.0.0.0:$serverPort');
  await io.serve(handler, '0.0.0.0', serverPort);
}

/// PUT /api/tournaments/:id
/// body: { "name": "...", "status": "in_progress|completed|upcoming" }
Future<Response> _updateTournament(Request req, String id) async {
  Map<String, dynamic> body;
  try {
    body = jsonDecode(await req.readAsString()) as Map<String, dynamic>;
  } catch (e) {
    return Response(
      400,
      body: jsonEncode({'error': 'Invalid JSON body'}),
      headers: {'content-type': 'application/json'},
    );
  }

  final name = body['name']?.toString();
  final status = body['status']?.toString();

  if ((name == null || name.trim().isEmpty) && status == null) {
    return Response(
      400,
      body: jsonEncode({'error': 'Provide at least one of: name, status'}),
      headers: {'content-type': 'application/json'},
    );
  }

  if (status != null) {
    const allowed = {'in_progress', 'completed', 'upcoming'};
    if (!allowed.contains(status)) {
      return Response(
        400,
        body: jsonEncode({'error': 'Invalid status: $status'}),
        headers: {'content-type': 'application/json'},
      );
    }
  }

  final existing = await _conn.query(
    'SELECT id, name, status, structure, created_at, updated_at FROM brackets WHERE id = ?',
    [id],
  );
  if (existing.isEmpty) return Response.notFound('tournament not found');

  final row = existing.first;
  final nextName = (name != null && name.trim().isNotEmpty) ? name.trim() : row['name']?.toString();
  final nextStatus = status ?? row['status']?.toString();

  await _conn.query(
    'UPDATE brackets SET name = ?, status = ? WHERE id = ?',
    [nextName, nextStatus, id],
  );

  final updated = await _conn.query(
    'SELECT id, name, status, structure, created_at, updated_at FROM brackets WHERE id = ?',
    [id],
  );
  if (updated.isEmpty) return Response.notFound('tournament not found');

  final updatedRow = updated.first;
  final structure = jsonDecode(updatedRow['structure'].toString());
  final tournament = {
    'id': updatedRow['id'],
    'name': updatedRow['name'],
    'status': updatedRow['status'],
    'type': structure['type'] ?? 'single',
    'teams': (structure['teams'] as List?)?.length ?? 0,
    'created': updatedRow['created_at'].toString(),
    'updated': updatedRow['updated_at'].toString(),
  };

  return Response.ok(
    jsonEncode(tournament),
    headers: {'content-type': 'application/json'},
  );
}

/// DELETE /api/tournaments/:id
Future<Response> _deleteTournament(Request req, String id) async {
  final result = await _conn.query('DELETE FROM brackets WHERE id = ?', [id]);
  if (result.affectedRows == 0) return Response.notFound('tournament not found');
  return Response.ok(
    jsonEncode({'deleted': true, 'id': int.tryParse(id) ?? id}),
    headers: {'content-type': 'application/json'},
  );
}

Future<void> _ensureTables() async {
  // create database and table if missing
  await _conn.query('CREATE DATABASE IF NOT EXISTS sumo');
  await _conn.query('USE sumo');

  // Create brackets table with basic schema first
  try {
    await _conn.query('''
      CREATE TABLE IF NOT EXISTS brackets (
        id INT AUTO_INCREMENT PRIMARY KEY,
        name VARCHAR(100),
        structure JSON,
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
      )
    ''');
  } catch (e) {
    print('Brackets table: $e');
  }

  // Add missing columns to existing table
  try {
    await _conn.query('ALTER TABLE brackets ADD COLUMN status VARCHAR(50) DEFAULT "in_progress"');
    print('✓ Added status column');
  } catch (e) {
    // Column likely already exists
  }

  try {
    await _conn.query('ALTER TABLE brackets ADD COLUMN updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP');
    print('✓ Added updated_at column');
  } catch (e) {
    // Column likely already exists
  }

  // Create scores table
  try {
    await _conn.query('''
      CREATE TABLE IF NOT EXISTS scores (
        id INT AUTO_INCREMENT PRIMARY KEY,
        bracket_id INT NOT NULL,
        round INT NOT NULL,
        match_index INT NOT NULL,
        team_a VARCHAR(100),
        team_b VARCHAR(100),
        score_a INT DEFAULT 0,
        score_b INT DEFAULT 0,
        winner VARCHAR(100),
        created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
        updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        FOREIGN KEY (bracket_id) REFERENCES brackets(id) ON DELETE CASCADE,
        UNIQUE KEY unique_match (bracket_id, round, match_index)
      )
    ''');
  } catch (e) {
    print('Scores table: $e');
  }
}

/// GET /api/tournaments
/// Returns list of all tournaments
Future<Response> _getTournaments(Request req) async {
  final results = await _conn.query('''
    SELECT id, name, structure, status, created_at, updated_at FROM brackets 
    ORDER BY created_at DESC
  ''');

  final tournaments = results.map((row) {
    final structure = jsonDecode(row['structure'].toString());
    return {
      'id': row['id'],
      'name': row['name'],
      'status': row['status'],
      'type': structure['type'] ?? 'single',
      'teams': (structure['teams'] as List?)?.length ?? 0,
      'created': row['created_at'].toString(),
      'updated': row['updated_at'].toString(),
    };
  }).toList();

  return Response.ok(jsonEncode(tournaments),
      headers: {'content-type': 'application/json'});
}

/// POST /api/brackets
/// body: { "name": "My Tourney", "teams": ["A","B",...], "type": "single" }
Future<Response> _createBracket(Request req) async {
  final body = jsonDecode(await req.readAsString());
  final String name = body['name'] ?? 'Unnamed';
  final List<dynamic> teamsDyn = body['teams'] ?? [];
  final String type = body['type'] ?? 'single';
  final List<String> teams = teamsDyn.map((e) => e.toString()).toList();

  if (teams.length < 2 || (teams.length & (teams.length - 1)) != 0) {
    // require power of two
    return Response(400,
        body: jsonEncode({'error': 'team count must be power of two >=2'}),
        headers: {'content-type': 'application/json'});
  }

  final structure = _generateBracket(teams, type);
  final result = await _conn.query(
      'INSERT INTO brackets (name, structure) VALUES (?, ?)',
      [name, jsonEncode(structure)]);
  final id = result.insertId;

  return Response(201,
      body: jsonEncode({'id': id, 'structure': structure}),
      headers: {'content-type': 'application/json'});
}

/// GET /api/brackets/:id
Future<Response> _getBracket(Request req, String id) async {
  final results =
      await _conn.query('SELECT structure FROM brackets WHERE id = ?', [id]);
  if (results.isEmpty) {
    return Response.notFound('bracket not found');
  }
  final row = results.first;
  final structure = jsonDecode(row['structure'].toString());
  return Response.ok(jsonEncode({'id': int.parse(id), 'structure': structure}),
      headers: {'content-type': 'application/json'});
}

/// PUT /api/brackets/:id/match
/// body: { "round": 0, "index": 1, "scoreA": 10, "scoreB": 8 }
Future<Response> _updateMatch(Request req, String id) async {
  final payload = jsonDecode(await req.readAsString());
  final int round = payload['round'];
  final int index = payload['index'];
  final int scoreA = payload['scoreA'];
  final int scoreB = payload['scoreB'];

  // fetch current structure
  final result =
      await _conn.query('SELECT structure FROM brackets WHERE id = ?', [id]);
  if (result.isEmpty) return Response.notFound('bracket not found');
  final struct = jsonDecode(result.first['structure'].toString());
  _applyScore(struct, round, index, scoreA, scoreB);

  await _conn.query('UPDATE brackets SET structure = ? WHERE id = ?',
      [jsonEncode(struct), id]);
  return Response.ok(jsonEncode({'id': int.parse(id), 'structure': struct}),
      headers: {'content-type': 'application/json'});
}

Map<String, dynamic> _generateBracket(List<String> teams, String type) {
  final n = teams.length;
  final rounds = (log(n) / log(2)).ceil();
  List<List<Map<String, dynamic>>> roundsList = [];

  // first round pairing
  List<Map<String, dynamic>> first = [];
  for (int i = 0; i < n ~/ 2; i++) {
    first.add({
      'teamA': teams[i],
      'teamB': teams[n - 1 - i],
      'scoreA': null,
      'scoreB': null,
    });
  }
  roundsList.add(first);

  int matches = n ~/ 2;
  for (int r = 1; r < rounds; r++) {
    matches = matches ~/ 2;
    List<Map<String, dynamic>> roundMatches = [];
    for (int i = 0; i < matches; i++) {
      roundMatches.add({
        'teamA': null,
        'teamB': null,
        'scoreA': null,
        'scoreB': null,
      });
    }
    roundsList.add(roundMatches);
  }

  final result = {'type': type, 'teams': teams, 'rounds': roundsList};
  if (type == 'double') {
    // add placeholder losers bracket of the same shape; it will be filled
    // later when matches are lost. simple skeleton for UI expansion.
    final losers = roundsList
        .map((round) => round
            .map((_) => {
                  'teamA': null,
                  'teamB': null,
                  'scoreA': null,
                  'scoreB': null,
                })
            .toList())
        .toList();
    result['losers'] = losers;
  }
  return result;
}

void _applyScore(Map<String, dynamic> struct, int round, int index,
    int scoreA, int scoreB) {
  final rounds = struct['rounds'] as List;
  if (round < 0 || round >= rounds.length) return;
  final match = rounds[round][index] as Map<String, dynamic>;
  // Yuhkoh scoring: first to 2 points wins the match.
  // We always persist the current points so live scoring works.
  match['scoreA'] = scoreA;
  match['scoreB'] = scoreB;

  // Only advance the bracket when a side has reached 2 points.
  // (Allow intermediate states like 1-0 or 1-1 without advancing.)
  if (scoreA == scoreB) return;
  if (scoreA < 2 && scoreB < 2) return;
  if (scoreA >= 2 && scoreB >= 2) return; // invalid

  final String winner = scoreA >= 2 ? match['teamA'] : match['teamB'];
  if (round + 1 < rounds.length) {
    final nextIndex = index ~/ 2;
    final nextMatch = rounds[round + 1][nextIndex] as Map<String, dynamic>;
    if (index % 2 == 0) {
      nextMatch['teamA'] = winner;
    } else {
      nextMatch['teamB'] = winner;
    }
  }
}
