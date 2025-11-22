import 'dart:convert';

import 'hole_result.dart';
import 'session_stats.dart';

class PuttingSession {
  PuttingSession({
    required this.id,
    required this.holeCount,
    required this.startedAt,
    required this.includeSlope,
    required List<HoleResult> holes,
  }) : holes = List.unmodifiable(holes);

  final String id;
  final int holeCount;
  final DateTime startedAt;
  final bool includeSlope;
  final List<HoleResult> holes;

  bool get isComplete => holes.length >= holeCount;

  SessionStats get stats => SessionStats.fromHoles(holes);

  PuttingSession copyWith({
    bool? includeSlope,
    List<HoleResult>? holes,
  }) {
    return PuttingSession(
      id: id,
      holeCount: holeCount,
      startedAt: startedAt,
      includeSlope: includeSlope ?? this.includeSlope,
      holes: holes ?? this.holes,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'holeCount': holeCount,
      'startedAt': startedAt.toIso8601String(),
      'includeSlope': includeSlope,
      'holes': holes.map((hole) => hole.toMap()).toList(),
    };
  }

  factory PuttingSession.fromMap(Map<String, dynamic> map) {
    return PuttingSession(
      id: map['id'] as String,
      holeCount: map['holeCount'] as int,
      startedAt: DateTime.parse(map['startedAt'] as String),
      includeSlope: map['includeSlope'] as bool? ?? true,
      holes: (map['holes'] as List<dynamic>)
          .map((hole) => HoleResult.fromMap(hole as Map<String, dynamic>))
          .toList(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory PuttingSession.fromJson(String source) =>
      PuttingSession.fromMap(jsonDecode(source) as Map<String, dynamic>);
}
