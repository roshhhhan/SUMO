
class MatchInfo {
  String? teamA;
  String? teamB;
  int? scoreA;
  int? scoreB;

  MatchInfo({this.teamA, this.teamB, this.scoreA, this.scoreB});

  factory MatchInfo.fromJson(Map<String, dynamic> json) => MatchInfo(
        teamA: json['teamA'],
        teamB: json['teamB'],
        scoreA: json['scoreA'],
        scoreB: json['scoreB'],
      );

  Map<String, dynamic> toJson() => {
        'teamA': teamA,
        'teamB': teamB,
        'scoreA': scoreA,
        'scoreB': scoreB,
      };
}

class Bracket {
  int? id;
  String? type;
  List<Map<String, dynamic>>? teams; // Changed from List<String> to handle full team objects
  List<List<MatchInfo>>? rounds;

  Bracket({this.id, this.type, this.teams, this.rounds});

  factory Bracket.fromJson(Map<String, dynamic> json) {
    try {
      // Handle both formats: direct structure or nested under 'structure' key
      final data = json['structure'] is Map ? json['structure'] as Map<String, dynamic> : json;
      final roundsJson = data['rounds'] as List<dynamic>?;
      
      List<List<MatchInfo>>? rounds;
      if (roundsJson != null) {
        rounds = [];
        for (var r in roundsJson) {
          final roundList = (r as List).map((m) {
            if (m is Map<String, dynamic>) {
              return MatchInfo.fromJson(m);
            }
            throw Exception('Invalid match data: $m');
          }).toList();
          rounds.add(roundList);
        }
      }
      
      // Handle teams: can be List<String> (legacy) or List<Map<String,dynamic>> (new)
      List<Map<String, dynamic>>? teams;
      final teamsData = data['teams'];
      if (teamsData is List) {
        teams = (teamsData).map((t) {
          if (t is Map<String, dynamic>) {
            return t;
          } else if (t is String) {
            // Legacy format: wrap string in a simple map
            return {'name': t, 'school': '', 'members': <String>[]};
          } else {
            return Map<String, dynamic>.from(t as Map);
          }
        }).toList();
      }
      
      return Bracket(
        id: json['id'],
        type: data['type'],
        teams: teams,
        rounds: rounds,
      );
    } catch (e) {
      print('ERROR in Bracket.fromJson: $e');
      print('  JSON: $json');
      rethrow;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'teams': teams,
        'rounds': rounds?.map((r) => r.map((m) => m.toJson()).toList()).toList(),
      };
}
